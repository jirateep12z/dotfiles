$GIT_IDENTITY_PROVIDERS = @(
  @{ name = "GitHub"; slug = "github" },
  @{ name = "GitLab"; slug = "gitlab" }
)
$GIT_EMAIL_PATTERN = '^[^@\s]+@[^@\s]+$'
$GIT_REQUIRED_PATTERN = '\S'
$GIT_GLOB_PATTERN = '[*?\[]'

function ReadGitPromptValue {
  param (
    [string]$Prompt,
    [string]$DefaultValue = ""
  )
  $prompt_text = $Prompt
  if ($DefaultValue) {
    $prompt_text = "$Prompt (default: $DefaultValue)"
  }
  $answer = Read-Host $prompt_text
  if ($null -eq $answer) {
    throw "Input closed while reading: $Prompt"
  }
  $answer = $answer.Trim()
  if ($answer) {
    return $answer
  }
  return $DefaultValue
}

function ReadGitIdentityAnswer {
  param (
    [string]$Prompt,
    [string]$DefaultValue = "",
    [string]$Pattern,
    [string]$InvalidMessage
  )
  while ($true) {
    $answer = ReadGitPromptValue -Prompt $Prompt -DefaultValue $DefaultValue
    if ($answer -match $Pattern) {
      return $answer
    }
    LogWarning $InvalidMessage
  }
}

function ConvertToGitDirectoryPattern {
  param (
    [string]$DirectoryPath
  )
  $directory_pattern = $DirectoryPath -replace '\\', '/'
  if (-not $directory_pattern.EndsWith("/")) {
    $directory_pattern += "/"
  }
  return $directory_pattern
}

function NewGitIdentityDirectory {
  param (
    [string]$DirectoryPattern
  )
  $directory_path = $DirectoryPattern
  if ($directory_path.StartsWith("~/")) {
    $directory_path = Join-Path $ENV:USERPROFILE $directory_path.Substring(2)
  }
  if (-not [System.IO.Path]::IsPathRooted($directory_path) -or $directory_path -match $GIT_GLOB_PATTERN) {
    LogWarning "Skipping folder creation for pattern: $DirectoryPattern"
    return $true
  }
  if (Test-Path -LiteralPath $directory_path -PathType Container) {
    return $true
  }
  try {
    New-Item -ItemType Directory -Path $directory_path -Force -ErrorAction Stop | Out-Null
    if (-not (Test-Path -LiteralPath $directory_path -PathType Container)) {
      throw "A file already exists at this path"
    }
    LogSuccess "Created folder: $directory_path"
    return $true
  } catch {
    LogError "Failed to create folder $directory_path : $_"
    return $false
  }
}

function ReadGitConfigValue {
  param (
    [string]$ConfigFilePath,
    [string]$Key
  )
  if (-not (Test-Path -LiteralPath $ConfigFilePath)) {
    return ""
  }
  $config_value = git config --file $ConfigFilePath --get $Key 2>$null
  if ($LASTEXITCODE -ne 0) {
    return ""
  }
  return "$config_value"
}

function ReadGitIncludeDirectory {
  param (
    [string]$GlobalConfigPath,
    [string]$IdentityFileName
  )
  if (-not (Test-Path -LiteralPath $GlobalConfigPath)) {
    return ""
  }
  $include_entries = @(git config --file $GlobalConfigPath --get-regexp '^includeif\.gitdir/i:.*\.path$' 2>$null)
  foreach ($include_entry in $include_entries) {
    if ($include_entry -match '^includeif\.gitdir/i:(.+)\.path (.+)$' -and $Matches[2] -eq $IdentityFileName) {
      return $Matches[1]
    }
  }
  return ""
}

