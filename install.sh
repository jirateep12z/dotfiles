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
  echo "  2. Install Windsurf extensions"
  echo "  3. Install all packages"
  echo ""
  echo "UNINSTALL:"
  echo "  4. Uninstall Homebrew packages"
  echo "  5. Uninstall Windsurf extensions"
  echo "  6. Uninstall all packages"
  echo ""
  echo "CONFIGURE:"
  echo "  7. Set Fish as default shell"
  echo "  8. Configure Fish"
  echo "  9. Configure Tmux"
  echo " 10. Configure Vim"
  echo " 11. Configure Script"
  echo " 12. Configure Git"
  echo " 13. Configure Lazygit"
  echo " 14. Configure Commitizen"
  echo " 15. Configure Python (pip)"
  echo " 16. Configure Windsurf"
  echo " 17. Configure all applications"
  echo ""
  echo "REMOVE:"
  echo " 18. Remove Fish configuration"
  echo " 19. Remove Tmux configuration"
  echo " 20. Remove Vim configuration"
  echo " 21. Remove Script configuration"
  echo " 22. Remove Git configuration"
  echo " 23. Remove Lazygit configuration"
  echo " 24. Remove Commitizen configuration"
  echo " 25. Remove Python configuration"
  echo " 26. Remove Windsurf configuration"
  echo " 27. Remove all configurations"
  echo ""
  echo "  q. Quit"
  echo ""
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
  for package in "${packages[@]}"; do
    ((current++))
    LogInfo "[$current/$total] Installing: $package"
    if [[ -n "$additional_params" ]]; then
      eval "$install_command $package $additional_params"
    else
      eval "$install_command $package"
    fi
  done
  LogSuccess "Completed installing $package_name"
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
  for package in "${packages[@]}"; do
    ((current++))
    LogInfo "[$current/$total] Uninstalling: $package"
    eval "$uninstall_command $package"
  done
  LogSuccess "Completed uninstalling $package_name"
}

InstallHomebrewPackages() {
  if ! command -v brew &>/dev/null; then
    LogWarning "Homebrew is not installed. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  InstallPackage -package_name "Homebrew packages" -package_list_path "$SCRIPT_DIR/requirement/brew_package.txt" -install_command "brew install"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    InstallPackage -package_name "Homebrew applications" -package_list_path "$SCRIPT_DIR/requirement/brew_application.txt" -install_command "brew install --cask"
  else
    LogInfo "Skipping cask applications (macOS only)"
  fi
  InstallPackage -package_name "Homebrew fonts" -package_list_path "$SCRIPT_DIR/requirement/brew_font.txt" -install_command "brew install"
}

UninstallHomebrewPackages() {
  UninstallPackage -package_name "Homebrew fonts" -package_list_path "$SCRIPT_DIR/requirement/brew_font.txt" -uninstall_command "brew uninstall"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    UninstallPackage -package_name "Homebrew applications" -package_list_path "$SCRIPT_DIR/requirement/brew_application.txt" -uninstall_command "brew uninstall --cask"
  else
    LogInfo "Skipping cask applications (macOS only)"
  fi
  UninstallPackage -package_name "Homebrew packages" -package_list_path "$SCRIPT_DIR/requirement/brew_package.txt" -uninstall_command "brew uninstall"
}

InstallWindsurfExtensions() {
  if ! command -v windsurf &>/dev/null; then
    LogWarning "Windsurf is not installed. Installing via Homebrew..."
    InstallHomebrewPackages
  fi
  InstallPackage -package_name "Windsurf extensions" -package_list_path "$SCRIPT_DIR/requirement/windsurf.txt" -install_command "windsurf --install-extension" -additional_params "--force"
}

UninstallWindsurfExtensions() {
  if ! command -v windsurf &>/dev/null; then
    LogWarning "Windsurf is not installed"
    return 1
  fi
  UninstallPackage -package_name "Windsurf extensions" -package_list_path "$SCRIPT_DIR/requirement/windsurf.txt" -uninstall_command "windsurf --uninstall-extension"
}

InstallAllPackages() {
  InstallHomebrewPackages
  InstallWindsurfExtensions
  LogSuccess "All packages installed successfully"
}

