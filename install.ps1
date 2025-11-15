#!/usr/bin/env pwsh

$SCRIPT_DIR = $PSScriptRoot
$SCRIPT_NAME = Split-Path -Leaf $PSCommandPath

. "$SCRIPT_DIR/utils/powershell/file.ps1" 2>$null
if (-not $?) {
  Write-Error "Error: Cannot load file.ps1 utility"
  exit 1
}
. "$SCRIPT_DIR/utils/powershell/progress.ps1" 2>$null
if (-not $?) {
  Write-Error "Error: Cannot load progress.ps1 utility"
  exit 1
}
. "$SCRIPT_DIR/utils/powershell/logger.ps1" 2>$null
if (-not $?) {
  Write-Error "Error: Cannot load logger.ps1 utility"
  exit 1
}

function CheckInstallCompatibility {
  $is_windows = $IsWindows -or $env:OS -eq "Windows_NT"
  if (-not $is_windows) {
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
  Write-Host "  5. Install VSCode extensions"
  Write-Host "  6. Install Skills"
  Write-Host "  7. Install all packages"
  Write-Host ""
  Write-Host "UNINSTALL:"
  Write-Host "  8. Uninstall PowerShell modules"
  Write-Host "  9. Uninstall Scoop packages"
  Write-Host " 10. Uninstall Node.js LTS version"
  Write-Host " 11. Uninstall NPM packages"
  Write-Host " 12. Uninstall VSCode extensions"
  Write-Host " 13. Uninstall Skills"
  Write-Host " 14. Uninstall all packages"
  Write-Host ""
  Write-Host "CONFIGURE:"
  Write-Host " 15. Configure PowerShell"
  Write-Host " 16. Configure Windows Terminal"
  Write-Host " 17. Configure Script"
  Write-Host " 18. Configure Python (pip)"
  Write-Host " 19. Configure Warp"
  Write-Host " 20. Configure Vim"
  Write-Host " 21. Configure Neovim"
  Write-Host " 22. Configure Git"
  Write-Host " 23. Configure Lazygit"
  Write-Host " 24. Configure Commitizen"
  Write-Host " 25. Configure VSCode"
  Write-Host " 26. Configure all applications"
  Write-Host ""
  Write-Host "REMOVE:"
  Write-Host " 27. Remove PowerShell configuration"
  Write-Host " 28. Remove Windows Terminal configuration"
  Write-Host " 29. Remove Script configuration"
  Write-Host " 30. Remove Python configuration"
  Write-Host " 31. Remove Warp configuration"
  Write-Host " 32. Remove Vim configuration"
  Write-Host " 33. Remove Neovim configuration"
  Write-Host " 34. Remove Git configuration"
  Write-Host " 35. Remove Lazygit configuration"
  Write-Host " 36. Remove Commitizen configuration"
  Write-Host " 37. Remove VSCode configuration"
  Write-Host " 38. Remove all configurations"
  Write-Host ""
  Write-Host "  q. Quit"
  Write-Host ""
}

function InvokePackageCommand {
  param (
    [string]$CommandText,
    [string]$Package,
    [string]$AdditionalParams = ""
  )
  if ([string]::IsNullOrWhiteSpace($CommandText)) {
    LogError "Package command is empty"
    return $false
  }
  $command_parts = $CommandText -split '\s+'
  $command_name = $command_parts[0]
  $arguments = @()
  if ($command_parts.Count -gt 1) {
    $arguments += $command_parts[1..($command_parts.Count - 1)]
  }
  $arguments += ($Package -split '\s+')
  if (-not [string]::IsNullOrWhiteSpace($AdditionalParams)) {
    $arguments += ($AdditionalParams -split '\s+')
  }
  try {
    $command_info = Get-Command $command_name -ErrorAction Stop
    $invoke_arguments = $arguments
    if ($command_info.CommandType -eq "Cmdlet") {
      $invoke_arguments += @("-ErrorAction", "Stop")
    }
    if ($command_info.CommandType -eq "Application" -or $command_info.CommandType -eq "ExternalScript") {
      $executable_path = $command_info.Source
      if ($command_info.CommandType -eq "ExternalScript") {
        $application_command = Get-Command "$command_name.cmd" -ErrorAction SilentlyContinue
        if ($application_command) {
          $executable_path = $application_command.Source
        }
      }
      $process = Start-Process -FilePath $executable_path -ArgumentList $invoke_arguments -NoNewWindow -Wait -PassThru
      return ($process.ExitCode -eq 0)
    }
    & $command_name @invoke_arguments
    return $true
  } catch {
    LogError "Command failed: $CommandText $Package $AdditionalParams : $_"
    return $false
  }
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
      return $false
    }
    if ($PackageName) {
      LogInfo "Installing $PackageName"
    }
    $packages = @(Get-Content $PackageListPath | Where-Object { $_ -and $_ -notmatch '^\s*#' })
    $total = $packages.Count
    $current = 0
    $failed_packages = @()
    foreach ($package in $packages) {
      $current++
      LogInfo "[$current/$total] Installing: $package"
      if (-not (InvokePackageCommand -CommandText $InstallCommand -Package $package -AdditionalParams $AdditionalParams)) {
        $failed_packages += $package
        LogError "Failed to install: $package"
      }
    }
    if ($failed_packages.Count -gt 0) {
      LogError "Failed to install $PackageName : $($failed_packages -join ', ')"
      return $false
    }
    LogSuccess "Completed installing $PackageName"
    return $true
  } catch {
    LogError "An error occurred while installing $PackageName : $_"
    return $false
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
      return $false
    }
    if ($PackageName) {
      LogInfo "Uninstalling $PackageName"
    }
    $packages = @(Get-Content $PackageListPath | Where-Object { $_ -and $_ -notmatch '^\s*#' })
    $total = $packages.Count
    $current = 0
    $failed_packages = @()
    foreach ($package in $packages) {
      $current++
      LogInfo "[$current/$total] Uninstalling: $package"
      if (-not (InvokePackageCommand -CommandText $UninstallCommand -Package $package)) {
        $failed_packages += $package
        LogError "Failed to uninstall: $package"
      }
    }
    if ($failed_packages.Count -gt 0) {
      LogError "Failed to uninstall $PackageName : $($failed_packages -join ', ')"
      return $false
    }
    LogSuccess "Completed uninstalling $PackageName"
    return $true
  } catch {
    LogError "An error occurred while uninstalling $PackageName : $_"
    return $false
  }
}