function ReadGitIdentityAnswers {
  $global_config_path = Join-Path $ENV:USERPROFILE ".gitconfig"
  $identity_answers = @()
  foreach ($provider in $GIT_IDENTITY_PROVIDERS) {
    $identity_file_name = ".gitconfig-$($provider.slug)"
    $identity_file_path = Join-Path $ENV:USERPROFILE $identity_file_name
    $default_directory = ReadGitIncludeDirectory -GlobalConfigPath $global_config_path -IdentityFileName $identity_file_name
    if (-not $default_directory) {
      $default_directory = "~/$($provider.slug)/"
    }
    $default_name = ReadGitConfigValue -ConfigFilePath $identity_file_path -Key "user.name"
    $default_email = ReadGitConfigValue -ConfigFilePath $identity_file_path -Key "user.email"
    while ($true) {
      $directory_answer = ReadGitIdentityAnswer -Prompt "$($provider.name) folder" -DefaultValue $default_directory -Pattern $GIT_REQUIRED_PATTERN -InvalidMessage "Folder is required"
      $identity_directory = ConvertToGitDirectoryPattern -DirectoryPath $directory_answer
      $used_directories = @($identity_answers | Where-Object { $_.directory -ieq $identity_directory })
      if ($used_directories.Count -eq 0) {
        break
      }
      LogWarning "Folder is already used by another provider: $identity_directory"
    }
    $identity_name = ReadGitIdentityAnswer -Prompt "$($provider.name) name" -DefaultValue $default_name -Pattern $GIT_REQUIRED_PATTERN -InvalidMessage "Name is required"
    $identity_email = ReadGitIdentityAnswer -Prompt "$($provider.name) email" -DefaultValue $default_email -Pattern $GIT_EMAIL_PATTERN -InvalidMessage "Email must look like name@example.com"
    $identity_answers += [pscustomobject]@{
      file_name = $identity_file_name
      directory = $identity_directory
      name = $identity_name
      email = $identity_email
    }
  }
  return , $identity_answers
}

function SetGitConfigValue {
  param (
    [string]$ConfigFilePath,
    [string]$Key,
    [string]$Value
  )
  git config --file $ConfigFilePath $Key $Value
  if ($LASTEXITCODE -ne 0) {
    LogError "Failed to write $Key to $ConfigFilePath"
    return $false
  }
  return $true
}

function WriteGitIdentityConfig {
  param (
    [object[]]$IdentityAnswers
  )
  $global_config_path = Join-Path $ENV:USERPROFILE ".gitconfig"
  foreach ($identity_answer in $IdentityAnswers) {
    $identity_file_path = Join-Path $ENV:USERPROFILE $identity_answer.file_name
    if (-not (SetGitConfigValue -ConfigFilePath $identity_file_path -Key "user.name" -Value $identity_answer.name)) { return $false }
    if (-not (SetGitConfigValue -ConfigFilePath $identity_file_path -Key "user.email" -Value $identity_answer.email)) { return $false }
    if (-not (SetGitConfigValue -ConfigFilePath $global_config_path -Key "includeIf.gitdir/i:$($identity_answer.directory).path" -Value $identity_answer.file_name)) { return $false }
  }
  return $true
}

function GetGitConfigFileNames {
  return @(".gitconfig") + @($GIT_IDENTITY_PROVIDERS | ForEach-Object { ".gitconfig-$($_.slug)" })
}

function FormatGitConfigFile {
  param (
    [string]$ConfigFilePath
  )
  try {
    $formatted_lines = [System.Collections.Generic.List[string]]::new()
    foreach ($config_line in @(Get-Content -LiteralPath $ConfigFilePath -ErrorAction Stop)) {
      $is_section_header = $config_line -match '^\['
      $has_previous_content = $formatted_lines.Count -gt 0 -and $formatted_lines[$formatted_lines.Count - 1] -ne ""
      if ($is_section_header -and $has_previous_content) {
        $formatted_lines.Add("")
      }
      $formatted_lines.Add(($config_line -replace '^\t', '  '))
    }
    Set-Content -LiteralPath $ConfigFilePath -Value $formatted_lines -ErrorAction Stop
    return $true
  } catch {
    LogError "Failed to format $ConfigFilePath : $_"
    return $false
  }
}

function SetGitConfig {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    LogError "Git is not installed"
    return $false
  }
  try {
    $identity_answers = ReadGitIdentityAnswers
  } catch {
    LogError "Git identity setup was cancelled: $_"
    return $false
  }
  foreach ($identity_answer in $identity_answers) {
    if (-not (NewGitIdentityDirectory -DirectoryPattern $identity_answer.directory)) {
      return $false
    }
  }
  if (-not (SetApplicationConfig -AppName "Git" -SourcePath "$SCRIPT_DIR/.gitconfig" -DestinationPath "$ENV:USERPROFILE" -Files @(".gitconfig"))) {
    return $false
  }
  if (-not (WriteGitIdentityConfig -IdentityAnswers $identity_answers)) {
    return $false
  }
  foreach ($config_file_name in GetGitConfigFileNames) {
    if (-not (FormatGitConfigFile -ConfigFilePath (Join-Path $ENV:USERPROFILE $config_file_name))) {
      return $false
    }
  }
  LogSuccess "Git identities configured successfully"
  return $true
}

function RemoveGitConfig {
  RemoveApplicationConfig -AppName "Git" -DestinationPath "$ENV:USERPROFILE" -Files (GetGitConfigFileNames)
}
