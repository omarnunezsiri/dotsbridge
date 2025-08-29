<#
.SYNOPSIS
    My *own* PowerShell profile script.

.NOTES
    This script expects the following environment variables to be set manually:
    - DEV_ENV: The path to the development environment
    - DOTS_PATH: The path to the dots configuration
#>

#region Utilities

# Unix-like sudo
function sudo 
{ 
    Start-Process wt -Verb runAs
}

# Unix-like which command
function which($name) { Get-Command $name | Select-Object -ExpandProperty Definition }

# Unix-like touch command
function touch() { New-Item -ItemType File -Name $args[0] }

# Open the current directory in the file explorer
function here() { Invoke-Item . }

# Opens my dev environment
function Open-DevEnvironment()
{ 
    Set-Location $env:DEV_ENV
    code .
}

# This attempts to update the local PowerShell profile from the upstream
function Update-LocalProfile
{
    try
    {
        Write-Host "Fetching remote profile script..." -ForegroundColor Yellow

        $tempPath = Join-Path $env:TEMP 'remote_profile.ps1'
        if (-not $env:REMOTE_PROFILE) { throw "REMOTE_PROFILE environment variable is empty." }

        Invoke-WebRequest -Uri $env:REMOTE_PROFILE -OutFile $tempPath -ErrorAction Stop

        $remoteHash = Get-FileHash -Path $tempPath -Algorithm SHA256
        $localHash = Get-FileHash -Path $PROFILE  -Algorithm SHA256

        if ($remoteHash.Hash -ne $localHash.Hash)
        {
            Write-Host "Remote profile differs. Updating local profile..." -ForegroundColor Yellow
            Copy-Item -Path $tempPath -Destination $PROFILE -Force
            Remove-Item -Path $tempPath -Force
            Write-Host "Local profile updated. Restart PowerShell to apply changes." -ForegroundColor Green
        }
        else
        {
            Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
            Write-Host "Local profile is already up to date." -ForegroundColor Green
        }
    }
    catch
    {
        Write-Host "Failed to update local profile: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Reloads the powershell profile
function Update-Profile
{
    & $PROFILE
}

#endregion


#region Aliases

Set-Alias -Name dev -Value Open-DevEnvironment
Set-Alias -Name reload -Value Update-Profile
Set-Alias -Name su -Value sudo 

#endregion

#region Init

Import-Module -Name Terminal-Icons

$draculaColorThemePath = "$env:DOTS_PATH\PowerShell\dracula.psd1"
if (Test-Path $draculaColorThemePath)
{
    Add-TerminalIconsColorTheme -Force $draculaColorThemePath
    Set-TerminalIconsTheme -ColorTheme dracula
}
else
{
    Write-Host "Warning: 'dracula' color theme not found." -ForegroundColor Yellow
}

oh-my-posh init pwsh --config $env:POSH_THEMES_PATH\tokyonight_storm.omp.json | Invoke-Expression

#endregion