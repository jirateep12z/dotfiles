#!/usr/bin/env bash

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