function InstallPowerShellModule {
  param (
    [string]$module_name
  )
  try {
    Install-Module -Name $module_name -Scope CurrentUser -AllowClobber -Force -ErrorAction Stop
    return $true
  } catch {
    LogError "Command failed: Install-Module -Name $module_name -Scope CurrentUser -AllowClobber -Force : $_"
    return $false
  }
}

function UninstallPowerShellModule {
  param (
    [string]$module_name
  )
  try {
    Uninstall-Module -Name $module_name -ErrorAction Stop
    return $true
  } catch {
    LogError "Command failed: Uninstall-Module -Name $module_name : $_"
    return $false
  }
}

function InstallPowerShellModules {
  try {
    LogInfo "Checking PowerShell installation"
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
      LogInfo "Installing PowerShell via winget"
      winget install --id Microsoft.PowerShell --source winget --silent | Out-Host
      if ($LASTEXITCODE -ne 0) {
        LogError "Failed to install PowerShell via winget"
        return $false
      }
    }
    $package_list_path = "$SCRIPT_DIR/requirement/powershell.txt"
    if (-not (Test-Path $package_list_path)) {
      LogWarning "Package list not found: $package_list_path"
      return $false
    }
    LogInfo "Installing PowerShell modules"
    $packages = @(Get-Content $package_list_path | Where-Object { $_ -and $_ -notmatch '^\s*#' })
    $total = $packages.Count
    $current = 0
    $failed_packages = @()
    foreach ($package in $packages) {
      $current++
      LogInfo "[$current/$total] Installing: $package"
      if (-not (InstallPowerShellModule -module_name $package)) {
        $failed_packages += $package
        LogError "Failed to install: $package"
      }
    }
    if ($failed_packages.Count -gt 0) {
      LogError "Failed to install PowerShell modules : $($failed_packages -join ', ')"
      return $false
    }
    LogSuccess "Completed installing PowerShell modules"
    return $true
  } catch {
    LogError "An error occurred while installing PowerShell modules: $_"
    return $false
  }
}

