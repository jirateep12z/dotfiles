#!/usr/bin/env pwsh

$SCRIPT_DIR = $PSScriptRoot
$SCRIPT_NAME = Split-Path -Leaf $PSCommandPath

. "$SCRIPT_DIR/utils/powershell/logger.ps1" 2>$null
if (-not $?) {
  Write-Error "Error: Cannot load logger.ps1 utility"
  exit 1
}
. "$SCRIPT_DIR/utils/powershell/progress.ps1" 2>$null
if (-not $?) {
  Write-Error "Error: Cannot load progress.ps1 utility"
  exit 1
}
. "$SCRIPT_DIR/utils/powershell/file.ps1" 2>$null
if (-not $?) {
  Write-Error "Error: Cannot load file.ps1 utility"
  exit 1
}

function CheckInstallCompatibility {
  if ($PSVersionTable.OS -notlike "*Windows*") {
    LogError "This install script does not support the current OS"
    return $false
  }
  return $true
}

function ShowMenu {
  if (Test-Path "$SCRIPT_DIR/ascii.txt") {
    Write-Host ""
    Get-Content "$SCRIPT_DIR/ascii.txt" -Encoding UTF8
    Write-Host ""
  }
  Write-Host "INSTALL:"
  Write-Host "  1. Install PowerShell modules"
  Write-Host "  2. Install Scoop packages"
  Write-Host "  3. Install Node.js LTS version"
  Write-Host "  4. Install NPM packages"
  Write-Host "  5. Install Windsurf extensions"
  Write-Host "  6. Install all packages"
  Write-Host ""
  Write-Host "UNINSTALL:"
  Write-Host "  7. Uninstall PowerShell modules"
  Write-Host "  8. Uninstall Scoop packages"
  Write-Host "  9. Uninstall Node.js LTS version"
  Write-Host " 10. Uninstall NPM packages"
  Write-Host " 11. Uninstall Windsurf extensions"
  Write-Host " 12. Uninstall all packages"
  Write-Host ""
  Write-Host "CONFIGURE:"
  Write-Host " 13. Configure PowerShell"
  Write-Host " 14. Configure Windows Terminal"
  Write-Host " 15. Configure Vim"
  Write-Host " 16. Configure Script"
  Write-Host " 17. Configure Lazygit"
  Write-Host " 18. Configure Python (pip)"
  Write-Host " 19. Configure Commitizen"
  Write-Host " 20. Configure Windsurf"
  Write-Host " 21. Configure Git"
  Write-Host " 22. Configure all applications"
  Write-Host ""
  Write-Host "REMOVE:"
  Write-Host " 23. Remove PowerShell configuration"
  Write-Host " 24. Remove Windows Terminal configuration"
  Write-Host " 25. Remove Vim configuration"
  Write-Host " 26. Remove Script configuration"
  Write-Host " 27. Remove Lazygit configuration"
  Write-Host " 28. Remove Python configuration"
  Write-Host " 29. Remove Commitizen configuration"
  Write-Host " 30. Remove Windsurf configuration"
  Write-Host " 31. Remove Git configuration"
  Write-Host " 32. Remove all configurations"
  Write-Host ""
  Write-Host "  q. Quit"
  Write-Host ""
}

function InstallPackage {
  param (
    [string]$PackageName,
    [string]$PackageListPath,
    [string]$InstallCommand,
    [string]$AdditionalParams = ""
  )
  try {
    if (-not (Test-Path $PackageListPath)) {
      LogWarning "Package list not found: $PackageListPath"
      return
    }
    if ($PackageName) {
      LogInfo "Installing $PackageName"
    }
    $packages = Get-Content $PackageListPath | Where-Object { $_ -and $_ -notmatch '^\s*#' }
    $total = $packages.Count
    $current = 0
    foreach ($package in $packages) {
      $current++
      LogInfo "[$current/$total] Installing: $package"
      if ($AdditionalParams) {
        Invoke-Expression "$InstallCommand $package $AdditionalParams"
      } else {
        Invoke-Expression "$InstallCommand $package"
      }
    }
    LogSuccess "Completed installing $PackageName"
  } catch {
    LogError "An error occurred while installing $PackageName : $_"
  }
}

