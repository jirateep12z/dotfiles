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

$INSTALLER_MODULES = @("package-command", "packages", "app-config", "configs", "git-config", "php-config", "menu")
foreach ($installer_module in $INSTALLER_MODULES) {
  . "$SCRIPT_DIR/installer/powershell/$installer_module.ps1" 2>$null
  if (-not $?) {
    Write-Error "Error: Cannot load $installer_module.ps1 installer module"
    exit 1
  }
}

function CheckInstallCompatibility {
  $is_windows = $IsWindows -or $env:OS -eq "Windows_NT"
  if (-not $is_windows) {
    LogError "This install script only supports Windows (detected: $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription))"
    return $false
  }
  return $true
}

function Main {
  if (-not (CheckInstallCompatibility)) {
    exit 1
  }
  do {
    ShowMenu
    $choice = Read-Host "Enter your choice"
    Write-Host ""
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
      "26" { InvokeMenuAction { SetPHPConfig } }
      "27" { InvokeMenuAction { SetAllApplicationConfigs } }
      "28" { InvokeMenuAction { RemovePowerShellConfig } }
      "29" { InvokeMenuAction { RemoveWindowsTerminalConfig } }
      "30" { InvokeMenuAction { RemoveScriptConfig } }
      "31" { InvokeMenuAction { RemovePythonConfig } }
      "32" { InvokeMenuAction { RemoveWarpConfig } }
      "33" { InvokeMenuAction { RemoveVimConfig } }
      "34" { InvokeMenuAction { RemoveNeovimConfig } }
      "35" { InvokeMenuAction { RemoveGitConfig } }
      "36" { InvokeMenuAction { RemoveLazyGitConfig } }
      "37" { InvokeMenuAction { RemoveCommitizenConfig } }
      "38" { InvokeMenuAction { RemoveVSCodeConfig } }
      "39" { InvokeMenuAction { RemovePHPConfig } }
      "40" { InvokeMenuAction { RemoveAllApplicationConfigs } }
      "q" { break }
      default { LogWarning "Invalid choice. Please try again." }
    }
  } while ($choice -ne "q")
}

Main