function UninstallPowerShellModules {
  try {
    $package_list_path = "$SCRIPT_DIR/requirement/powershell.txt"
    if (-not (Test-Path $package_list_path)) {
      LogWarning "Package list not found: $package_list_path"
      return $false
    }
    LogInfo "Uninstalling PowerShell modules"
    $packages = @(Get-Content $package_list_path | Where-Object { $_ -and $_ -notmatch '^\s*#' })
    $total = $packages.Count
    $current = 0
    $failed_packages = @()
    foreach ($package in $packages) {
      $current++
      LogInfo "[$current/$total] Uninstalling: $package"
      if (-not (UninstallPowerShellModule -module_name $package)) {
        $failed_packages += $package
        LogError "Failed to uninstall: $package"
      }
    }
    if ($failed_packages.Count -gt 0) {
      LogError "Failed to uninstall PowerShell modules : $($failed_packages -join ', ')"
      return $false
    }
    LogSuccess "Completed uninstalling PowerShell modules"
    return $true
  } catch {
    LogError "An error occurred while uninstalling PowerShell modules: $_"
    return $false
  }
}

function InstallScoopPackages {
  try {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
      LogWarning "Scoop is not installed. Installing..."
      Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
      $scoop_installer = Join-Path $env:TEMP "install-scoop.ps1"
      Invoke-RestMethod -Uri https://get.scoop.sh -OutFile $scoop_installer
      & $scoop_installer | Out-Host
      Remove-Item -Path $scoop_installer -Force -ErrorAction SilentlyContinue
    }
    $failed_steps = @()
    if (-not (InstallPackage -PackageName "Scoop buckets" -PackageListPath "$SCRIPT_DIR/requirement/scoop-bucket.txt" -InstallCommand "scoop bucket add")) { $failed_steps += "Scoop buckets" }
    if (-not (InstallPackage -PackageName "Scoop packages" -PackageListPath "$SCRIPT_DIR/requirement/scoop-package.txt" -InstallCommand "scoop install")) { $failed_steps += "Scoop packages" }
    if (-not (InstallPackage -PackageName "Scoop applications" -PackageListPath "$SCRIPT_DIR/requirement/scoop-application.txt" -InstallCommand "scoop install")) { $failed_steps += "Scoop applications" }
    if (-not (InstallPackage -PackageName "Scoop fonts" -PackageListPath "$SCRIPT_DIR/requirement/scoop-font.txt" -InstallCommand "scoop install")) { $failed_steps += "Scoop fonts" }
    if ($failed_steps.Count -gt 0) {
      LogError "Scoop package installation failed: $($failed_steps -join ', ')"
      return $false
    }
    return $true
  } catch {
    LogError "An error occurred while installing Scoop packages: $_"
    return $false
  }
}

function UninstallScoopPackages {
  try {
    $failed_steps = @()
    if (-not (UninstallPackage -PackageName "Scoop fonts" -PackageListPath "$SCRIPT_DIR/requirement/scoop-font.txt" -UninstallCommand "scoop uninstall")) { $failed_steps += "Scoop fonts" }
    if (-not (UninstallPackage -PackageName "Scoop applications" -PackageListPath "$SCRIPT_DIR/requirement/scoop-application.txt" -UninstallCommand "scoop uninstall")) { $failed_steps += "Scoop applications" }
    if (-not (UninstallPackage -PackageName "Scoop packages" -PackageListPath "$SCRIPT_DIR/requirement/scoop-package.txt" -UninstallCommand "scoop uninstall")) { $failed_steps += "Scoop packages" }
    if ($failed_steps.Count -gt 0) {
      LogError "Scoop package uninstallation failed: $($failed_steps -join ', ')"
      return $false
    }
    return $true
  } catch {
    LogError "An error occurred while uninstalling Scoop packages: $_"
    return $false
  }
}

function InstallNodeJS {
  try {
    if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
      LogWarning "NVM is not installed. Installing Scoop first..."
      if (-not (InstallScoopPackages)) {
        return $false
      }
    }
    LogInfo "Installing Node.js LTS version"
    nvm install lts | Out-Host
    if ($LASTEXITCODE -ne 0) {
      LogError "Failed to install Node.js LTS"
      return $false
    }
    LogInfo "Using Node.js LTS version"
    nvm use lts | Out-Host
    if ($LASTEXITCODE -ne 0) {
      LogError "Failed to switch to Node.js LTS"
      return $false
    }
    LogSuccess "Node.js LTS installed successfully"
    return $true
  } catch {
    LogError "An error occurred while installing Node.js LTS: $_"
    return $false
  }
}