function UninstallPackage {
  param (
    [string]$PackageName,
    [string]$PackageListPath,
    [string]$UninstallCommand
  )
  try {
    if (-not (Test-Path $PackageListPath)) {
      LogWarning "Package list not found: $PackageListPath"
      return
    }
    if ($PackageName) {
      LogInfo "Uninstalling $PackageName"
    }
    $packages = Get-Content $PackageListPath | Where-Object { $_ -and $_ -notmatch '^\s*#' }
    $total = $packages.Count
    $current = 0
    foreach ($package in $packages) {
      $current++
      LogInfo "[$current/$total] Uninstalling: $package"
      Invoke-Expression "$UninstallCommand $package"
    }
    LogSuccess "Completed uninstalling $PackageName"
  } catch {
    LogError "An error occurred while uninstalling $PackageName : $_"
  }
}

function InstallPowerShellModules {
  try {
    LogInfo "Checking PowerShell installation"
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
      LogInfo "Installing PowerShell via winget"
      winget install --id Microsoft.PowerShell --source winget --silent
    }
    InstallPackage -PackageName "PowerShell modules" -PackageListPath "$SCRIPT_DIR/requirement/powershell.txt" -InstallCommand "Install-Module -Name" -AdditionalParams "-Scope CurrentUser -AllowClobber -Force"
  } catch {
    LogError "An error occurred while installing PowerShell modules: $_"
  }
}

function UninstallPowerShellModules {
  try {
    UninstallPackage -PackageName "PowerShell modules" -PackageListPath "$SCRIPT_DIR/requirement/powershell.txt" -UninstallCommand "Uninstall-Module -Name"
  } catch {
    LogError "An error occurred while uninstalling PowerShell modules: $_"
  }
}

function InstallScoopPackages {
  try {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
      LogWarning "Scoop is not installed. Installing..."
      Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
      Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    }
    InstallPackage -PackageName "Scoop buckets" -PackageListPath "$SCRIPT_DIR/requirement/scoop_bucket.txt" -InstallCommand "scoop bucket add"
    InstallPackage -PackageName "Scoop packages" -PackageListPath "$SCRIPT_DIR/requirement/scoop_package.txt" -InstallCommand "scoop install"
    InstallPackage -PackageName "Scoop applications" -PackageListPath "$SCRIPT_DIR/requirement/scoop_application.txt" -InstallCommand "scoop install"
    InstallPackage -PackageName "Scoop fonts" -PackageListPath "$SCRIPT_DIR/requirement/scoop_font.txt" -InstallCommand "scoop install"
  } catch {
    LogError "An error occurred while installing Scoop packages: $_"
  }
}

function UninstallScoopPackages {
  try {
    UninstallPackage -PackageName "Scoop fonts" -PackageListPath "$SCRIPT_DIR/requirement/scoop_font.txt" -UninstallCommand "scoop uninstall"
    UninstallPackage -PackageName "Scoop applications" -PackageListPath "$SCRIPT_DIR/requirement/scoop_application.txt" -UninstallCommand "scoop uninstall"
    UninstallPackage -PackageName "Scoop packages" -PackageListPath "$SCRIPT_DIR/requirement/scoop_package.txt" -UninstallCommand "scoop uninstall"
  } catch {
    LogError "An error occurred while uninstalling Scoop packages: $_"
  }
}

function InstallNodeJS {
  try {
    if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
      LogWarning "NVM is not installed. Installing Scoop first..."
      InstallScoopPackages
    }
    LogInfo "Installing Node.js LTS version"
    nvm install lts
    LogInfo "Using Node.js LTS version"
    nvm use lts
    LogSuccess "Node.js LTS installed successfully"
  } catch {
    LogError "An error occurred while installing Node.js LTS: $_"
  }
}

