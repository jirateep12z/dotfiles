#!/usr/bin/env bash

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