function UninstallNodeJS {
  try {
    if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
      LogWarning "NVM is not installed"
      return $false
    }
    LogInfo "Uninstalling Node.js LTS version"
    nvm uninstall lts | Out-Host
    if ($LASTEXITCODE -ne 0) {
      LogError "Failed to uninstall Node.js LTS"
      return $false
    }
    LogSuccess "Node.js LTS uninstalled successfully"
    return $true
  } catch {
    LogError "An error occurred while uninstalling Node.js LTS: $_"
    return $false
  }
}

function InstallNPMPackages {
  try {
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
      LogWarning "Node.js is not installed. Installing..."
      if (-not (InstallNodeJS)) {
        return $false
      }
    }
    return (InstallPackage -PackageName "NPM packages" -PackageListPath "$SCRIPT_DIR/requirement/npm.txt" -InstallCommand "npm install -g")
  } catch {
    LogError "An error occurred while installing NPM packages: $_"
    return $false
  }
}

function UninstallNPMPackages {
  try {
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
      LogWarning "Node.js is not installed"
      return $false
    }
    return (UninstallPackage -PackageName "NPM packages" -PackageListPath "$SCRIPT_DIR/requirement/npm.txt" -UninstallCommand "npm uninstall -g")
  } catch {
    LogError "An error occurred while uninstalling NPM packages: $_"
    return $false
  }
}

function InstallVSCodeExtensions {
  try {
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
      LogWarning "VSCode is not installed. Installing via Scoop..."
      if (-not (InstallScoopPackages)) {
        return $false
      }
    }
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
      LogError "VSCode command is still unavailable after package installation"
      return $false
    }
    return (InstallPackage -PackageName "VSCode extensions" -PackageListPath "$SCRIPT_DIR/requirement/code.txt" -InstallCommand "code --install-extension" -AdditionalParams "--force")
  } catch {
    LogError "An error occurred while installing VSCode extensions: $_"
    return $false
  }
}

function UninstallVSCodeExtensions {
  try {
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
      LogWarning "VSCode is not installed"
      return $false
    }
    return (UninstallPackage -PackageName "VSCode extensions" -PackageListPath "$SCRIPT_DIR/requirement/code.txt" -UninstallCommand "code --uninstall-extension")
  } catch {
    LogError "An error occurred while uninstalling VSCode extensions: $_"
    return $false
  }
}

function InstallSkills {
  try {
    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
      LogWarning "Node.js is not installed. Cannot run npx."
      return $false
    }
    return (InstallPackage -PackageName "Skills" -PackageListPath "$SCRIPT_DIR/requirement/skills.txt" -InstallCommand "npx skills add")
  } catch {
    LogError "An error occurred while installing Skills: $_"
    return $false
  }
}

function UninstallSkills {
  try {
    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
      LogWarning "Node.js is not installed. Cannot run npx."
      return $false
    }
    $skill_list_path = "$SCRIPT_DIR/requirement/skills.txt"
    if (-not (Test-Path $skill_list_path)) {
      LogWarning "Skill list not found: $skill_list_path"
      return $false
    }
    $failed_skills = @()
    $skill_entries = @(Get-Content $skill_list_path | Where-Object { $_ -and $_ -notmatch '^\s*#' })
    foreach ($skill_entry in $skill_entries) {
      $entry_parts = $skill_entry -split '\s+'
      $skill_name = ""
      for ($index = 0; $index -lt $entry_parts.Count; $index++) {
        if ($entry_parts[$index] -eq "--skill" -or $entry_parts[$index] -eq "-s") {
          if ($index + 1 -lt $entry_parts.Count) {
            $skill_name = $entry_parts[$index + 1]
          }
          break
        }
      }
      if ([string]::IsNullOrWhiteSpace($skill_name)) {
        LogError "Cannot determine skill name from: $skill_entry"
        $failed_skills += $skill_entry
        continue
      }
      LogInfo "Uninstalling skill: $skill_name"
      if (-not (InvokePackageCommand -CommandText "npx skills remove" -Package $skill_name)) {
        $failed_skills += $skill_name
        LogError "Failed to uninstall skill: $skill_name"
      }
    }
    if ($failed_skills.Count -gt 0) {
      LogError "Failed to uninstall Skills: $($failed_skills -join ', ')"
      return $false
    }
    LogSuccess "Completed uninstalling Skills"
    return $true
  } catch {
    LogError "An error occurred while uninstalling Skills: $_"
    return $false
  }
}

