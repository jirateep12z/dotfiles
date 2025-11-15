#!/usr/bin/env bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="${HOME}/.ide-config"

source "$SCRIPT_DIR/utils/file.sh" 2>/dev/null || {
  echo "Error: Cannot load file.sh utility" >&2
  exit 1
}
source "$SCRIPT_DIR/utils/logger.sh" 2>/dev/null || {
  echo "Error: Cannot load logger.sh utility" >&2
  exit 1
}

declare LAYOUT_TYPE="default"
declare -a WINDOW_NAMES=("editor" "terminal" "debug")
declare CUSTOM_CONFIG=""

ShowUsage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

IDE Setup Script - Configure tmux layout for development

OPTIONS:
  -h, --help              Show this help message
  -l, --layout TYPE       Layout type: default, wide, tall, quad (default: default)
  -c, --config FILE       Load custom config file
  -n, --names NAMES       Window names (comma-separated)

LAYOUTS:
  default                 Vertical split (70/30) + horizontal split on bottom
  wide                    Horizontal split (60/40)
  tall                    Vertical split (40/60)
  quad                    Four panes (2x2 grid)

EXAMPLES:
  $(basename "$0")                              # Use default layout
  $(basename "$0") --layout wide                # Use wide layout
  $(basename "$0") --names "vim,bash,debug"    # Custom window names

EOF
}

ParseArguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        ShowUsage
        exit 0
        ;;
      -l|--layout)
        LAYOUT_TYPE="$2"
        shift 2
        ;;
      -c|--config)
        CUSTOM_CONFIG="$2"
        shift 2
        ;;
      -n|--names)
        IFS=',' read -ra WINDOW_NAMES <<< "$2"
        shift 2
        ;;
      *)
        LogError "Unknown option: $1"
        ShowUsage
        exit 1
        ;;
    esac
  done
}

LoadConfig() {
  if [[ -f "$CONFIG_FILE" ]]; then
    if _ValidateFile "$CONFIG_FILE" >/dev/null 2>&1; then
      local file_age=$(GetFileAge "$CONFIG_FILE" "days")
      LogInfo "Loading config from: $CONFIG_FILE (age: ${file_age} days)"
      source "$CONFIG_FILE"
    else
      LogWarning "Config file validation failed: $CONFIG_FILE"
    fi
  fi
  if [[ -n "$CUSTOM_CONFIG" && -f "$CUSTOM_CONFIG" ]]; then
    if _ValidateFile "$CUSTOM_CONFIG" >/dev/null 2>&1; then
      LogInfo "Loading custom config from: $CUSTOM_CONFIG"
      source "$CUSTOM_CONFIG"
    else
      LogWarning "Custom config file validation failed: $CUSTOM_CONFIG"
    fi
  fi
}

CheckIDECompatibility() {
  local os_type="$(uname -s)"
  case "${os_type}" in
    "Darwin"|"Linux")
      LogInfo "OS detected: ${os_type}"
      return 0
      ;;
    "MINGW"*|"MSYS"*|"CYGWIN"*)
      LogWarning "Windows detected - tmux may not work properly"
      return 0
      ;;
    *)
      LogError "Unsupported OS: ${os_type}"
      return 1
      ;;
  esac
}

CheckTmux() {
  if ! command -v tmux >/dev/null 2>&1; then
    LogError "tmux is not installed"
    return 1
  fi
  if [[ -z "$TMUX" ]]; then
    LogError "Please run this script inside tmux"
    return 1
  fi
  local tmux_version=$(tmux -V | grep -oE '[0-9]+\.[0-9]+')
  LogInfo "tmux version: $tmux_version"
  return 0
}

ValidateTmuxLayout() {
  local pane_count=$(tmux list-panes -t "$TMUX_PANE" | wc -l)
  LogInfo "Current pane count: $pane_count"
  if [[ $pane_count -lt 1 ]]; then
    LogError "Invalid tmux layout"
    return 1
  fi
  return 0
}

SetupDefaultLayout() {
  LogInfo "Setting up default layout (70/30 + horizontal split)"
  tmux split-window -v -l 30%
  tmux split-window -h -l 50% -t 1
  tmux select-pane -t 0
  if [[ ${#WINDOW_NAMES[@]} -ge 3 ]]; then
    tmux rename-window -t 0 "${WINDOW_NAMES[0]}"
    tmux select-pane -t 1 && tmux rename-window -t 1 "${WINDOW_NAMES[1]}"
    tmux select-pane -t 2 && tmux rename-window -t 2 "${WINDOW_NAMES[2]}"
  fi
}

SetupWideLayout() {
  LogInfo "Setting up wide layout (60/40 horizontal split)"
  tmux split-window -h -l 40%
  tmux select-pane -t 0
  if [[ ${#WINDOW_NAMES[@]} -ge 2 ]]; then
    tmux rename-window -t 0 "${WINDOW_NAMES[0]}"
    tmux select-pane -t 1 && tmux rename-window -t 1 "${WINDOW_NAMES[1]}"
  fi
}

SetupTallLayout() {
  LogInfo "Setting up tall layout (40/60 vertical split)"
  tmux split-window -v -l 60%
  tmux select-pane -t 0
  if [[ ${#WINDOW_NAMES[@]} -ge 2 ]]; then
    tmux rename-window -t 0 "${WINDOW_NAMES[0]}"
    tmux select-pane -t 1 && tmux rename-window -t 1 "${WINDOW_NAMES[1]}"
  fi
}

SetupQuadLayout() {
  LogInfo "Setting up quad layout (2x2 grid)"
  tmux split-window -h -l 50%
  tmux split-window -v -l 50% -t 0
  tmux split-window -v -l 50% -t 2
  tmux select-pane -t 0
  if [[ ${#WINDOW_NAMES[@]} -ge 4 ]]; then
    for ((i=0; i<4; i++)); do
      tmux select-pane -t $i && tmux rename-window -t $i "${WINDOW_NAMES[i]}"
    done
  fi
}

SetupIDELayout() {
  case "$LAYOUT_TYPE" in
    default)
      SetupDefaultLayout
      ;;
    wide)
      SetupWideLayout
      ;;
    tall)
      SetupTallLayout
      ;;
    quad)
      SetupQuadLayout
      ;;
    *)
      LogError "Unknown layout type: $LAYOUT_TYPE"
      return 1
      ;;
  esac
  ValidateTmuxLayout
}

Main() {
  ParseArguments "$@"
  LoadConfig
  if ! CheckIDECompatibility; then
    exit 1
  fi
  if ! CheckTmux; then
    exit 1
  fi
  LogInfo "Setting up IDE with layout: $LAYOUT_TYPE"
  if SetupIDELayout; then
    LogSuccess "IDE layout setup completed!"
  else
    LogError "Failed to setup IDE layout"
    exit 1
  fi
}

Main "$@"
