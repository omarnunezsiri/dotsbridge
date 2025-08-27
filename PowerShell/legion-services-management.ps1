<#
.SYNOPSIS
    This script manages Windows services on a Lenovo Legion 7i Gen 9 laptop.
    I found that a stock Lenovo Legion can be quite bloated with unnecessary services,
    so this script aims to streamline and optimize the service configuration.

.NOTES
    I **generally** run Chris Titus Tech's WinUtil tool after installing and updating Windows,
    given that this targets Lenovo/Misc services for optimization.

    - Run this script in an elevated PowerShell (Run as administrator).
    - A backup of the current service states will be saved to the Desktop.
    - Review the lists in the script before running to ensure they fit your needs.

.AUTHOR
    Omar

.LICENSE
    Follow LICENSE in the root of this repository
#>

# Admin check
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Error "Run this script in an elevated PowerShell (Run as administrator)." -ForegroundColor Red
    exit 1
}

# Backup current states
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupCsv = "$env:USERPROFILE\Desktop\ServicesBackup-$timestamp.csv"
Get-CimInstance Win32_Service |
Select-Object Name, DisplayName, State, StartMode, StartName |
Export-Csv -NoTypeInformation -Path $backupCsv
Write-Host "Backup saved to: $backupCsv" -ForegroundColor Green

# Helpers
function Resolve-Services
{
    param(
        [string[]]$Patterns
    )

    $all = Get-CimInstance -ClassName Win32_Service

    $results = foreach ($p in $Patterns)
    {
        $all | Where-Object { $_.Name -like $p -or $_.DisplayName -like $p }
    }

    $results | Sort-Object Name -Unique
}

function Set-Startup
{
    param(
        [object[]]$Services,
        [ValidateSet('Automatic', 'Manual', 'Disabled')]$Mode
    )

    foreach ($s in $Services)
    {
        $name = $s.Name
        
        try
        {
            Set-Service -Name $name -StartupType $Mode -ErrorAction Stop
            Write-Host ("{0,-40} -> {1}" -f $name, $Mode)
        }
        catch
        {
            Write-Warning "Could not set $name to $Mode ($($_.Exception.Message))"
        }
    }
}

function Stop-And-Disable
{
    param(
        [object[]]$Services
    )

    foreach ($s in $Services)
    {
        $name = $s.Name
        $state = if ($s.PSObject.Properties['State']) { $s.State } elseif ($s.PSObject.Properties['Status']) { $s.Status } else { '' }

        try
        {
            if ($state -eq 'Running')
            {
                Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
            }

            Set-Service -Name $name -StartupType Disabled -ErrorAction Stop
            Write-Host ("{0,-40} -> Disabled" -f $name)
        }
        catch
        {
            Write-Warning "Could not disable $name ($($_.Exception.Message))"
        }
    }
}

# DO NOT touch these Lenovo core services (keep Automatic) unless you know what you're doing:
# ImControllerService, LenovoVantageService, LenovoSmartFusionService, LenovoFnAndFunctionKeysService

# Manual (on demand: still available)
$Manual_List = @(
    # Lenovo extras
    'Lenovo*Communication*',       # Smart Communication / AI voice
    'LnvVCam*',                    # Lenovo Virtual Camera bits
    'SmartAppearance*',            # Webcam appearance AI
    'CameraEventService',          # Lenovo camera events
    'AISpeechService',             # AI speech control

    # Input / devices / discovery
    'GameInputSvc',
    'ELAN*Detection*',
    'FDResPub', 'fdPHost', 'SSDPSRV',

    # Location / phone / xbox
    'lfsvc',
    'PhoneSvc',
    'XblAuthManager',

    # Imaging / scanners
    'StiSvc', 'WiaRpc',

    # Thunderbolt
    'TbtHostControllerService',
    'TbtP2pShortcutService',

    # NVIDIA / Intel utilities
    'NvBroadcast.ContainerLocalSystem',
    'XTU3SERVICE',                      # Intel XTU
    'DSAService', 'DSAUpdateService',   # Intel DSA

    # Tobii eye-tracking
    'Tobii*',

    # Windows Subsystem for Android fabric
    'WSAIFabricSvc',

    # Misc OEM
    'UDCService'                   # Universal Device Client
)

# Telemetry/bloat (safe to remove from daily operation)
$Disable_List = @(
    'ESRV_*QUEENCREEK*',                # Intel energy/telemetry
    'USER_ESRV_*QUEENCREEK*',
    'SystemUsageReport*',               # Intel System Usage Report service
    'webthreatdef*',                    # Lenovo Web Threat Defender (svc + per-user)
    'LRAvatarService'                   # Lenovo AR avatar overlay
)

# Apply
Write-Host "Setting OPTIONAL/OEM services to MANUAL" -ForegroundColor Cyan
Set-Startup -Services (Resolve-Services $Manual_List) -Mode Manual

Write-Host "`nDisabling telemetry/bloat" -ForegroundColor Cyan
Stop-And-Disable (Resolve-Services $Disable_List)

# Prompt to reboot now
Write-Host "`nDone. Backup CSV is on your Desktop: $backupCsv"
$reboot = Read-Host "Do you want to reboot now? (Y/N)"
if ($reboot -eq 'Y' -or $reboot -eq 'y')
{
    Restart-Computer -Force
}