function InstallAllPackages {
  $failed_steps = @()
  if (-not (InstallPowerShellModules)) { $failed_steps += "PowerShell modules" }
  if (-not (InstallScoopPackages)) { $failed_steps += "Scoop packages" }
  if (-not (InstallNodeJS)) { $failed_steps += "Node.js" }
  if (-not (InstallNPMPackages)) { $failed_steps += "NPM packages" }
  if (-not (InstallVSCodeExtensions)) { $failed_steps += "VSCode extensions" }
  if (-not (InstallSkills)) { $failed_steps += "Skills" }
  if ($failed_steps.Count -gt 0) {
    LogError "Package installation failed: $($failed_steps -join ', ')"
    return $false
  }
  LogSuccess "All packages installed successfully"
  return $true
}

function UninstallAllPackages {
  $failed_steps = @()
  if (-not (UninstallPowerShellModules)) { $failed_steps += "PowerShell modules" }
  if (-not (UninstallScoopPackages)) { $failed_steps += "Scoop packages" }
  if (-not (UninstallNodeJS)) { $failed_steps += "Node.js" }
  if (-not (UninstallNPMPackages)) { $failed_steps += "NPM packages" }
  if (-not (UninstallVSCodeExtensions)) { $failed_steps += "VSCode extensions" }
  if (-not (UninstallSkills)) { $failed_steps += "Skills" }
  if ($failed_steps.Count -gt 0) {
    LogError "Package uninstallation failed: $($failed_steps -join ', ')"
    return $false
  }
  LogSuccess "All packages uninstalled successfully"
  return $true
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
      return $false
    }
    if (Test-Path $DestinationPath) {
      if ($Extensions.Count -eq 0 -and $Files.Count -eq 0) {
        LogInfo "Cleaning destination: $DestinationPath"
        Remove-Item -Path "$DestinationPath" -Recurse -Force
        New-Item -Path "$DestinationPath" -ItemType Directory -Force | Out-Null
      } else {
        if ($Extensions.Count -gt 0) {
          foreach ($extension in $Extensions) {
            Get-ChildItem -Path "$DestinationPath" -Filter "*.$extension" -ErrorAction SilentlyContinue | Remove-Item -Force
          }
        }
        if ($Files.Count -gt 0) {
          foreach ($file in $Files) {
            $target_file = Join-Path $DestinationPath $file
            if (Test-Path $target_file) {
              Remove-Item -Path $target_file -Force
            }
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
    return $true
  } catch {
    LogError "An error occurred while configuring $AppName : $_"
    return $false
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
            Get-ChildItem -Path "$DestinationPath" -Filter "*.$extension" -ErrorAction SilentlyContinue | Remove-Item -Force
          }
        }
        if ($Files.Count -gt 0) {
          foreach ($file in $Files) {
            $target_file = Join-Path $DestinationPath $file
            if (Test-Path $target_file) {
              Remove-Item -Path $target_file -Force
            }
          }
        }
        LogSuccess "Removed $AppName configuration files"
      }
    } else {
      LogWarning "Configuration path not found: $DestinationPath"
      return $false
    }
    return $true
  } catch {
    LogError "An error occurred while removing $AppName configuration: $_"
    return $false
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
  $failed_steps = @()
  if (-not (SetApplicationConfig -AppName "Windows PowerShell" -SourcePath "$SCRIPT_DIR/config/powershell" -DestinationPath "$powershell_path/WindowsPowerShell" -Extensions @("txt", "json", "ps1"))) {
    $failed_steps += "Windows PowerShell"
  }
  if (Test-Path "$powershell_path/WindowsPowerShell/microsoft.powershell_profile.ps1") {
    Rename-Item -Path "$powershell_path/WindowsPowerShell/microsoft.powershell_profile.ps1" -NewName "Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
  }
  if (Test-Path "$powershell_path/WindowsPowerShell/Modules") {
    Copy-Item -Path "$powershell_path/WindowsPowerShell/Modules/*" -ErrorAction SilentlyContinue -Destination "$powershell_path/PowerShell/Modules" -Recurse -Force
  }
  if (-not (SetApplicationConfig -AppName "PowerShell" -SourcePath "$SCRIPT_DIR/config/powershell" -DestinationPath "$powershell_path/PowerShell" -Extensions @("txt", "json", "ps1"))) {
    $failed_steps += "PowerShell"
  }
  if (Test-Path "$powershell_path/PowerShell/microsoft.powershell_profile.ps1") {
    Rename-Item -Path "$powershell_path/PowerShell/microsoft.powershell_profile.ps1" -NewName "Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
  }
  if (Test-Path "$powershell_path/PowerShell/Modules") {
    Copy-Item -Path "$powershell_path/PowerShell/Modules/*" -ErrorAction SilentlyContinue -Destination "$powershell_path/WindowsPowerShell/Modules" -Recurse -Force
  }
  if ($failed_steps.Count -gt 0) {
    LogError "PowerShell configuration failed: $($failed_steps -join ', ')"
    return $false
  }
  return $true
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
  $failed_steps = @()
  if (-not (RemoveApplicationConfig -AppName "Windows PowerShell" -DestinationPath "$powershell_path/WindowsPowerShell")) { $failed_steps += "Windows PowerShell" }
  if (-not (RemoveApplicationConfig -AppName "PowerShell" -DestinationPath "$powershell_path/PowerShell")) { $failed_steps += "PowerShell" }
  if ($failed_steps.Count -gt 0) {
    LogError "PowerShell configuration removal failed: $($failed_steps -join ', ')"
    return $false
  }
  return $true
}