UninstallAllPackages() {
  UninstallWindsurfExtensions
  UninstallHomebrewPackages
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
          find "$destination_path" -name "*.$extension" -type f -delete 2>/dev/null
        done
      fi
      if [[ ${#files[@]} -gt 0 ]]; then
        for file in "${files[@]}"; do
          find "$destination_path" -name "$file" -delete 2>/dev/null
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
          find "$destination_path" -name "*.$extension" -type f -delete 2>/dev/null
        done
      fi
      if [[ ${#files[@]} -gt 0 ]]; then
        for file in "${files[@]}"; do
          find "$destination_path" -name "$file" -delete 2>/dev/null
        done
      fi
      LogSuccess "Removed $app_name configuration files"
    fi
  else
    LogWarning "Configuration path not found: $destination_path"
  fi
}

SetFishConfig() {
  SetApplicationConfig -app_name "Fish" -source_path "$SCRIPT_DIR/config/fish" -destination_path "$HOME/.config/fish"
}

RemoveFishConfig() {
  RemoveApplicationConfig -app_name "Fish" -destination_path "$HOME/.config/fish"
}

SetTmuxConfig() {
  SetApplicationConfig -app_name "Tmux" -source_path "$SCRIPT_DIR/config/tmux" -destination_path "$HOME/.config/tmux"
}

RemoveTmuxConfig() {
  RemoveApplicationConfig -app_name "Tmux" -destination_path "$HOME/.config/tmux"
}

SetVimConfig() {
  SetApplicationConfig -app_name "Vim" -source_path "$SCRIPT_DIR/config/vim/.vimrc" -destination_path "$HOME" -files ".vimrc"
}

RemoveVimConfig() {
  RemoveApplicationConfig -app_name "Vim" -destination_path "$HOME" -files ".vimrc"
}

SetScriptConfig() {
  SetApplicationConfig -app_name "Script" -source_path "$SCRIPT_DIR/script" -destination_path "$HOME/.local/bin"
}

RemoveScriptConfig() {
  RemoveApplicationConfig -app_name "Script" -destination_path "$HOME/.local/bin"
}

SetGitConfig() {
  SetApplicationConfig -app_name "Git" -source_path "$SCRIPT_DIR/.gitconfig" -destination_path "$HOME" -files ".gitconfig"
}

RemoveGitConfig() {
  RemoveApplicationConfig -app_name "Git" -destination_path "$HOME" -files ".gitconfig"
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

SetPythonConfig() {
  SetApplicationConfig -app_name "Python (pip)" -source_path "$SCRIPT_DIR/config/pip" -destination_path "$HOME/.config/pip"
}

RemovePythonConfig() {
  RemoveApplicationConfig -app_name "Python (pip)" -destination_path "$HOME/.config/pip"
}

SetWindsurfConfig() {
  local windsurf_config_path
  if [[ "$OSTYPE" == "darwin"* ]]; then
    windsurf_config_path="$HOME/Library/Application Support/Windsurf/User"
  elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    windsurf_config_path="$HOME/.config/Windsurf/User"
  else
    LogError "Unsupported OS for Windsurf configuration"
    return 1
  fi
  SetApplicationConfig -app_name "Windsurf" -source_path "$SCRIPT_DIR/config/windsurf" -destination_path "$windsurf_config_path" -extensions "json"
}

RemoveWindsurfConfig() {
  local windsurf_config_path
  if [[ "$OSTYPE" == "darwin"* ]]; then
    windsurf_config_path="$HOME/Library/Application Support/Windsurf/User"
  elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    windsurf_config_path="$HOME/.config/Windsurf/User"
  else
    LogError "Unsupported OS for Windsurf configuration"
    return 1
  fi
  RemoveApplicationConfig -app_name "Windsurf" -destination_path "$windsurf_config_path" -extensions "json"
}

SetAllApplicationConfigs() {
  SetFishConfig
  SetTmuxConfig
  SetVimConfig
  SetScriptConfig
  SetGitConfig
  SetLazygitConfig
  SetCommitizenConfig
  SetPythonConfig
  SetWindsurfConfig
  LogSuccess "All applications configured successfully"
}

RemoveAllApplicationConfigs() {
  RemoveWindsurfConfig
  RemovePythonConfig
  RemoveCommitizenConfig
  RemoveLazygitConfig
  RemoveGitConfig
  RemoveScriptConfig
  RemoveVimConfig
  RemoveTmuxConfig
  RemoveFishConfig
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
      2) InstallWindsurfExtensions ;;
      3) InstallAllPackages ;;
      4) UninstallHomebrewPackages ;;
      5) UninstallWindsurfExtensions ;;
      6) UninstallAllPackages ;;
      7) SetFishToDefaultShell ;;
      8) SetFishConfig ;;
      9) SetTmuxConfig ;;
      10) SetVimConfig ;;
      11) SetScriptConfig ;;
      12) SetGitConfig ;;
      13) SetLazygitConfig ;;
      14) SetCommitizenConfig ;;
      15) SetPythonConfig ;;
      16) SetWindsurfConfig ;;
      17) SetAllApplicationConfigs ;;
      18) RemoveFishConfig ;;
      19) RemoveTmuxConfig ;;
      20) RemoveVimConfig ;;
      21) RemoveScriptConfig ;;
      22) RemoveGitConfig ;;
      23) RemoveLazygitConfig ;;
      24) RemoveCommitizenConfig ;;
      25) RemovePythonConfig ;;
      26) RemoveWindsurfConfig ;;
      27) RemoveAllApplicationConfigs ;;
      q) break ;;
      *) LogWarning "Invalid choice. Please try again." ;;
    esac
  done
}

Main
