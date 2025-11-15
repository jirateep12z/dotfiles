#!/usr/bin/env bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

source "$SCRIPT_DIR/utils/shell/file.sh" 2>/dev/null || {
  echo "Error: Cannot load file.sh utility" >&2
  exit 1
}
source "$SCRIPT_DIR/utils/shell/progress.sh" 2>/dev/null || {
  echo "Error: Cannot load progress.sh utility" >&2
  exit 1
}
source "$SCRIPT_DIR/utils/shell/logger.sh" 2>/dev/null || {
  echo "Error: Cannot load logger.sh utility" >&2
  exit 1
}

CheckInstallCompatibility() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    LogInfo "macOS system detected: $OSTYPE"
    return 0
  elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    LogInfo "Linux system detected: $OSTYPE"
    return 0
  else
    LogError "This install script only supports macOS and Linux"
    LogError "Detected OS: $OSTYPE"
    return 1
  fi
}

ShowMenu() {
  if [[ -f "$SCRIPT_DIR/ascii.txt" ]]; then
    echo ""
    cat "$SCRIPT_DIR/ascii.txt"
    echo ""
  fi
  echo "INSTALL:"
  echo "  1. Install Homebrew packages"
  echo "  2. Install VSCode extensions"
  echo "  3. Install Skills"
  echo "  4. Install all packages"
  echo ""
  echo "UNINSTALL:"
  echo "  5. Uninstall Homebrew packages"
  echo "  6. Uninstall VSCode extensions"
  echo "  7. Uninstall Skills"
  echo "  8. Uninstall all packages"
  echo ""
  echo "CONFIGURE:"
  echo "  9. Set Fish as default shell"
  echo " 10. Configure Script"
  echo " 11. Configure Python (pip)"
  echo " 12. Configure Warp"
  echo " 13. Configure Vim"
  echo " 14. Configure Neovim"
  echo " 15. Configure Git"
  echo " 16. Configure Lazygit"
  echo " 17. Configure Commitizen"
  echo " 18. Configure VSCode"
  echo " 19. Configure all applications"
  echo ""
  echo "REMOVE:"
  echo " 20. Remove Script configuration"
  echo " 21. Remove Python configuration"
  echo " 22. Remove Warp configuration"
  echo " 23. Remove Vim configuration"
  echo " 24. Remove Neovim configuration"
  echo " 25. Remove Git configuration"
  echo " 26. Remove Lazygit configuration"
  echo " 27. Remove Commitizen configuration"
  echo " 28. Remove VSCode configuration"
  echo " 29. Remove all configurations"
  echo ""
  echo "  q. Quit"
  echo ""
}

