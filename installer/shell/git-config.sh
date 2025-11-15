#!/usr/bin/env bash

readonly GIT_IDENTITY_PROVIDER_SLUGS=("github" "gitlab")
readonly GIT_IDENTITY_PROVIDER_NAMES=("GitHub" "GitLab")
readonly GIT_EMAIL_PATTERN='^[^@[:space:]]+@[^@[:space:]]+$'
readonly GIT_REQUIRED_PATTERN='[^[:space:]]'
readonly GIT_GLOB_PATTERN='[*?[]'
readonly GIT_INCLUDE_ENTRY_PATTERN='^includeif\.gitdir/i:(.+)\.path (.+)$'

ReadGitPromptValue() {
  local prompt="$1"
  local default_value="$2"
  local prompt_text="$prompt: "
  local answer=""
  if [[ -n "$default_value" ]]; then
    prompt_text="$prompt (default: $default_value): "
  fi
  read -r -p "$prompt_text" answer || return 1
  printf '%s\n' "${answer:-$default_value}"
}

ReadGitIdentityAnswer() {
  local output_variable_name="$1"
  local prompt="$2"
  local default_value="$3"
  local answer_pattern="$4"
  local invalid_message="$5"
  local prompt_answer=""
  while true; do
    prompt_answer="$(ReadGitPromptValue "$prompt" "$default_value")" || return 1
    if [[ "$prompt_answer" =~ $answer_pattern ]]; then
      printf -v "$output_variable_name" '%s' "$prompt_answer"
      return 0
    fi
    LogWarning "$invalid_message"
  done
}

ConvertToGitDirectoryPattern() {
  local directory_pattern="${1//\\//}"
  if [[ "$directory_pattern" != */ ]]; then
    directory_pattern="$directory_pattern/"
  fi
  printf '%s\n' "$directory_pattern"
}

