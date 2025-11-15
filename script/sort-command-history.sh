#!/usr/bin/env bash

if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Error: This script requires bash 4+ (detected: ${BASH_VERSION:-unknown}). On macOS: brew install bash" >&2
  exit 1
fi

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
if [[ ! -f "$UTILS_DIR/file.sh" || ! -f "$UTILS_DIR/logger.sh" || ! -f "$UTILS_DIR/progress.sh" ]]; then
  UTILS_DIR="$SCRIPT_DIR/../utils/shell"
fi
readonly UTILS_DIR
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SYSTEM_OS_TYPE="$(uname -s)"
readonly FISH_HISTORY_PATH="${HOME}/.local/share/fish/fish_history"
readonly POWERSHELL_HISTORY_PATH="${HOME}/AppData/Roaming/Microsoft/Windows/PowerShell/PSReadLine/ConsoleHost_history.txt"
readonly OS_PATTERN_SUPPORTED="^(Darwin|Linux|MINGW|MSYS|CYGWIN)"
readonly OS_PATTERN_UNIX="^(Darwin|Linux)"
readonly BACKUP_DIR="${HOME}/.history_backups"

source "$UTILS_DIR/file.sh" 2>/dev/null || {
  echo "Error: Cannot load file.sh utility" >&2
  exit 1
}
source "$UTILS_DIR/progress.sh" 2>/dev/null || {
  echo "Error: Cannot load progress.sh utility" >&2
  exit 1
}
source "$UTILS_DIR/logger.sh" 2>/dev/null || {
  echo "Error: Cannot load logger.sh utility" >&2
  exit 1
}

declare history_file_path=""
declare DRY_RUN=true
declare SHOW_STATS=false
declare BACKUP_ENABLED=false
declare QUIET_MODE=false

ShowUsage() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Sort Command History - Sort and deduplicate shell command history

OPTIONS:
  -h, --help              Show this help message
  -f, --force             Force apply changes (disable dry run)
  -s, --stats             Show statistics after sorting
  -b, --backup            Create backup before sorting
  -q, --quiet             Suppress log output

RESTORE A BACKUP:
  --backup saves the history file to ~/.history_backups/YYYYMMDD_HHMMSS/.
  To restore it, copy the file back:
    fish        cp ~/.history_backups/YYYYMMDD_HHMMSS/fish_history ~/.local/share/fish/fish_history
    PowerShell  cp ~/.history_backups/YYYYMMDD_HHMMSS/ConsoleHost_history.txt ~/AppData/Roaming/Microsoft/Windows/PowerShell/PSReadLine/ConsoleHost_history.txt

EXAMPLES:
  $SCRIPT_NAME                           # Dry run
  $SCRIPT_NAME --force                   # Actually sort history
  $SCRIPT_NAME --force --backup          # Sort with backup
  $SCRIPT_NAME --force --backup --stats  # Sort with backup and statistics
EOF
}

ParseArguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        ShowUsage
        exit 0
        ;;
      -f|--force)
        DRY_RUN=false
        shift
        ;;
      -s|--stats)
        SHOW_STATS=true
        shift
        ;;
      -b|--backup)
        BACKUP_ENABLED=true
        shift
        ;;
      -q|--quiet)
        QUIET_MODE=true
        shift
        ;;
      *)
        LogError "Unknown option: $1"
        ShowUsage
        exit 1
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

QuietLogKeyValue() {
  if [[ "$QUIET_MODE" != "true" ]]; then
    LogKeyValue "$@"
  fi
}

ValidateSystemEnvironment() {
  if [[ ! "${SYSTEM_OS_TYPE}" =~ ${OS_PATTERN_SUPPORTED} ]]; then
    LogError "Unsupported OS: ${SYSTEM_OS_TYPE}"
    return 1
  fi
  LogInfo "OS detected: ${SYSTEM_OS_TYPE}"
  return 0
}

