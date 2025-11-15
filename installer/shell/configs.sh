#!/usr/bin/env bash

SetFishToDefaultShell() {
  LogInfo "Setting Fish as default shell"
  local fish_path
  fish_path="$(command -v fish)"
  if [[ -z "$fish_path" ]]; then
    LogError "Fish is not installed"
    return 1
  fi
  if ! grep -q "$fish_path" /etc/shells; then
    LogInfo "Adding Fish to /etc/shells"
    echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
  else
    LogInfo "Fish is already in /etc/shells"
  fi
  LogInfo "Changing default shell to Fish"
  chsh -s "$fish_path"
  LogInfo "Adding Homebrew to Fish path"
  fish -c 'fish_add_path (dirname (command -v brew))'
  LogSuccess "Fish set as default shell successfully"
}

SetScriptConfig() {
  local source_path="$SCRIPT_DIR/script"
  local source_utils_path="$SCRIPT_DIR/utils/shell"
  local destination_path="$HOME/.local/bin"
  local destination_utils_path="$destination_path/utils"
  if [[ ! -d "$source_path" ]]; then
    LogWarning "Source path not found: $source_path"
    return 1
  fi
  if [[ ! -d "$source_utils_path" ]]; then
    LogWarning "Shell utilities path not found: $source_utils_path"
    return 1
  fi
  LogInfo "Configuring Script"
  mkdir -p "$destination_path" "$destination_utils_path" || return 1
  find "$source_path" -maxdepth 1 -type f -name "*.sh" -exec cp {} "$destination_path" \;
  find "$source_utils_path" -maxdepth 1 -type f -exec cp {} "$destination_utils_path" \;
  find "$destination_path" -maxdepth 1 -name "*.sh" -type f -exec chmod +x {} +
  LogSuccess "Script configured successfully"
}

RemoveScriptConfig() {
  local source_path="$SCRIPT_DIR/script"
  local source_utils_path="$SCRIPT_DIR/utils/shell"
  local destination_path="$HOME/.local/bin"
  local destination_utils_path="$destination_path/utils"
  LogInfo "Removing Script configuration"
  if [[ ! -d "$destination_path" && ! -d "$destination_utils_path" ]]; then
    LogWarning "Configuration path not found: $destination_path"
    return 1
  fi
  if [[ -d "$source_path" ]]; then
    while IFS= read -r source_file; do
      rm -f "$destination_path/$(basename "$source_file")"
    done < <(find "$source_path" -maxdepth 1 -type f -name "*.sh")
  fi
  if [[ -d "$source_utils_path" && -d "$destination_utils_path" ]]; then
    while IFS= read -r source_file; do
      rm -f "$destination_utils_path/$(basename "$source_file")"
    done < <(find "$source_utils_path" -maxdepth 1 -type f)
    rmdir "$destination_utils_path" 2>/dev/null || true
  fi
  LogSuccess "Removed Script configuration files"
}

SetPythonConfig() {
  SetApplicationConfig -app_name "Python (pip)" -source_path "$SCRIPT_DIR/config/pip" -destination_path "$HOME/.config/pip"
}

RemovePythonConfig() {
  RemoveApplicationConfig -app_name "Python (pip)" -destination_path "$HOME/.config/pip"
}

GetWarpThemesPath() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "$HOME/.warp/themes"
  elif [[ "$OSTYPE" == linux* ]]; then
    echo "${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/themes"
  else
    LogError "Unsupported OS for Warp configuration"
    return 1
  fi
}

SetWarpConfig() {
  local warp_themes_path
  warp_themes_path="$(GetWarpThemesPath)" || return 1
  SetApplicationConfig -app_name "Warp" -source_path "$SCRIPT_DIR/config/warp" -destination_path "$warp_themes_path" -extensions "yaml"
}

RemoveWarpConfig() {
  local warp_themes_path
  warp_themes_path="$(GetWarpThemesPath)" || return 1
  RemoveApplicationConfig -app_name "Warp" -destination_path "$warp_themes_path" -extensions "yaml"
}