NewGitIdentityDirectory() {
  local directory_pattern="$1"
  local directory_path="$directory_pattern"
  if [[ "$directory_path" == "~/"* ]]; then
    directory_path="$HOME/${directory_path#\~/}"
  fi
  if [[ "$directory_path" != /* || "$directory_path" =~ $GIT_GLOB_PATTERN ]]; then
    LogWarning "Skipping folder creation for pattern: $directory_pattern"
    return 0
  fi
  [[ -d "$directory_path" ]] && return 0
  if ! mkdir -p "$directory_path"; then
    LogError "Failed to create folder $directory_path"
    return 1
  fi
  LogSuccess "Created folder: $directory_path"
}

ReadGitConfigValue() {
  local config_file_path="$1"
  local config_key="$2"
  [[ -f "$config_file_path" ]] || return 0
  git config --file "$config_file_path" --get "$config_key" 2>/dev/null || true
}

ReadGitIncludeDirectory() {
  local global_config_path="$1"
  local identity_file_name="$2"
  local include_entry=""
  [[ -f "$global_config_path" ]] || return 0
  while IFS= read -r include_entry; do
    if [[ "$include_entry" =~ $GIT_INCLUDE_ENTRY_PATTERN && "${BASH_REMATCH[2]}" == "$identity_file_name" ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  done < <(git config --file "$global_config_path" --get-regexp '^includeif\.gitdir/i:.*\.path$' 2>/dev/null)
}

IsGitDirectoryUsed() {
  local identity_directory="$1"
  local used_directory=""
  for used_directory in "${identity_directories[@]}"; do
    if [[ "${used_directory,,}" == "${identity_directory,,}" ]]; then
      return 0
    fi
  done
  return 1
}

ReadGitIdentityAnswers() {
  local global_config_path="$HOME/.gitconfig"
  local index=""
  for index in "${!GIT_IDENTITY_PROVIDER_SLUGS[@]}"; do
    local provider_slug="${GIT_IDENTITY_PROVIDER_SLUGS[$index]}"
    local provider_name="${GIT_IDENTITY_PROVIDER_NAMES[$index]}"
    local identity_file_name=".gitconfig-$provider_slug"
    local identity_file_path="$HOME/$identity_file_name"
    local default_directory=""
    local directory_answer=""
    local identity_directory=""
    local identity_name=""
    local identity_email=""
    default_directory="$(ReadGitIncludeDirectory "$global_config_path" "$identity_file_name")"
    if [[ -z "$default_directory" ]]; then
      default_directory='~/'"$provider_slug/"
    fi
    while true; do
      ReadGitIdentityAnswer directory_answer "$provider_name folder" "$default_directory" "$GIT_REQUIRED_PATTERN" "Folder is required" || return 1
      identity_directory="$(ConvertToGitDirectoryPattern "$directory_answer")"
      IsGitDirectoryUsed "$identity_directory" || break
      LogWarning "Folder is already used by another provider: $identity_directory"
    done
    ReadGitIdentityAnswer identity_name "$provider_name name" "$(ReadGitConfigValue "$identity_file_path" user.name)" "$GIT_REQUIRED_PATTERN" "Name is required" || return 1
    ReadGitIdentityAnswer identity_email "$provider_name email" "$(ReadGitConfigValue "$identity_file_path" user.email)" "$GIT_EMAIL_PATTERN" "Email must look like name@example.com" || return 1
    identity_directories+=("$identity_directory")
    identity_names+=("$identity_name")
    identity_emails+=("$identity_email")
  done
}

SetGitConfigValue() {
  local config_file_path="$1"
  local config_key="$2"
  local config_value="$3"
  if ! git config --file "$config_file_path" "$config_key" "$config_value"; then
    LogError "Failed to write $config_key to $config_file_path"
    return 1
  fi
}

WriteGitIdentityConfig() {
  local global_config_path="$HOME/.gitconfig"
  local index=""
  for index in "${!GIT_IDENTITY_PROVIDER_SLUGS[@]}"; do
    local identity_file_name=".gitconfig-${GIT_IDENTITY_PROVIDER_SLUGS[$index]}"
    local identity_file_path="$HOME/$identity_file_name"
    SetGitConfigValue "$identity_file_path" "user.name" "${identity_names[$index]}" || return 1
    SetGitConfigValue "$identity_file_path" "user.email" "${identity_emails[$index]}" || return 1
    SetGitConfigValue "$global_config_path" "includeIf.gitdir/i:${identity_directories[$index]}.path" "$identity_file_name" || return 1
  done
}

ReadGitConfigFileNames() {
  local provider_slug=""
  printf '%s\n' ".gitconfig"
  for provider_slug in "${GIT_IDENTITY_PROVIDER_SLUGS[@]}"; do
    printf '%s\n' ".gitconfig-$provider_slug"
  done
}

FormatGitConfigFile() {
  local config_file_path="$1"
  local formatted_file_path="$config_file_path.formatted"
  if ! awk '
    { sub(/\r$/, "") }
    /^\[/ && NR > 1 && previous_line != "" { print "" }
    { sub(/^\t/, "  "); print; previous_line = $0 }
  ' "$config_file_path" > "$formatted_file_path" || ! mv "$formatted_file_path" "$config_file_path"; then
    rm -f "$formatted_file_path"
    LogError "Failed to format $config_file_path"
    return 1
  fi
}

SetGitConfig() {
  local identity_directories=()
  local identity_names=()
  local identity_emails=()
  if ! command -v git &>/dev/null; then
    LogError "Git is not installed"
    return 1
  fi
  if ! ReadGitIdentityAnswers; then
    LogError "Git identity setup was cancelled"
    return 1
  fi
  local identity_directory_pattern=""
  for identity_directory_pattern in "${identity_directories[@]}"; do
    NewGitIdentityDirectory "$identity_directory_pattern" || return 1
  done
  SetApplicationConfig -app_name "Git" -source_path "$SCRIPT_DIR/.gitconfig" -destination_path "$HOME" -files ".gitconfig" || return 1
  WriteGitIdentityConfig || return 1
  local config_file_name=""
  while IFS= read -r config_file_name; do
    FormatGitConfigFile "$HOME/$config_file_name" || return 1
  done < <(ReadGitConfigFileNames)
  LogSuccess "Git identities configured successfully"
}

RemoveGitConfig() {
  local git_config_files=()
  local config_file_name=""
  while IFS= read -r config_file_name; do
    git_config_files+=("$config_file_name")
  done < <(ReadGitConfigFileNames)
  RemoveApplicationConfig -app_name "Git" -destination_path "$HOME" -files "${git_config_files[@]}"
}