function UninstallNodeJS {
  try {
    if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
      LogWarning "NVM is not installed"
      return
    }
    LogInfo "Uninstalling Node.js LTS version"
    nvm uninstall lts
    LogSuccess "Node.js LTS uninstalled successfully"
  } catch {
    LogError "An error occurred while uninstalling Node.js LTS: $_"
  }
}

function InstallNPMPackages {
  try {
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
      LogWarning "Node.js is not installed. Installing..."
      InstallNodeJS
    }
    InstallPackage -PackageName "NPM packages" -PackageListPath "$SCRIPT_DIR/requirement/npm.txt" -InstallCommand "npm install -g"
  } catch {
    LogError "An error occurred while installing NPM packages: $_"
  }
}

function UninstallNPMPackages {
  try {
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
      LogWarning "Node.js is not installed"
      return
    }
    UninstallPackage -PackageName "NPM packages" -PackageListPath "$SCRIPT_DIR/requirement/npm.txt" -UninstallCommand "npm uninstall -g"
  } catch {
    LogError "An error occurred while uninstalling NPM packages: $_"
  }
}

function InstallWindsurfExtensions {
  try {
    if (-not (Get-Command windsurf -ErrorAction SilentlyContinue)) {
      LogWarning "Windsurf is not installed. Installing via Scoop..."
      InstallScoopPackages
    }
    InstallPackage -PackageName "Windsurf extensions" -PackageListPath "$SCRIPT_DIR/requirement/windsurf.txt" -InstallCommand "windsurf --install-extension" -AdditionalParams "--force"
  } catch {
    LogError "An error occurred while installing Windsurf extensions: $_"
  }
}

function UninstallWindsurfExtensions {
  try {
    if (-not (Get-Command windsurf -ErrorAction SilentlyContinue)) {
      LogWarning "Windsurf is not installed"
      return
    }
    UninstallPackage -PackageName "Windsurf extensions" -PackageListPath "$SCRIPT_DIR/requirement/windsurf.txt" -UninstallCommand "windsurf --uninstall-extension"
  } catch {
    LogError "An error occurred while uninstalling Windsurf extensions: $_"
  }
}

function InstallAllPackages {
  InstallPowerShellModules
  InstallScoopPackages
  InstallNodeJS
  InstallNPMPackages
  InstallWindsurfExtensions
  LogSuccess "All packages installed successfully"
}

function UninstallAllPackages {
  UninstallWindsurfExtensions
  UninstallNPMPackages
  UninstallNodeJS
  UninstallScoopPackages
  UninstallPowerShellModules
  LogSuccess "All packages uninstalled successfully"
}

function SetApplicationConfig {
  param (
    [string]$AppName,
    [string]$SourcePath,
    [string]$DestinationPath,
    [string[]]$Extensions = @(),
    [string[]]$Files = @()
  )
  try {
    if ($AppName) {
      LogInfo "Configuring $AppName"
    }
    if (-not (Test-Path $SourcePath)) {
      LogWarning "Source path not found: $SourcePath"
      return
    }
    if (Test-Path $DestinationPath) {
      if ($Extensions.Count -eq 0 -and $Files.Count -eq 0) {
        LogInfo "Cleaning destination: $DestinationPath"
        Remove-Item -Path "$DestinationPath" -Recurse -Force
        New-Item -Path "$DestinationPath" -ItemType Directory -Force | Out-Null
      } else {
        if ($Extensions.Count -gt 0) {
          foreach ($extension in $Extensions) {
            Get-ChildItem -Path "$DestinationPath" -Filter "*.$extension" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
          }
        }
        if ($Files.Count -gt 0) {
          foreach ($file in $Files) {
            Get-ChildItem -Path "$DestinationPath" -Filter "$file" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
          }
        }
      }
    } else {
      LogInfo "Creating destination: $DestinationPath"
      New-Item -Path "$DestinationPath" -ItemType Directory -Force | Out-Null
    }
    if ((Get-Item $SourcePath).PSIsContainer) {
      Copy-Item -Path "$SourcePath/*" -Destination "$DestinationPath" -Recurse -Force
    } else {
      Copy-Item -Path "$SourcePath" -Destination "$DestinationPath" -Recurse -Force
    }
    LogSuccess "$AppName configured successfully"
  } catch {
    LogError "An error occurred while configuring $AppName : $_"
  }
}

