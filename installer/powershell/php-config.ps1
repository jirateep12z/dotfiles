$PHP_EXTENSION_SETTING_PATTERN = '^extension\s*=\s*([A-Za-z0-9_]+)$'
$PHP_DIRECTIVE_SETTING_PATTERN = '^([A-Za-z0-9_.]+)\s*=\s*(.+)$'
$SCOOP_PHP_APP_PATTERN = '[\\/]apps[\\/]([^\\/]+)[\\/][^\\/]+[\\/]php\.exe$'

function ReadPHPSettings {
  param (
    [string]$SettingsPath
  )
  $extensions = @()
  $directives = [ordered]@{}
  foreach ($setting_line in (Get-Content -LiteralPath $SettingsPath -ErrorAction Stop)) {
    $trimmed_line = $setting_line.Trim()
    if (-not $trimmed_line -or $trimmed_line.StartsWith(";")) {
      continue
    }
    if ($trimmed_line -match $PHP_EXTENSION_SETTING_PATTERN) {
      $extensions += $Matches[1]
    } elseif ($trimmed_line -match $PHP_DIRECTIVE_SETTING_PATTERN) {
      $directives[$Matches[1]] = $Matches[2].Trim()
    } else {
      throw "Invalid PHP setting line: $trimmed_line"
    }
  }
  return @{ extensions = $extensions; directives = $directives }
}

function SetPHPIniDirective {
  param (
    [string[]]$Lines,
    [string]$Key,
    [string]$Value
  )
  $escaped_key = [regex]::Escape($Key)
  $directive_line = "$Key = $Value"
  $line_patterns = @("^\s*$escaped_key\s*=", "^\s*;\s*$escaped_key\s*=")
  foreach ($line_pattern in $line_patterns) {
    for ($index = 0; $index -lt $Lines.Count; $index++) {
      if ($Lines[$index] -cmatch $line_pattern) {
        $updated_lines = [string[]]$Lines.Clone()
        $updated_lines[$index] = $directive_line
        return , $updated_lines
      }
    }
  }
  return , [string[]]($Lines + $directive_line)
}

function EnablePHPIniExtension {
  param (
    [string[]]$Lines,
    [string]$Name
  )
  $escaped_name = [regex]::Escape($Name)
  $extension_pattern = "^\s*(;\s*)?extension\s*=\s*(php_)?$escaped_name(\.dll)?\s*$"
  $extension_line = "extension=$Name"
  $commented_index = -1
  for ($index = 0; $index -lt $Lines.Count; $index++) {
    if ($Lines[$index] -cmatch $extension_pattern) {
      if (-not $Matches[1]) {
        return , $Lines
      }
      if ($commented_index -lt 0) {
        $commented_index = $index
      }
    }
  }
  if ($commented_index -ge 0) {
    $updated_lines = [string[]]$Lines.Clone()
    $updated_lines[$commented_index] = $extension_line
    return , $updated_lines
  }
  return , [string[]]($Lines + $extension_line)
}

