#!/usr/bin/env bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SYSTEM_OS_TYPE="$(uname -s)"
readonly FISH_HISTORY_PATH="${HOME}/.local/share/fish/fish_history"
readonly POWERSHELL_HISTORY_PATH="${HOME}/AppData/Roaming/Microsoft/Windows/PowerShell/PSReadLine/ConsoleHost_history.txt"
readonly OS_PATTERN_SUPPORTED="^(Darwin|Linux|MINGW*|MSYS*)"
readonly OS_PATTERN_UNIX="^(Darwin|Linux)"
readonly BACKUP_DIR="${HOME}/.history_backups"

source "$SCRIPT_DIR/utils/file.sh" 2>/dev/null || {
  echo "Error: Cannot load file.sh utility" >&2
  exit 1
}
source "$SCRIPT_DIR/utils/progress.sh" 2>/dev/null || {
  echo "Error: Cannot load progress.sh utility" >&2
  exit 1
}
source "$SCRIPT_DIR/utils/logger.sh" 2>/dev/null || {
  echo "Error: Cannot load logger.sh utility" >&2
  exit 1
}

declare history_file_path=""
declare DRY_RUN=true
declare SHOW_STATS=false
declare BACKUP_ENABLED=false
declare BACKUP_LIST=false
declare BACKUP_DELETE=""
declare BACKUP_RESTORE=""
declare BACKUP_DELETE_ALL=false
declare QUIET_MODE=false

ShowUsage() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Sort and deduplicate shell command history

OPTIONS:
  -h, --help              Show this help message
  -d, --dry-run           Dry run mode (default: true)
  -f, --force             Force apply changes (disable dry run)
  -s, --stats             Show statistics after sorting
  -b, --backup            Create backup before sorting
  -q, --quiet             Suppress log output
  -lb, --list-backups     List all backup files
  -db, --delete-backup    Delete backup file (use with --backup-file)
  -dba, --delete-all      Delete all backup files
  -rb, --restore-backup   Restore from backup file (use with --backup-file)
  --backup-file FILE      Specify backup file to delete or restore

EXAMPLES:
  $SCRIPT_NAME                    # Dry run
  $SCRIPT_NAME --force            # Actually sort history
  $SCRIPT_NAME --force --backup   # Sort with backup
  $SCRIPT_NAME --force --backup --stats # Sort with backup and statistics
  $SCRIPT_NAME --list-backups     # List all backups
  $SCRIPT_NAME --restore-backup --backup-file FILE  # Restore from backup

EOF
}

ParseArguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        ShowUsage
        exit 0
        ;;
      -d|--dry-run)
        DRY_RUN=true
        shift
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
      -lb|--list-backups)
        BACKUP_LIST=true
        shift
        ;;
      -db|--delete-backup)
        BACKUP_DELETE="true"
        shift
        ;;
      -dba|--delete-all)
        BACKUP_DELETE_ALL=true
        shift
        ;;
      -rb|--restore-backup)
        BACKUP_RESTORE="true"
        shift
        ;;
      --backup-file)
        if [[ "$BACKUP_DELETE" == "true" ]]; then
          BACKUP_DELETE="$2"
        elif [[ "$BACKUP_RESTORE" == "true" ]]; then
          BACKUP_RESTORE="$2"
        fi
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

ListBackups() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    QuietLogWarning "No backup directory found"
    return 0
  fi
  local backup_count=0
  QuietLogInfo "Available backups:"
  while IFS= read -r backup_file; do
    ((backup_count++))
    local file_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null || echo "0")
    printf "  %2d. %s (%s)\n" "$backup_count" "$(basename "$backup_file")" "$file_size bytes"
  done < <(find "$BACKUP_DIR" -type f 2>/dev/null | sort -r)
  if [[ $backup_count -eq 0 ]]; then
    QuietLogWarning "No backup files found"
  fi
}

DeleteBackup() {
  local backup_file="$1"
  if [[ -z "$backup_file" || "$backup_file" == "true" ]]; then
    LogError "Backup file not specified"
    return 1
  fi
  if [[ ! -f "$backup_file" ]]; then
    backup_file="$BACKUP_DIR/$backup_file"
  fi
  if [[ ! -f "$backup_file" ]]; then
    LogError "Backup file not found: $backup_file"
    return 1
  fi
  if rm "$backup_file" 2>/dev/null; then
    QuietLogSuccess "Backup deleted: $(basename "$backup_file")"
    return 0
  else
    LogError "Failed to delete backup: $backup_file"
    return 1
  fi
}

DeleteAllBackups() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    QuietLogWarning "No backup directory found"
    return 0
  fi
  local backup_count=0
  local deleted_count=0
  while IFS= read -r backup_file; do
    ((backup_count++))
  done < <(find "$BACKUP_DIR" -type f 2>/dev/null)
  if [[ $backup_count -eq 0 ]]; then
    QuietLogWarning "No backup files found"
    return 0
  fi
  QuietLogWarning "Found $backup_count backup files to delete"
  read -p "Are you sure you want to delete all $backup_count backups? (Y/N): " -r confirm_delete
  if [[ "${confirm_delete^^}" != "Y" ]]; then
    QuietLogInfo "Operation cancelled"
    return 1
  fi
  local current=0
  while IFS= read -r backup_file; do
    ((current++))
    if rm "$backup_file" 2>/dev/null; then
      ((deleted_count++))
    else
      LogError "Failed to delete: $(basename "$backup_file")"
    fi
    if [[ "$QUIET_MODE" != "true" ]]; then
      ShowProgress "$current" "$backup_count" "Deleting" "true" 50 "detailed"
    fi
  done < <(find "$BACKUP_DIR" -type f 2>/dev/null)
  if [[ "$QUIET_MODE" != "true" ]]; then
    ClearProgress "true" "true"
  fi
  QuietLogSuccess "Deleted $deleted_count/$backup_count backups"
  return 0
}

RestoreBackup() {
  local backup_file="$1"
  if [[ -z "$backup_file" || "$backup_file" == "true" ]]; then
    LogError "Backup file not specified"
    return 1
  fi
  if [[ ! -f "$backup_file" ]]; then
    backup_file="$BACKUP_DIR/$backup_file"
  fi
  if [[ ! -f "$backup_file" ]]; then
    LogError "Backup file not found: $backup_file"
    return 1
  fi
  QuietLogInfo "Restoring from: $(basename "$backup_file")"
  if cp "$backup_file" "${history_file_path}" 2>/dev/null; then
    QuietLogSuccess "History restored from: $(basename "$backup_file")"
    return 0
  else
    LogError "Failed to restore backup: $backup_file"
    return 1
  fi
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
    sort -u > "${temp_file}"
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
  if [[ "$BACKUP_LIST" == "true" ]]; then
    ListBackups
    exit 0
  fi
  if [[ "$BACKUP_DELETE_ALL" == "true" ]]; then
    DeleteAllBackups
    exit $?
  fi
  if [[ "$BACKUP_DELETE" != "" && "$BACKUP_DELETE" != "false" ]]; then
    DeleteBackup "$BACKUP_DELETE"
    exit $?
  fi
  if [[ "$BACKUP_RESTORE" != "" && "$BACKUP_RESTORE" != "false" ]]; then
    if ! ValidateSystemEnvironment; then
      exit 1
    fi
    if ! InitializeHistoryFilePath; then
      exit 1
    fi
    RestoreBackup "$BACKUP_RESTORE"
    exit $?
  fi
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