InitializeHistoryFilePath() {
  if [[ "${SYSTEM_OS_TYPE}" =~ ${OS_PATTERN_UNIX} ]]; then
    history_file_path="${FISH_HISTORY_PATH}"
  else
    history_file_path="${POWERSHELL_HISTORY_PATH}"
  fi
  if [[ ! -f "${history_file_path}" ]]; then
    LogError "History file not found: ${history_file_path}"
    return 1
  fi
  if [[ ! -r "${history_file_path}" ]]; then
    LogError "Permission denied reading: ${history_file_path}"
    return 1
  fi
  if [[ ! -w "${history_file_path}" ]]; then
    LogError "Permission denied writing: ${history_file_path}"
    return 1
  fi
  QuietLogInfo "History file: ${history_file_path}"
  return 0
}

ProcessHistoryContent() {
  local temp_file
  temp_file=$(mktemp) || {
    LogError "Failed to create temporary file"
    return 1
  }
  local original_count=0
  local sorted_count=0
  original_count=$(wc -l < "${history_file_path}" 2>/dev/null || echo "0")
  if [[ "${SYSTEM_OS_TYPE}" =~ ${OS_PATTERN_UNIX} ]]; then
    awk '!/^[[:space:]]*$/ && /^- [[:space:]]?cmd:/' "${history_file_path}" | \
    sort -u > "${temp_file}"
  else
    awk '!/^[[:space:]]*$/' "${history_file_path}" | \
    LC_ALL=C sort -u > "${temp_file}"
  fi
  if [[ ! -s "${temp_file}" ]]; then
    rm -f "${temp_file}"
    LogError "No content after processing"
    return 1
  fi
  sorted_count=$(wc -l < "${temp_file}" 2>/dev/null || echo "0")
  if [[ "$DRY_RUN" == "true" ]]; then
    QuietLogWarning "DRY RUN: Would remove $((original_count - sorted_count)) duplicate entries"
    if [[ "$SHOW_STATS" == "true" ]]; then
      LogKeyValue "Original entries" "$original_count"
      LogKeyValue "After deduplication" "$sorted_count"
      LogKeyValue "Duplicates removed" "$((original_count - sorted_count))"
    fi
    rm -f "${temp_file}"
    return 0
  fi
  if [[ "$BACKUP_ENABLED" == "true" ]]; then
    QuietLogInfo "Creating backup..."
    local backup_path
    backup_path=$(CreateBackup "$history_file_path" "$BACKUP_DIR" "false")
    if [[ $? -eq 0 && -n "$backup_path" ]]; then
      QuietLogSuccess "Backup created: $backup_path"
    else
      rm -f "${temp_file}"
      LogError "Backup failed, skipping sort for safety"
      return 1
    fi
  fi
  if ! cat "${temp_file}" > "${history_file_path}"; then
    rm -f "${temp_file}"
    LogError "Failed to write sorted history"
    return 1
  fi
  rm -f "${temp_file}"
  QuietLogSuccess "History sorted and deduplicated"
  if [[ "$SHOW_STATS" == "true" ]]; then
    QuietLogKeyValue "Original entries" "$original_count"
    QuietLogKeyValue "After deduplication" "$sorted_count"
    QuietLogKeyValue "Duplicates removed" "$((original_count - sorted_count))"
  fi
  return 0
}

Main() {
  ParseArguments "$@"
  if ! ValidateSystemEnvironment; then
    exit 1
  fi
  if ! InitializeHistoryFilePath; then
    exit 1
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    if [[ "$QUIET_MODE" != "true" ]]; then
      LogWarning "Running in DRY RUN mode - no changes will be made"
      LogInfo "Use --force to actually sort history"
    fi
  fi
  if ! ProcessHistoryContent; then
    exit 1
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    if [[ "$QUIET_MODE" != "true" ]]; then
      LogWarning "This was a dry run. Use --force to apply changes."
    fi
  fi
}

Main "$@"
