#!/usr/bin/env bash

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
