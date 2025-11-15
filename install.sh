#!/usr/bin/env bash

if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Error: This script requires bash 4+ (detected: ${BASH_VERSION:-unknown}). On macOS: brew install bash" >&2
  exit 1
fi

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

# Keep exported utility functions available to this shell without passing their
# large definitions to every external command started by the installer.
while IFS= read -r function_name; do
  export -nf "$function_name" 2>/dev/null || true
done < <(compgen -A function)

readonly INSTALLER_MODULES=("package-command" "packages" "app-config" "configs" "git-config" "menu")
for installer_module in "${INSTALLER_MODULES[@]}"; do
  source "$SCRIPT_DIR/installer/shell/$installer_module.sh" 2>/dev/null || {
    echo "Error: Cannot load $installer_module.sh installer module" >&2
    exit 1
  }
done

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

Main() {
  if ! CheckInstallCompatibility; then
    exit 1
  fi
  while true; do
    ShowMenu
    read -r -p "Enter your choice: " choice
    printf '\n'
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