SetVimConfig() {
  SetApplicationConfig -app_name "Vim" -source_path "$SCRIPT_DIR/config/vim/.vimrc" -destination_path "$HOME" -files ".vimrc"
}

RemoveVimConfig() {
  RemoveApplicationConfig -app_name "Vim" -destination_path "$HOME" -files ".vimrc"
}

SetNeovimConfig() {
  SetApplicationConfig -app_name "Neovim" -source_path "$SCRIPT_DIR/config/nvim" -destination_path "$HOME/.config/nvim"
}

RemoveNeovimConfig() {
  RemoveApplicationConfig -app_name "Neovim" -destination_path "$HOME/.config/nvim"
}

SetLazygitConfig() {
  SetApplicationConfig -app_name "Lazygit" -source_path "$SCRIPT_DIR/config/lazygit" -destination_path "$HOME/.config/lazygit"
}

RemoveLazygitConfig() {
  RemoveApplicationConfig -app_name "Lazygit" -destination_path "$HOME/.config/lazygit"
}

SetCommitizenConfig() {
  SetApplicationConfig -app_name "Commitizen" -source_path "$SCRIPT_DIR/config/commitizen/.czrc" -destination_path "$HOME" -files ".czrc"
}

RemoveCommitizenConfig() {
  RemoveApplicationConfig -app_name "Commitizen" -destination_path "$HOME" -files ".czrc"
}

SetVSCodeConfig() {
  local vscode_config_path
  if [[ "$OSTYPE" == "darwin"* ]]; then
    vscode_config_path="$HOME/Library/Application Support/Code/User"
  elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    vscode_config_path="$HOME/.config/Code/User"
  else
    LogError "Unsupported OS for VSCode configuration"
    return 1
  fi
  SetApplicationConfig -app_name "VSCode" -source_path "$SCRIPT_DIR/config/visual-studio-code" -destination_path "$vscode_config_path" -extensions "json"
}

RemoveVSCodeConfig() {
  local vscode_config_path
  if [[ "$OSTYPE" == "darwin"* ]]; then
    vscode_config_path="$HOME/Library/Application Support/Code/User"
  elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    vscode_config_path="$HOME/.config/Code/User"
  else
    LogError "Unsupported OS for VSCode configuration"
    return 1
  fi
  RemoveApplicationConfig -app_name "VSCode" -destination_path "$vscode_config_path" -extensions "json"
}

SetAllApplicationConfigs() {
  local failed_steps=()
  SetScriptConfig || failed_steps+=("Script")
  SetPythonConfig || failed_steps+=("Python")
  SetWarpConfig || failed_steps+=("Warp")
  SetVimConfig || failed_steps+=("Vim")
  SetNeovimConfig || failed_steps+=("Neovim")
  SetGitConfig || failed_steps+=("Git")
  SetLazygitConfig || failed_steps+=("Lazygit")
  SetCommitizenConfig || failed_steps+=("Commitizen")
  SetVSCodeConfig || failed_steps+=("VSCode")
  if [[ ${#failed_steps[@]} -gt 0 ]]; then
    LogError "Application configuration failed: ${failed_steps[*]}"
    return 1
  fi
  LogSuccess "All applications configured successfully"
}

RemoveAllApplicationConfigs() {
  local failed_steps=()
  RemoveScriptConfig || failed_steps+=("Script")
  RemovePythonConfig || failed_steps+=("Python")
  RemoveWarpConfig || failed_steps+=("Warp")
  RemoveVimConfig || failed_steps+=("Vim")
  RemoveNeovimConfig || failed_steps+=("Neovim")
  RemoveGitConfig || failed_steps+=("Git")
  RemoveLazygitConfig || failed_steps+=("Lazygit")
  RemoveCommitizenConfig || failed_steps+=("Commitizen")
  RemoveVSCodeConfig || failed_steps+=("VSCode")
  if [[ ${#failed_steps[@]} -gt 0 ]]; then
    LogError "Application configuration removal failed: ${failed_steps[*]}"
    return 1
  fi
  LogSuccess "All configurations removed successfully"
}