function SetWindowsTerminalConfig {
  SetApplicationConfig -AppName "Windows Terminal" -SourcePath "$SCRIPT_DIR/config/windows-terminal" -DestinationPath "$ENV:USERPROFILE/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState" -Files @("settings.json")
}

function RemoveWindowsTerminalConfig {
  RemoveApplicationConfig -AppName "Windows Terminal" -DestinationPath "$ENV:USERPROFILE/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState" -Files @("settings.json")
}

function SetScriptConfig {
  SetApplicationConfig -AppName "Script" -SourcePath "$SCRIPT_DIR/script" -DestinationPath "$ENV:USERPROFILE/AppData/Local/script"
}

function RemoveScriptConfig {
  RemoveApplicationConfig -AppName "Script" -DestinationPath "$ENV:USERPROFILE/AppData/Local/script"
}

function SetPythonConfig {
  SetApplicationConfig -AppName "Python (pip)" -SourcePath "$SCRIPT_DIR/config/pip" -DestinationPath "$ENV:USERPROFILE/AppData/Roaming/pip"
}

function RemovePythonConfig {
  RemoveApplicationConfig -AppName "Python (pip)" -DestinationPath "$ENV:USERPROFILE/AppData/Roaming/pip"
}

function SetWarpConfig {
  SetApplicationConfig -AppName "Warp" -SourcePath "$SCRIPT_DIR/config/warp" -DestinationPath "$ENV:USERPROFILE/AppData/Roaming/warp/Warp/data/themes" -Extensions @("yaml")
}

function RemoveWarpConfig {
  RemoveApplicationConfig -AppName "Warp" -DestinationPath "$ENV:USERPROFILE/AppData/Roaming/warp/Warp/data/themes" -Extensions @("yaml")
}

function SetVimConfig {
  SetApplicationConfig -AppName "Vim" -SourcePath "$SCRIPT_DIR/config/vim" -DestinationPath "$ENV:USERPROFILE" -Files @(".vimrc")
}

function RemoveVimConfig {
  RemoveApplicationConfig -AppName "Vim" -DestinationPath "$ENV:USERPROFILE" -Files @(".vimrc")
}

function SetNeovimConfig {
  SetApplicationConfig -AppName "Neovim" -SourcePath "$SCRIPT_DIR/config/nvim" -DestinationPath "$ENV:LOCALAPPDATA/nvim"
}

function RemoveNeovimConfig {
  RemoveApplicationConfig -AppName "Neovim" -DestinationPath "$ENV:LOCALAPPDATA/nvim"
}