function RemoveApplicationConfig {
  param (
    [string]$AppName,
    [string]$DestinationPath,
    [string[]]$Extensions = @(),
    [string[]]$Files = @()
  )
  try {
    if ($AppName) {
      LogInfo "Removing $AppName configuration"
    }
    if (Test-Path $DestinationPath) {
      if ($Extensions.Count -eq 0 -and $Files.Count -eq 0) {
        Remove-Item -Path "$DestinationPath" -Recurse -Force
        LogSuccess "Removed $AppName configuration"
      } else {
        if ($Extensions.Count -gt 0) {
          foreach ($extension in $Extensions) {
            Get-ChildItem -Path "$DestinationPath" -Filter "*.$extension" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
          }
        }
        if ($Files.Count -gt 0) {
          foreach ($file in $Files) {
            Get-ChildItem -Path "$DestinationPath" -Filter "$file" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
          }
        }
        LogSuccess "Removed $AppName configuration files"
      }
    } else {
      LogWarning "Configuration path not found: $DestinationPath"
    }
  } catch {
    LogError "An error occurred while removing $AppName configuration: $_"
  }
}

function SetPowerShellConfig {
  $paths = Get-Module -ListAvailable -All | Select-Object -ExpandProperty Path
  $powershell_path = ""
  foreach ($path in $paths) {
    if ($path -like "*Documents\*") {
      $powershell_path = "$ENV:USERPROFILE\Documents"
      break
    } elseif ($path -like "*OneDrive\Documents\*") {
      $powershell_path = "$ENV:USERPROFILE\OneDrive\Documents"
      break
    }
  }
  if (-not $powershell_path) {
    $powershell_path = "$ENV:USERPROFILE\Documents"
  }
  SetApplicationConfig -AppName "Windows PowerShell" -SourcePath "$SCRIPT_DIR/config/powershell" -DestinationPath "$powershell_path/WindowsPowerShell" -Extensions @("txt", "json", "ps1")
  if (Test-Path "$powershell_path/WindowsPowerShell/microsoft.powershell_profile.ps1") {
    Rename-Item -Path "$powershell_path/WindowsPowerShell/microsoft.powershell_profile.ps1" -NewName "Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
  }
  if (Test-Path "$powershell_path/WindowsPowerShell/Modules") {
    Copy-Item -Path "$powershell_path/WindowsPowerShell/Modules/*" -ErrorAction SilentlyContinue -Destination "$powershell_path/PowerShell/Modules" -Recurse -Force
  }
  SetApplicationConfig -AppName "PowerShell" -SourcePath "$SCRIPT_DIR/config/powershell" -DestinationPath "$powershell_path/PowerShell" -Extensions @("txt", "json", "ps1")
  if (Test-Path "$powershell_path/PowerShell/microsoft.powershell_profile.ps1") {
    Rename-Item -Path "$powershell_path/PowerShell/microsoft.powershell_profile.ps1" -NewName "Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
  }
  if (Test-Path "$powershell_path/PowerShell/Modules") {
    Copy-Item -Path "$powershell_path/PowerShell/Modules/*" -ErrorAction SilentlyContinue -Destination "$powershell_path/WindowsPowerShell/Modules" -Recurse -Force
  }
}