function UpdatePHPIniContent {
  param (
    [string]$Content,
    [string]$ExtensionDirectory,
    [hashtable]$Settings
  )
  $line_ending = if ($Content.Contains("`r`n")) { "`r`n" } else { "`n" }
  $lines = [string[]]($Content -split "\r?\n")
  $has_trailing_line_ending = $Content.EndsWith("`n")
  if ($has_trailing_line_ending -or $Content -eq "") {
    $lines = if ($lines.Count -gt 1) { [string[]]$lines[0..($lines.Count - 2)] } else { [string[]]@() }
  }
  $lines = SetPHPIniDirective -Lines $lines -Key "extension_dir" -Value "`"$ExtensionDirectory`""
  foreach ($extension_name in $Settings.extensions) {
    $lines = EnablePHPIniExtension -Lines $lines -Name $extension_name
  }
  foreach ($directive_key in $Settings.directives.Keys) {
    $lines = SetPHPIniDirective -Lines $lines -Key $directive_key -Value $Settings.directives[$directive_key]
  }
  $updated_content = $lines -join $line_ending
  if ($has_trailing_line_ending) {
    $updated_content += $line_ending
  }
  return $updated_content
}

function GetScoopPHPApp {
  $php_shim_target = scoop which php 2>$null | Select-Object -Last 1
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($php_shim_target)) {
    return $null
  }
  if ("$php_shim_target".Trim() -notmatch $SCOOP_PHP_APP_PATTERN) {
    return $null
  }
  $scoop_php_app_name = $Matches[1]
  $scoop_php_path = scoop prefix $scoop_php_app_name 2>$null | Select-Object -Last 1
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($scoop_php_path)) {
    return $null
  }
  $scoop_php_path = "$scoop_php_path".Trim()
  if (-not (Test-Path -LiteralPath $scoop_php_path -PathType Container)) {
    return $null
  }
  return @{ name = $scoop_php_app_name; path = $scoop_php_path }
}

function SetPHPConfig {
  try {
    LogInfo "Configuring PHP"
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
      LogWarning "Scoop is not installed"
      return $false
    }
    $scoop_php_app = GetScoopPHPApp
    if (-not $scoop_php_app) {
      LogWarning "Scoop PHP is not installed"
      return $false
    }
    $scoop_php_path = $scoop_php_app.path
    LogInfo "Using Scoop PHP app: $($scoop_php_app.name)"
    $settings_path = "$SCRIPT_DIR/config/php/php.ini"
    if (-not (Test-Path -LiteralPath $settings_path)) {
      LogWarning "Source path not found: $settings_path"
      return $false
    }
    $php_settings = ReadPHPSettings -SettingsPath $settings_path
    $php_ini_directory = Join-Path $scoop_php_path "cli"
    $php_ini_path = Join-Path $php_ini_directory "php.ini"
    if (-not (Test-Path -LiteralPath $php_ini_path)) {
      LogError "PHP configuration file not found: $php_ini_path"
      return $false
    }
    $current_content = [System.IO.File]::ReadAllText($php_ini_path)
    $updated_content = UpdatePHPIniContent -Content $current_content -ExtensionDirectory (Join-Path $scoop_php_path "ext") -Settings $php_settings
    if (-not (InvokePackageCommand -CommandText "scoop reset" -Package $scoop_php_app.name)) {
      LogError "Failed to reset Scoop PHP"
      return $false
    }
    [Environment]::SetEnvironmentVariable("PHP_INI_SCAN_DIR", $null, "User")
    Remove-Item -Path Env:PHP_INI_SCAN_DIR -ErrorAction SilentlyContinue
    [Environment]::SetEnvironmentVariable("PHPRC", $php_ini_directory, "User")
    $env:PHPRC = $php_ini_directory
    if ($updated_content -cne $current_content) {
      [System.IO.File]::WriteAllText($php_ini_path, $updated_content, [System.Text.UTF8Encoding]::new($false))
      LogInfo "Updated $php_ini_path"
    } else {
      LogInfo "PHP settings are already up to date"
    }
    LogSuccess "PHP configured successfully"
    LogInfo "Open a new terminal to apply the environment changes"
    LogInfo "Run Configure PHP again after switching PHP versions with scoop reset <app> or after scoop update"
    return $true
  } catch {
    LogError "An error occurred while configuring PHP : $_"
    return $false
  }
}

function RemovePHPConfig {
  try {
    LogInfo "Removing PHP configuration"
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
      LogWarning "Scoop is not installed"
      return $false
    }
    $scoop_php_app = GetScoopPHPApp
    if (-not $scoop_php_app) {
      LogWarning "Scoop PHP is not installed"
      return $false
    }
    LogInfo "Using Scoop PHP app: $($scoop_php_app.name)"
    if (-not (InvokePackageCommand -CommandText "scoop reset" -Package $scoop_php_app.name)) {
      LogError "Failed to reset Scoop PHP"
      return $false
    }
    [Environment]::SetEnvironmentVariable("PHPRC", $null, "User")
    Remove-Item -Path Env:PHPRC -ErrorAction SilentlyContinue
    LogWarning "XAMPP Apache will fail with 'Entry Point Not Found' while PHP_INI_SCAN_DIR is set"
    LogSuccess "Removed PHP configuration"
    return $true
  } catch {
    LogError "An error occurred while removing PHP configuration: $_"
    return $false
  }
}
