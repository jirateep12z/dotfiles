#!/usr/bin/env bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly MIN_DOCK_SIZE=20
readonly MAX_DOCK_SIZE=100
readonly DEFAULT_DOCK_SIZE=80

source "$SCRIPT_DIR/utils/file.sh" 2>/dev/null || {
  echo "Error: Cannot load file.sh utility" >&2
  exit 1
}
source "$SCRIPT_DIR/utils/logger.sh" 2>/dev/null || {
  echo "Error: Cannot load logger.sh utility" >&2
  exit 1
}

declare DOCK_SIZE=""
declare SHOW_CURRENT=false
declare RESET_TO_DEFAULT=false
declare QUIET_MODE=false

ShowUsage() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] [SIZE]

Resize macOS Dock tile size

OPTIONS:
  -h, --help              Show this help message
  -c, --current           Show current dock tile size
  -r, --reset             Reset to default size (80)
  -q, --quiet             Suppress log output
  SIZE                    Dock tile size (20-100)

EXAMPLES:
  $SCRIPT_NAME 50                 # Set dock size to 50
  $SCRIPT_NAME --current          # Show current dock size
  $SCRIPT_NAME --reset            # Reset to default size

EOF
}

ParseArguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        ShowUsage
        exit 0
        ;;
      -c|--current)
        SHOW_CURRENT=true
        shift
        ;;
      -r|--reset)
        RESET_TO_DEFAULT=true
        shift
        ;;
      -q|--quiet)
        QUIET_MODE=true
        shift
        ;;
      -*)
        LogError "Unknown option: $1"
        ShowUsage
        exit 1
        ;;
      *)
        DOCK_SIZE="$1"
        shift
        ;;
    esac
  done
}

QuietLogInfo() {
  if [[ "$QUIET_MODE" != "true" ]]; then
    LogInfo "$@"
  fi
}

QuietLogWarning() {
  if [[ "$QUIET_MODE" != "true" ]]; then
    LogWarning "$@"
  fi
}

QuietLogSuccess() {
  if [[ "$QUIET_MODE" != "true" ]]; then
    LogSuccess "$@"
  fi
}

GetCurrentDockSize() {
  local current_size
  current_size=$(defaults read com.apple.dock tilesize 2>/dev/null)
  if [[ -z "$current_size" ]]; then
    echo "$DEFAULT_DOCK_SIZE"
  else
    echo "$current_size"
  fi
}

CheckDockResizeCompatibility() {
  if [[ $OSTYPE != "darwin"* ]]; then
    LogError "This script only supports macOS"
    return 1
  fi
  return 0
}

ValidateDockTileSize() {
  local dock_tile_size="$1"
  if [[ ! "$dock_tile_size" =~ ^[0-9]+$ ]]; then
    LogError "Dock tile size must be a number"
    return 1
  fi
  if [[ "$dock_tile_size" -lt $MIN_DOCK_SIZE || "$dock_tile_size" -gt $MAX_DOCK_SIZE ]]; then
    LogError "Dock tile size must be between $MIN_DOCK_SIZE and $MAX_DOCK_SIZE"
    return 1
  fi
  return 0
}

ApplyDockTileSize() {
  local dock_tile_size="$1"
  QuietLogInfo "Applying dock size: $dock_tile_size"
  if defaults write com.apple.dock tilesize -int "$dock_tile_size" 2>/dev/null; then
    if killall Dock 2>/dev/null; then
      QuietLogSuccess "Dock resized to $dock_tile_size successfully"
      return 0
    else
      QuietLogWarning "Dock size changed but failed to restart Dock"
      return 1
    fi
  else
    LogError "Failed to change dock size"
    return 1
  fi
}

Main() {
  if ! CheckDockResizeCompatibility; then
    exit 1
  fi
  ParseArguments "$@"
  if [[ "$SHOW_CURRENT" == "true" ]]; then
    local current_size=$(GetCurrentDockSize)
    LogKeyValue "Current dock size" "$current_size"
    exit 0
  fi
  if [[ "$RESET_TO_DEFAULT" == "true" ]]; then
    QuietLogInfo "Resetting dock to default size ($DEFAULT_DOCK_SIZE)"
    DOCK_SIZE=$DEFAULT_DOCK_SIZE
  fi
  if [[ -z "$DOCK_SIZE" ]]; then
    LogError "Dock size not specified"
    ShowUsage
    exit 1
  fi
  if ! ValidateDockTileSize "$DOCK_SIZE"; then
    exit 1
  fi
  local current_size=$(GetCurrentDockSize)
  if [[ "$current_size" == "$DOCK_SIZE" ]]; then
    QuietLogWarning "Dock is already set to size $DOCK_SIZE"
    exit 0
  fi
  QuietLogInfo "Current dock size: $current_size"
  ApplyDockTileSize "$DOCK_SIZE"
}

Main "$@"