function RemovePowerShellConfig {
  $paths = Get-Module -ListAvailable -All | Select-Object -ExpandProperty Path
  $powershell_path = ""
  foreach ($path in $paths) {
    if ($path -like "*Documents\*") {
      $powershell_path = "$ENV:USERPROFILE\Documents"
      break
    } elseif ($path -like "*OneDrive\Documents\*") {
      $powershell_path = "$ENV:USERPROFILE\OneDrive\Documents"
      break
    }
  }
  if (-not $powershell_path) {
    $powershell_path = "$ENV:USERPROFILE\Documents"
  }
  RemoveApplicationConfig -AppName "Windows PowerShell" -DestinationPath "$powershell_path/WindowsPowerShell"
  RemoveApplicationConfig -AppName "PowerShell" -DestinationPath "$powershell_path/PowerShell"
}

function SetWindowsTerminalConfig {
  SetApplicationConfig -AppName "Windows Terminal" -SourcePath "$SCRIPT_DIR/config/windows terminal" -DestinationPath "$ENV:USERPROFILE/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState" -Files @("settings.json")
}

function RemoveWindowsTerminalConfig {
  RemoveApplicationConfig -AppName "Windows Terminal" -DestinationPath "$ENV:USERPROFILE/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState" -Files @("settings.json")
}

function SetVimConfig {
  SetApplicationConfig -AppName "Vim" -SourcePath "$SCRIPT_DIR/config/vim" -DestinationPath "$ENV:USERPROFILE" -Files @(".vimrc")
}

function RemoveVimConfig {
  RemoveApplicationConfig -AppName "Vim" -DestinationPath "$ENV:USERPROFILE" -Files @(".vimrc")
}

function SetLazyGitConfig {
  SetApplicationConfig -AppName "Lazygit" -SourcePath "$SCRIPT_DIR/config/lazygit" -DestinationPath "$ENV:USERPROFILE/AppData/Local/lazygit"
}

function RemoveLazyGitConfig {
  RemoveApplicationConfig -AppName "Lazygit" -DestinationPath "$ENV:USERPROFILE/AppData/Local/lazygit"
}

function SetPythonConfig {
  SetApplicationConfig -AppName "Python (pip)" -SourcePath "$SCRIPT_DIR/config/pip" -DestinationPath "$ENV:USERPROFILE/AppData/Roaming/pip"
}

function RemovePythonConfig {
  RemoveApplicationConfig -AppName "Python (pip)" -DestinationPath "$ENV:USERPROFILE/AppData/Roaming/pip"
}

function SetCommitizenConfig {
  SetApplicationConfig -AppName "Commitizen" -SourcePath "$SCRIPT_DIR/config/commitizen" -DestinationPath "$ENV:USERPROFILE" -Files @(".czrc")
}

function RemoveCommitizenConfig {
  RemoveApplicationConfig -AppName "Commitizen" -DestinationPath "$ENV:USERPROFILE" -Files @(".czrc")
}

function SetWindsurfConfig {
  if (-not (Get-Command windsurf -ErrorAction SilentlyContinue)) {
    LogWarning "Windsurf is not installed. Installing via Scoop..."
    InstallScoopPackages
  }
  $windsurf_path = ""
  $paths = Get-Command windsurf -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
  foreach ($path in $paths) {
    if ($path -like "*Windsurf\*") {
      $windsurf_path = "$ENV:USERPROFILE/AppData/Roaming/Windsurf/User"
      break
    } elseif ($path -like "*scoop\apps\windsurf\current\*") {
      $windsurf_path = "$ENV:USERPROFILE/scoop/apps/windsurf/current/data/user-data/User"
      break
    }
  }
  if (-not $windsurf_path) {
    $windsurf_path = "$ENV:USERPROFILE/AppData/Roaming/Windsurf/User"
  }
  SetApplicationConfig -AppName "Windsurf" -SourcePath "$SCRIPT_DIR/config/windsurf" -DestinationPath "$windsurf_path" -Extensions @("json")
}