function SetLazyGitConfig {
  SetApplicationConfig -AppName "Lazygit" -SourcePath "$SCRIPT_DIR/config/lazygit" -DestinationPath "$ENV:USERPROFILE/AppData/Local/lazygit"
}

function RemoveLazyGitConfig {
  RemoveApplicationConfig -AppName "Lazygit" -DestinationPath "$ENV:USERPROFILE/AppData/Local/lazygit"
}

function SetCommitizenConfig {
  SetApplicationConfig -AppName "Commitizen" -SourcePath "$SCRIPT_DIR/config/commitizen" -DestinationPath "$ENV:USERPROFILE" -Files @(".czrc")
}

function RemoveCommitizenConfig {
  RemoveApplicationConfig -AppName "Commitizen" -DestinationPath "$ENV:USERPROFILE" -Files @(".czrc")
}

function SetVSCodeConfig {
  if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    LogWarning "VSCode is not installed. Installing via Scoop..."
    if (-not (InstallScoopPackages)) {
      return $false
    }
  }
  if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    LogError "VSCode command is still unavailable after package installation"
    return $false
  }
  $vscode_path = ""
  $paths = Get-Command code -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
  foreach ($path in $paths) {
    if ($path -like "*Microsoft VS Code*") {
      $vscode_path = "$ENV:USERPROFILE/AppData/Roaming/Code/User"
      break
    } elseif ($path -like "*scoop\apps\vscode\current\*") {
      $vscode_path = "$ENV:USERPROFILE/scoop/apps/vscode/current/data/user-data/User"
      break
    }
  }
  if (-not $vscode_path) {
    $vscode_path = "$ENV:USERPROFILE/AppData/Roaming/Code/User"
  }
  return (SetApplicationConfig -AppName "VSCode" -SourcePath "$SCRIPT_DIR/config/visual-studio-code" -DestinationPath "$vscode_path" -Extensions @("json"))
}

function RemoveVSCodeConfig {
  if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    LogWarning "VSCode is not installed"
    return
  }
  $vscode_path = ""
  $paths = Get-Command code -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
  foreach ($path in $paths) {
    if ($path -like "*Microsoft VS Code*") {
      $vscode_path = "$ENV:USERPROFILE/AppData/Roaming/Code/User"
      break
    } elseif ($path -like "*scoop\apps\vscode\current\*") {
      $vscode_path = "$ENV:USERPROFILE/scoop/apps/vscode/current/data/user-data/User"
      break
    }
  }
  if (-not $vscode_path) {
    $vscode_path = "$ENV:USERPROFILE/AppData/Roaming/Code/User"
  }
  RemoveApplicationConfig -AppName "VSCode" -DestinationPath "$vscode_path" -Extensions @("json")
}

function SetGitConfig {
  SetApplicationConfig -AppName "Git" -SourcePath "$SCRIPT_DIR/.gitconfig" -DestinationPath "$ENV:USERPROFILE" -Files @(".gitconfig")
}

function RemoveGitConfig {
  RemoveApplicationConfig -AppName "Git" -DestinationPath "$ENV:USERPROFILE" -Files @(".gitconfig")
}

function SetAllApplicationConfigs {
  $failed_steps = @()
  if (-not (SetPowerShellConfig)) { $failed_steps += "PowerShell" }
  if (-not (SetWindowsTerminalConfig)) { $failed_steps += "Windows Terminal" }
  if (-not (SetScriptConfig)) { $failed_steps += "Script" }
  if (-not (SetPythonConfig)) { $failed_steps += "Python" }
  if (-not (SetWarpConfig)) { $failed_steps += "Warp" }
  if (-not (SetVimConfig)) { $failed_steps += "Vim" }
  if (-not (SetNeovimConfig)) { $failed_steps += "Neovim" }
  if (-not (SetGitConfig)) { $failed_steps += "Git" }
  if (-not (SetLazyGitConfig)) { $failed_steps += "Lazygit" }
  if (-not (SetCommitizenConfig)) { $failed_steps += "Commitizen" }
  if (-not (SetVSCodeConfig)) { $failed_steps += "VSCode" }
  if ($failed_steps.Count -gt 0) {
    LogError "Application configuration failed: $($failed_steps -join ', ')"
    return $false
  }
  LogSuccess "All applications configured successfully"
  return $true
}

