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
  New-Item -ItemType Directory -Path "$powershell_path/WindowsPowerShell/Modules" -Force | Out-Null
  New-Item -ItemType Directory -Path "$powershell_path/PowerShell/Modules" -Force | Out-Null
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
  $script_source_path = Join-Path $SCRIPT_DIR "script"
  $script_destination_path = Join-Path $ENV:USERPROFILE "AppData/Local/script"
  $shell_utils_source_path = Join-Path $SCRIPT_DIR "utils/shell"
  $shell_utils_destination_path = Join-Path $script_destination_path "utils"
  $failed_steps = @()

  if (-not (SetApplicationConfig -AppName "Script" -SourcePath $script_source_path -DestinationPath $script_destination_path)) {
    $failed_steps += "Script"
  }
  if (-not (SetApplicationConfig -AppName "Shell utilities" -SourcePath $shell_utils_source_path -DestinationPath $shell_utils_destination_path)) {
    $failed_steps += "Shell utilities"
  }
  if ($failed_steps.Count -gt 0) {
    LogError "Script configuration failed: $($failed_steps -join ', ')"
    return $false
  }
  return $true
}

function RemoveScriptConfig {
  $script_destination_path = Join-Path $ENV:USERPROFILE "AppData/Local/script"
  $shell_utils_destination_path = Join-Path $script_destination_path "utils"
  $script_destination_exists = Test-Path -LiteralPath $script_destination_path
  $shell_utils_destination_exists = Test-Path -LiteralPath $shell_utils_destination_path

  if (-not $script_destination_exists -and -not $shell_utils_destination_exists) {
    LogWarning "Configuration path not found: $script_destination_path"
    return $false
  }

  $failed_steps = @()

  if ($shell_utils_destination_exists -and -not (RemoveApplicationConfig -AppName "Shell utilities" -DestinationPath $shell_utils_destination_path)) {
    $failed_steps += "Shell utilities"
  }
  if ($script_destination_exists -and -not (RemoveApplicationConfig -AppName "Script" -DestinationPath $script_destination_path)) {
    $failed_steps += "Script"
  }
  if ($failed_steps.Count -gt 0) {
    LogError "Script configuration removal failed: $($failed_steps -join ', ')"
    return $false
  }
  return $true
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
  if (-not (SetPHPConfig)) { $failed_steps += "PHP" }
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
  if (-not (RemovePHPConfig)) { $failed_steps += "PHP" }
  if ($failed_steps.Count -gt 0) {
    LogError "Application configuration removal failed: $($failed_steps -join ', ')"
    return $false
  }
  LogSuccess "All configurations removed successfully"
  return $true
}