RunPackageCommand() {
  local command_text="$1"
  local package="$2"
  local additional_params="${3:-}"
  local command_parts=()
  local package_parts=()
  local additional_parts=()
  read -r -a command_parts <<< "$command_text"
  if [[ ${#command_parts[@]} -eq 0 ]]; then
    LogError "Install command is empty"
    return 1
  fi
  read -r -a package_parts <<< "$package"
  if [[ -n "$additional_params" ]]; then
    read -r -a additional_parts <<< "$additional_params"
  fi
  "${command_parts[@]}" "${package_parts[@]}" "${additional_parts[@]}"
}

InstallPackage() {
  local package_name=""
  local package_list_path=""
  local install_command=""
  local additional_params=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      -package_name)
        package_name="$2"
        shift 2
        ;;
      -package_list_path)
        package_list_path="$2"
        shift 2
        ;;
      -install_command)
        install_command="$2"
        shift 2
        ;;
      -additional_params)
        additional_params="$2"
        shift 2
        ;;
      *)
        LogError "Unknown parameter: $1"
        return 1
        ;;
    esac
  done
  if [[ ! -f "$package_list_path" ]]; then
    LogWarning "Package list not found: $package_list_path"
    return 1
  fi
  if [[ -n "$package_name" ]]; then
    LogInfo "Installing $package_name"
  fi
  local packages=()
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    packages+=("$line")
  done < "$package_list_path"
  local total=${#packages[@]}
  local current=0
  local failed_packages=()
  for package in "${packages[@]}"; do
    ((current++))
    LogInfo "[$current/$total] Installing: $package"
    if ! RunPackageCommand "$install_command" "$package" "$additional_params"; then
      failed_packages+=("$package")
      LogError "Failed to install: $package"
    fi
  done
  if [[ ${#failed_packages[@]} -gt 0 ]]; then
    LogError "Failed to install $package_name: ${failed_packages[*]}"
    return 1
  fi
  LogSuccess "Completed installing $package_name"
}

GetSkillNameFromEntry() {
  local skill_entry="$1"
  local entry_parts=()
  read -r -a entry_parts <<< "$skill_entry"
  for ((index = 0; index < ${#entry_parts[@]}; index++)); do
    if [[ "${entry_parts[$index]}" == "--skill" || "${entry_parts[$index]}" == "-s" ]]; then
      echo "${entry_parts[$((index + 1))]:-}"
      return 0
    fi
  done
  return 1
}

UninstallPackage() {
  local package_name=""
  local package_list_path=""
  local uninstall_command=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      -package_name)
        package_name="$2"
        shift 2
        ;;
      -package_list_path)
        package_list_path="$2"
        shift 2
        ;;
      -uninstall_command)
        uninstall_command="$2"
        shift 2
        ;;
      *)
        LogError "Unknown parameter: $1"
        return 1
        ;;
    esac
  done
  if [[ ! -f "$package_list_path" ]]; then
    LogWarning "Package list not found: $package_list_path"
    return 1
  fi
  if [[ -n "$package_name" ]]; then
    LogInfo "Uninstalling $package_name"
  fi
  local packages=()
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    packages+=("$line")
  done < "$package_list_path"
  local total=${#packages[@]}
  local current=0
  local failed_packages=()
  for package in "${packages[@]}"; do
    ((current++))
    LogInfo "[$current/$total] Uninstalling: $package"
    if ! RunPackageCommand "$uninstall_command" "$package"; then
      failed_packages+=("$package")
      LogError "Failed to uninstall: $package"
    fi
  done
  if [[ ${#failed_packages[@]} -gt 0 ]]; then
    LogError "Failed to uninstall $package_name: ${failed_packages[*]}"
    return 1
  fi
  LogSuccess "Completed uninstalling $package_name"
}

InstallHomebrewPackages() {
  if ! command -v brew &>/dev/null; then
    LogWarning "Homebrew is not installed. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  local failed_steps=()
  InstallPackage -package_name "Homebrew taps" -package_list_path "$SCRIPT_DIR/requirement/brew-tap.txt" -install_command "brew tap" || failed_steps+=("Homebrew taps")
  InstallPackage -package_name "Homebrew packages" -package_list_path "$SCRIPT_DIR/requirement/brew-package.txt" -install_command "brew install" || failed_steps+=("Homebrew packages")
  if [[ "$OSTYPE" == "darwin"* ]]; then
    InstallPackage -package_name "Homebrew applications" -package_list_path "$SCRIPT_DIR/requirement/brew-application.txt" -install_command "brew install --cask" || failed_steps+=("Homebrew applications")
  else
    LogInfo "Skipping cask applications (macOS only)"
  fi
  InstallPackage -package_name "Homebrew fonts" -package_list_path "$SCRIPT_DIR/requirement/brew-font.txt" -install_command "brew install" || failed_steps+=("Homebrew fonts")
  if [[ ${#failed_steps[@]} -gt 0 ]]; then
    LogError "Homebrew package installation failed: ${failed_steps[*]}"
    return 1
  fi
}

UninstallHomebrewPackages() {
  local failed_steps=()
  UninstallPackage -package_name "Homebrew fonts" -package_list_path "$SCRIPT_DIR/requirement/brew-font.txt" -uninstall_command "brew uninstall" || failed_steps+=("Homebrew fonts")
  if [[ "$OSTYPE" == "darwin"* ]]; then
    UninstallPackage -package_name "Homebrew applications" -package_list_path "$SCRIPT_DIR/requirement/brew-application.txt" -uninstall_command "brew uninstall --cask" || failed_steps+=("Homebrew applications")
  else
    LogInfo "Skipping cask applications (macOS only)"
  fi
  UninstallPackage -package_name "Homebrew packages" -package_list_path "$SCRIPT_DIR/requirement/brew-package.txt" -uninstall_command "brew uninstall" || failed_steps+=("Homebrew packages")
  if [[ ${#failed_steps[@]} -gt 0 ]]; then
    LogError "Homebrew package uninstallation failed: ${failed_steps[*]}"
    return 1
  fi
}

InstallVSCodeExtensions() {
  if ! command -v code &>/dev/null; then
    LogWarning "VSCode is not installed. Installing via Homebrew..."
    InstallHomebrewPackages || return 1
  fi
  if ! command -v code &>/dev/null; then
    LogError "VSCode command is still unavailable after package installation"
    return 1
  fi
  InstallPackage -package_name "VSCode extensions" -package_list_path "$SCRIPT_DIR/requirement/code.txt" -install_command "code --install-extension" -additional_params "--force"
}

UninstallVSCodeExtensions() {
  if ! command -v code &>/dev/null; then
    LogWarning "VSCode is not installed"
    return 1
  fi
  UninstallPackage -package_name "VSCode extensions" -package_list_path "$SCRIPT_DIR/requirement/code.txt" -uninstall_command "code --uninstall-extension"
}

InstallSkills() {
  if ! command -v npx &>/dev/null; then
    LogWarning "Node.js is not installed. Cannot run npx."
    return 1
  fi
  InstallPackage -package_name "Skills" -package_list_path "$SCRIPT_DIR/requirement/skills.txt" -install_command "npx skills add"
}

UninstallSkills() {
  if ! command -v npx &>/dev/null; then
    LogWarning "Node.js is not installed. Cannot run npx."
    return 1
  fi
  if [[ ! -f "$SCRIPT_DIR/requirement/skills.txt" ]]; then
    LogWarning "Skill list not found: $SCRIPT_DIR/requirement/skills.txt"
    return 1
  fi
  local failed_skills=()
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    local skill_name
    skill_name=$(GetSkillNameFromEntry "$line")
    if [[ -z "$skill_name" ]]; then
      LogError "Cannot determine skill name from: $line"
      failed_skills+=("$line")
      continue
    fi
    LogInfo "Uninstalling skill: $skill_name"
    if ! npx skills remove "$skill_name"; then
      failed_skills+=("$skill_name")
      LogError "Failed to uninstall skill: $skill_name"
    fi
  done < "$SCRIPT_DIR/requirement/skills.txt"
  if [[ ${#failed_skills[@]} -gt 0 ]]; then
    LogError "Failed to uninstall Skills: ${failed_skills[*]}"
    return 1
  fi
  LogSuccess "Completed uninstalling Skills"
}

InstallAllPackages() {
  local failed_steps=()
  InstallHomebrewPackages || failed_steps+=("Homebrew packages")
  InstallVSCodeExtensions || failed_steps+=("VSCode extensions")
  InstallSkills || failed_steps+=("Skills")
  if [[ ${#failed_steps[@]} -gt 0 ]]; then
    LogError "Package installation failed: ${failed_steps[*]}"
    return 1
  fi
  LogSuccess "All packages installed successfully"
}

UninstallAllPackages() {
  local failed_steps=()
  UninstallHomebrewPackages || failed_steps+=("Homebrew packages")
  UninstallVSCodeExtensions || failed_steps+=("VSCode extensions")
  UninstallSkills || failed_steps+=("Skills")
  if [[ ${#failed_steps[@]} -gt 0 ]]; then
    LogError "Package uninstallation failed: ${failed_steps[*]}"
    return 1
  fi
  LogSuccess "All packages uninstalled successfully"
}

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

SetApplicationConfig() {
  local app_name=""
  local source_path=""
  local destination_path=""
  local extensions=()
  local files=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      -app_name)
        app_name="$2"
        shift 2
        ;;
      -source_path)
        source_path="$2"
        shift 2
        ;;
      -destination_path)
        destination_path="$2"
        shift 2
        ;;
      -extensions)
        shift
        while [[ $# -gt 0 && ! $1 == -* ]]; do
          extensions+=("$1")
          shift
        done
        ;;
      -files)
        shift
        while [[ $# -gt 0 && ! $1 == -* ]]; do
          files+=("$1")
          shift
        done
        ;;
      *)
        LogError "Unknown parameter: $1"
        return 1
        ;;
    esac
  done
  if [[ -n "$app_name" ]]; then
    LogInfo "Configuring $app_name"
  fi
  if [[ ! -e "$source_path" ]]; then
    LogWarning "Source path not found: $source_path"
    return 1
  fi
  if [[ -d "$destination_path" ]]; then
    if [[ ${#extensions[@]} -eq 0 && ${#files[@]} -eq 0 ]]; then
      LogInfo "Cleaning destination: $destination_path"
      rm -rf "$destination_path"
      mkdir -p "$destination_path"
    else
      if [[ ${#extensions[@]} -gt 0 ]]; then
        for extension in "${extensions[@]}"; do
          find "$destination_path" -maxdepth 1 -name "*.$extension" -type f -delete 2>/dev/null
        done
      fi
      if [[ ${#files[@]} -gt 0 ]]; then
        for file in "${files[@]}"; do
          find "$destination_path" -maxdepth 1 -name "$file" -delete 2>/dev/null
        done
      fi
    fi
  else
    LogInfo "Creating destination: $destination_path"
    mkdir -p "$destination_path"
  fi
  if [[ -d "$source_path" ]]; then
    cp -r "$source_path"/. "$destination_path"
  else
    cp -r "$source_path" "$destination_path"
  fi
  LogSuccess "$app_name configured successfully"
}

RemoveApplicationConfig() {
  local app_name=""
  local destination_path=""
  local extensions=()
  local files=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      -app_name)
        app_name="$2"
        shift 2
        ;;
      -destination_path)
        destination_path="$2"
        shift 2
        ;;
      -extensions)
        shift
        while [[ $# -gt 0 && ! $1 == -* ]]; do
          extensions+=("$1")
          shift
        done
        ;;
      -files)
        shift
        while [[ $# -gt 0 && ! $1 == -* ]]; do
          files+=("$1")
          shift
        done
        ;;
      *)
        LogError "Unknown parameter: $1"
        return 1
        ;;
    esac
  done
  if [[ -n "$app_name" ]]; then
    LogInfo "Removing $app_name configuration"
  fi
  if [[ -d "$destination_path" ]]; then
    if [[ ${#extensions[@]} -eq 0 && ${#files[@]} -eq 0 ]]; then
      rm -rf "$destination_path"
      LogSuccess "Removed $app_name configuration"
    else
      if [[ ${#extensions[@]} -gt 0 ]]; then
        for extension in "${extensions[@]}"; do
          find "$destination_path" -maxdepth 1 -name "*.$extension" -type f -delete 2>/dev/null
        done
      fi
      if [[ ${#files[@]} -gt 0 ]]; then
        for file in "${files[@]}"; do
          find "$destination_path" -maxdepth 1 -name "$file" -delete 2>/dev/null
        done
      fi
      LogSuccess "Removed $app_name configuration files"
    fi
  else
    LogWarning "Configuration path not found: $destination_path"
  fi
}

SetScriptConfig() {
  local source_path="$SCRIPT_DIR/script"
  local destination_path="$HOME/.local/bin"
  local destination_utils_path="$destination_path/utils"
  if [[ ! -d "$source_path" ]]; then
    LogWarning "Source path not found: $source_path"
    return 1
  fi
  LogInfo "Configuring Script"
  mkdir -p "$destination_path" "$destination_utils_path" || return 1
  find "$source_path" -maxdepth 1 -type f -name "*.sh" -exec cp {} "$destination_path" \;
  if [[ -d "$source_path/utils" ]]; then
    find "$source_path/utils" -maxdepth 1 -type f -exec cp {} "$destination_utils_path" \;
  fi
  find "$destination_path" -maxdepth 1 -name "*.sh" -type f -exec chmod +x {} +
  LogSuccess "Script configured successfully"
}

RemoveScriptConfig() {
  local source_path="$SCRIPT_DIR/script"
  local destination_path="$HOME/.local/bin"
  local destination_utils_path="$destination_path/utils"
  LogInfo "Removing Script configuration"
  if [[ ! -d "$destination_path" ]]; then
    LogWarning "Configuration path not found: $destination_path"
    return 1
  fi
  if [[ -d "$source_path" ]]; then
    while IFS= read -r source_file; do
      rm -f "$destination_path/$(basename "$source_file")"
    done < <(find "$source_path" -maxdepth 1 -type f -name "*.sh")
  fi
  if [[ -d "$source_path/utils" && -d "$destination_utils_path" ]]; then
    while IFS= read -r source_file; do
      rm -f "$destination_utils_path/$(basename "$source_file")"
    done < <(find "$source_path/utils" -maxdepth 1 -type f)
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

SetWarpConfig() {
  SetApplicationConfig -app_name "Warp" -source_path "$SCRIPT_DIR/config/warp" -destination_path "$HOME/.warp/themes" -extensions "yaml"
}

RemoveWarpConfig() {
  RemoveApplicationConfig -app_name "Warp" -destination_path "$HOME/.warp/themes" -extensions "yaml"
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

SetGitConfig() {
  SetApplicationConfig -app_name "Git" -source_path "$SCRIPT_DIR/.gitconfig" -destination_path "$HOME" -files ".gitconfig"
}

RemoveGitConfig() {
  RemoveApplicationConfig -app_name "Git" -destination_path "$HOME" -files ".gitconfig"
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

Main() {
  if ! CheckInstallCompatibility; then
    exit 1
  fi
  while true; do
    ShowMenu
    read -r -p "Enter your choice: " choice
    case $choice in
      1) InstallHomebrewPackages ;;
      2) InstallVSCodeExtensions ;;
      3) InstallSkills ;;
      4) InstallAllPackages ;;
      5) UninstallHomebrewPackages ;;
      6) UninstallVSCodeExtensions ;;
      7) UninstallSkills ;;
      8) UninstallAllPackages ;;
      9) SetFishToDefaultShell ;;
      10) SetScriptConfig ;;
      11) SetPythonConfig ;;
      12) SetWarpConfig ;;
      13) SetVimConfig ;;
      14) SetNeovimConfig ;;
      15) SetGitConfig ;;
      16) SetLazygitConfig ;;
      17) SetCommitizenConfig ;;
      18) SetVSCodeConfig ;;
      19) SetAllApplicationConfigs ;;
      20) RemoveScriptConfig ;;
      21) RemovePythonConfig ;;
      22) RemoveWarpConfig ;;
      23) RemoveVimConfig ;;
      24) RemoveNeovimConfig ;;
      25) RemoveGitConfig ;;
      26) RemoveLazygitConfig ;;
      27) RemoveCommitizenConfig ;;
      28) RemoveVSCodeConfig ;;
      29) RemoveAllApplicationConfigs ;;
      q) break ;;
      *) LogWarning "Invalid choice. Please try again." ;;
    esac
  done
}

Main