function RemoveWindsurfConfig {
  if (-not (Get-Command windsurf -ErrorAction SilentlyContinue)) {
    LogWarning "Windsurf is not installed"
    return
  }
  $windsurf_path = ""
  $paths = Get-Command windsurf -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
  foreach ($path in $paths) {
    if ($path -like "*Windsurf\*") {
      $windsurf_path = "$ENV:USERPROFILE/AppData/Roaming/Windsurf/User"
      break
    } elseif ($path -like "*scoop\apps\windsurf\current\*") {
      $windsurf_path = "$ENV:USERPROFILE/scoop/apps/windsurf/current/data/user-data/User"
      break
    }
  }
  if (-not $windsurf_path) {
    $windsurf_path = "$ENV:USERPROFILE/AppData/Roaming/Windsurf/User"
  }
  RemoveApplicationConfig -AppName "Windsurf" -DestinationPath "$windsurf_path" -Extensions @("json")
}

function SetScriptConfig {
  SetApplicationConfig -AppName "Script" -SourcePath "$SCRIPT_DIR/script" -DestinationPath "$ENV:USERPROFILE/AppData/Local/script"
}

function RemoveScriptConfig {
  RemoveApplicationConfig -AppName "Script" -DestinationPath "$ENV:USERPROFILE/AppData/Local/script"
}

function SetGitConfig {
  SetApplicationConfig -AppName "Git" -SourcePath "$SCRIPT_DIR/.gitconfig" -DestinationPath "$ENV:USERPROFILE" -Files @(".gitconfig")
}

function RemoveGitConfig {
  RemoveApplicationConfig -AppName "Git" -DestinationPath "$ENV:USERPROFILE" -Files @(".gitconfig")
}

function SetAllApplicationConfigs {
  SetPowerShellConfig
  SetWindowsTerminalConfig
  SetVimConfig
  SetScriptConfig
  SetLazyGitConfig
  SetPythonConfig
  SetCommitizenConfig
  SetWindsurfConfig
  SetGitConfig
  LogSuccess "All applications configured successfully"
}

function RemoveAllApplicationConfigs {
  RemoveWindsurfConfig
  RemoveGitConfig
  RemoveCommitizenConfig
  RemovePythonConfig
  RemoveLazyGitConfig
  RemoveScriptConfig
  RemoveVimConfig
  RemoveWindowsTerminalConfig
  RemovePowerShellConfig
  LogSuccess "All configurations removed successfully"
}

function Main {
  if (-not (CheckInstallCompatibility)) {
    exit 1
  }
  do {
    ShowMenu
    $choice = Read-Host "Enter your choice"
    switch ($choice) {
      "1" { InstallPowerShellModules }
      "2" { InstallScoopPackages }
      "3" { InstallNodeJS }
      "4" { InstallNPMPackages }
      "5" { InstallWindsurfExtensions }
      "6" { InstallAllPackages }
      "7" { UninstallPowerShellModules }
      "8" { UninstallScoopPackages }
      "9" { UninstallNodeJS }
      "10" { UninstallNPMPackages }
      "11" { UninstallWindsurfExtensions }
      "12" { UninstallAllPackages }
      "13" { SetPowerShellConfig }
      "14" { SetWindowsTerminalConfig }
      "15" { SetVimConfig }
      "16" { SetScriptConfig }
      "17" { SetLazyGitConfig }
      "18" { SetPythonConfig }
      "19" { SetCommitizenConfig }
      "20" { SetWindsurfConfig }
      "21" { SetGitConfig }
      "22" { SetAllApplicationConfigs }
      "23" { RemovePowerShellConfig }
      "24" { RemoveWindowsTerminalConfig }
      "25" { RemoveVimConfig }
      "26" { RemoveScriptConfig }
      "27" { RemoveLazyGitConfig }
      "28" { RemovePythonConfig }
      "29" { RemoveCommitizenConfig }
      "30" { RemoveWindsurfConfig }
      "31" { RemoveGitConfig }
      "32" { RemoveAllApplicationConfigs }
      "q" { break }
      default { LogWarning "Invalid choice. Please try again." }
    }
  } while ($choice -ne "q")
}

Main