function RemoveAllApplicationConfigs {
  $failed_steps = @()
  if (-not (RemovePowerShellConfig)) { $failed_steps += "PowerShell" }
  if (-not (RemoveWindowsTerminalConfig)) { $failed_steps += "Windows Terminal" }
  if (-not (RemoveScriptConfig)) { $failed_steps += "Script" }
  if (-not (RemovePythonConfig)) { $failed_steps += "Python" }
  if (-not (RemoveWarpConfig)) { $failed_steps += "Warp" }
  if (-not (RemoveVimConfig)) { $failed_steps += "Vim" }
  if (-not (RemoveNeovimConfig)) { $failed_steps += "Neovim" }
  if (-not (RemoveGitConfig)) { $failed_steps += "Git" }
  if (-not (RemoveLazyGitConfig)) { $failed_steps += "Lazygit" }
  if (-not (RemoveCommitizenConfig)) { $failed_steps += "Commitizen" }
  if (-not (RemoveVSCodeConfig)) { $failed_steps += "VSCode" }
  if ($failed_steps.Count -gt 0) {
    LogError "Application configuration removal failed: $($failed_steps -join ', ')"
    return $false
  }
  LogSuccess "All configurations removed successfully"
  return $true
}

function InvokeMenuAction {
  param (
    [scriptblock]$Action
  )
  & $Action
}

function Main {
  if (-not (CheckInstallCompatibility)) {
    exit 1
  }
  do {
    ShowMenu
    $choice = Read-Host "Enter your choice"
    switch ($choice) {
      "1" { InvokeMenuAction { InstallPowerShellModules } }
      "2" { InvokeMenuAction { InstallScoopPackages } }
      "3" { InvokeMenuAction { InstallNodeJS } }
      "4" { InvokeMenuAction { InstallNPMPackages } }
      "5" { InvokeMenuAction { InstallVSCodeExtensions } }
      "6" { InvokeMenuAction { InstallSkills } }
      "7" { InvokeMenuAction { InstallAllPackages } }
      "8" { InvokeMenuAction { UninstallPowerShellModules } }
      "9" { InvokeMenuAction { UninstallScoopPackages } }
      "10" { InvokeMenuAction { UninstallNodeJS } }
      "11" { InvokeMenuAction { UninstallNPMPackages } }
      "12" { InvokeMenuAction { UninstallVSCodeExtensions } }
      "13" { InvokeMenuAction { UninstallSkills } }
      "14" { InvokeMenuAction { UninstallAllPackages } }
      "15" { InvokeMenuAction { SetPowerShellConfig } }
      "16" { InvokeMenuAction { SetWindowsTerminalConfig } }
      "17" { InvokeMenuAction { SetScriptConfig } }
      "18" { InvokeMenuAction { SetPythonConfig } }
      "19" { InvokeMenuAction { SetWarpConfig } }
      "20" { InvokeMenuAction { SetVimConfig } }
      "21" { InvokeMenuAction { SetNeovimConfig } }
      "22" { InvokeMenuAction { SetGitConfig } }
      "23" { InvokeMenuAction { SetLazyGitConfig } }
      "24" { InvokeMenuAction { SetCommitizenConfig } }
      "25" { InvokeMenuAction { SetVSCodeConfig } }
      "26" { InvokeMenuAction { SetAllApplicationConfigs } }
      "27" { InvokeMenuAction { RemovePowerShellConfig } }
      "28" { InvokeMenuAction { RemoveWindowsTerminalConfig } }
      "29" { InvokeMenuAction { RemoveScriptConfig } }
      "30" { InvokeMenuAction { RemovePythonConfig } }
      "31" { InvokeMenuAction { RemoveWarpConfig } }
      "32" { InvokeMenuAction { RemoveVimConfig } }
      "33" { InvokeMenuAction { RemoveNeovimConfig } }
      "34" { InvokeMenuAction { RemoveGitConfig } }
      "35" { InvokeMenuAction { RemoveLazyGitConfig } }
      "36" { InvokeMenuAction { RemoveCommitizenConfig } }
      "37" { InvokeMenuAction { RemoveVSCodeConfig } }
      "38" { InvokeMenuAction { RemoveAllApplicationConfigs } }
      "q" { break }
      default { LogWarning "Invalid choice. Please try again." }
    }
  } while ($choice -ne "q")
}

Main
