$NPM_ALLOWED_SCRIPT_PACKAGES = "@openai/codex,@anthropic-ai/claude-code"

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

function SetNPMAllowScripts {
  try {
    LogInfo "Setting NPM allow-scripts: $NPM_ALLOWED_SCRIPT_PACKAGES"
    npm config set "allow-scripts=$NPM_ALLOWED_SCRIPT_PACKAGES" --location=user | Out-Host
    if ($LASTEXITCODE -ne 0) {
      LogError "Failed to set NPM allow-scripts"
      return $false
    }
    LogSuccess "NPM allow-scripts configured successfully"
    return $true
  } catch {
    LogError "An error occurred while setting NPM allow-scripts: $_"
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
    if (-not (SetNPMAllowScripts)) {
      return $false
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
