#!/usr/bin/env bash

shopt -s dotglob

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

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

declare CLEANUP_DRY_RUN=true
declare CLEANUP_BACKUP=false
declare CLEANUP_MIN_AGE_DAYS=0
declare CLEANUP_SHOW_PROGRESS=true
declare -a CLEANUP_EXCLUDE_PATTERNS=()
declare CLEANUP_MIN_SIZE_BYTES=0
declare CLEANUP_INTERACTIVE=false
declare CLEANUP_COMPRESS_BACKUP=false
declare CLEANUP_HISTORY_FILE="$HOME/.cleanup_history"
declare CLEANUP_BACKUP_LIST=false
declare CLEANUP_BACKUP_DELETE=""
declare CLEANUP_BACKUP_RESTORE=""
declare CLEANUP_BACKUP_DELETE_ALL=false
declare CLEANUP_QUIET_MODE=false

declare DRY_RUN=$CLEANUP_DRY_RUN
declare BACKUP_ENABLED=$CLEANUP_BACKUP
declare MIN_AGE_DAYS=$CLEANUP_MIN_AGE_DAYS
declare SHOW_PROGRESS=$CLEANUP_SHOW_PROGRESS
declare BACKUP_DIR="$HOME/.cleanup_backups"
declare -a EXCLUDE_PATTERNS=()
declare TOTAL_SIZE_CLEANED=0
declare TOTAL_FILES_CLEANED=0
declare -a DRY_RUN_ITEMS=()
declare MIN_SIZE_BYTES=$CLEANUP_MIN_SIZE_BYTES
declare INTERACTIVE=$CLEANUP_INTERACTIVE
declare COMPRESS_BACKUP=$CLEANUP_COMPRESS_BACKUP
declare BACKUP_LIST=$CLEANUP_BACKUP_LIST
declare BACKUP_DELETE=$CLEANUP_BACKUP_DELETE
declare BACKUP_RESTORE=$CLEANUP_BACKUP_RESTORE
declare BACKUP_DELETE_ALL=$CLEANUP_BACKUP_DELETE_ALL
declare QUIET_MODE=$CLEANUP_QUIET_MODE

ShowUsage() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Directory Cleanup Script - Clean temporary files and directories safely

OPTIONS:
  -h, --help              Show this help message
  -d, --dry-run           Dry run mode (default: true)
  -f, --force             Force cleanup (disable dry run)
  -b, --backup            Create backup before cleanup
  -z, --compress          Compress backups (tar.gz)
  -a, --age DAYS          Only clean files older than DAYS (default: 0)
  -s, --min-size SIZE     Only clean files larger than SIZE (e.g., 10M, 1G)
  -e, --exclude PATTERN   Exclude files matching PATTERN (can be used multiple times)
  -i, --interactive       Interactive mode (select directories to clean)
  -q, --quiet             Suppress log output
  -lb, --list-backups     List all backup files
  -db, --delete-backup    Delete backup file (use with --backup-file)
  -dba, --delete-all      Delete all backup files
  -rb, --restore-backup   Restore from backup file (use with --backup-file)
  --backup-file FILE      Specify backup file to delete or restore
  --backup-dir DIR        Custom backup directory (default: ~/.cleanup_backups)
  --history FILE          Cleanup history file (default: ~/.cleanup_history)

EXAMPLES:
  $SCRIPT_NAME                          # Dry run with default settings
  $SCRIPT_NAME --force                  # Actually perform cleanup
  $SCRIPT_NAME --force --backup         # Cleanup with backup
  $SCRIPT_NAME --force --age 30         # Clean files older than 30 days
  $SCRIPT_NAME --force --min-size 100M  # Clean files larger than 100MB
  $SCRIPT_NAME --force --interactive    # Interactive mode
  $SCRIPT_NAME --force --backup --compress  # Backup with compression

EOF
}

ConvertSizeToBytes() {
  local size_str="$1"
  local size_num="${size_str%[A-Za-z]*}"
  local size_unit="${size_str##*[0-9]}"
  size_unit="${size_unit^^}"
  case "$size_unit" in
    K|KB) echo $((size_num * 1024)) ;;
    M|MB) echo $((size_num * 1024 * 1024)) ;;
    G|GB) echo $((size_num * 1024 * 1024 * 1024)) ;;
    *) echo "$size_num" ;;
  esac
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
      -b|--backup)
        BACKUP_ENABLED=true
        shift
        ;;
      -z|--compress)
        COMPRESS_BACKUP=true
        shift
        ;;
      -a|--age)
        MIN_AGE_DAYS="$2"
        shift 2
        ;;
      -s|--min-size)
        MIN_SIZE_BYTES=$(ConvertSizeToBytes "$2")
        shift 2
        ;;
      -e|--exclude)
        EXCLUDE_PATTERNS+=("$2")
        shift 2
        ;;
      -i|--interactive)
        INTERACTIVE=true
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
      --backup-dir)
        BACKUP_DIR="$2"
        shift 2
        ;;
      --history)
        CLEANUP_HISTORY_FILE="$2"
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

ShouldExclude() {
  local path="$1"
  local filename=$(basename "$path")
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    if CheckFilePattern "$path" "$pattern" "false"; then
      return 0
    fi
  done
  return 1
}

ShouldCleanBySize() {
  local file_size="$1"
  if [[ $MIN_SIZE_BYTES -gt 0 && $file_size -lt $MIN_SIZE_BYTES ]]; then
    return 1
  fi
  return 0
}

LogCleanupHistory() {
  local action="$1"
  local path="$2"
  local size="$3"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $action | $path | $(FormatBytes $size 2)" >> "$CLEANUP_HISTORY_FILE"
}

SelectDirectoriesInteractive() {
  local available_dirs=("$@")
  local selected_dirs=()
  local idx=1
  QuietLogInfo "Available directories:"
  for dir in "${available_dirs[@]}"; do
    printf "%2d. %s\n" "$idx" "$dir"
    ((idx++))
  done
  read -p "Enter directory numbers to clean (comma-separated, or 'all'): " -r selection
  if [[ "$selection" == "all" ]]; then
    selected_dirs=("${available_dirs[@]}")
  else
    IFS=',' read -ra indices <<< "$selection"
    for i in "${indices[@]}"; do
      i=$(echo "$i" | xargs)
      if [[ "$i" =~ ^[0-9]+$ ]] && [[ $i -ge 1 ]] && [[ $i -le ${#available_dirs[@]} ]]; then
        selected_dirs+=("${available_dirs[$((i-1))]}")
      fi
    done
  fi
  printf '%s\n' "${selected_dirs[@]}"
}

DeleteDirectoryContents() {
  local directory_path="$1"
  local description="${2:-}"
  if [[ ! -d "$directory_path" ]]; then
    QuietLogWarning "Directory not found: $directory_path"
    return 1
  fi
  local dir_size=$(GetDirectorySize "$directory_path" "true")
  local file_count=$(CountFiles "$directory_path")
  if [[ "$file_count" -eq 0 ]]; then
    QuietLogInfo "Directory is empty: $directory_path"
    return 0
  fi
  QuietLogInfo "Processing: $directory_path ($file_count files, $dir_size)"
  if [[ -n "$description" ]]; then
    QuietLogInfo "Description: $description"
  fi
  if [[ "$BACKUP_ENABLED" == "true" && "$DRY_RUN" == "false" ]]; then
    QuietLogInfo "Creating backup..."
    local backup_path
    backup_path=$(CreateBackup "$directory_path" "$BACKUP_DIR" "false")
    if [[ $? -eq 0 && -n "$backup_path" ]]; then
      if [[ "$COMPRESS_BACKUP" == "true" ]]; then
        local compressed_path="${backup_path}.tar.gz"
        if tar -czf "$compressed_path" -C "$(dirname "$backup_path")" "$(basename "$backup_path")" 2>/dev/null; then
          rm -rf "$backup_path"
          backup_path="$compressed_path"
          QuietLogSuccess "Compressed backup created: $backup_path"
        else
          QuietLogWarning "Compression failed, keeping uncompressed backup: $backup_path"
        fi
      fi
      QuietLogSuccess "Backup created: $backup_path"
    else
      LogError "Backup failed, skipping cleanup for safety"
      return 1
    fi
  fi
  local current=0
  local cleaned_size=0
  local cleaned_files=0
  local failed_files=0
  while IFS= read -r -d '' item; do
    ((current++))
    if ShouldExclude "$item"; then
      continue
    fi
    if [[ "$MIN_AGE_DAYS" -gt 0 ]]; then
      if ! CheckFileAge "$item" "$MIN_AGE_DAYS" "days"; then
        continue
      fi
    fi
    local item_size=$(GetFileSize "$item" 2>/dev/null || echo "0")
    if ! ShouldCleanBySize "$item_size"; then
      continue
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
      cleaned_files=$((cleaned_files + 1))
      cleaned_size=$((cleaned_size + item_size))
      DRY_RUN_ITEMS+=("$item")
    else
      if rm -rf "$item" 2>/dev/null; then
        ((cleaned_files++))
        cleaned_size=$((cleaned_size + item_size))
        LogCleanupHistory "DELETED" "$item" "$item_size"
      else
        ((failed_files++))
      fi
    fi
    if [[ "$SHOW_PROGRESS" == "true" && "$QUIET_MODE" != "true" && $((current % 10)) -eq 0 ]]; then
      ShowProgress "$current" "$file_count" "Cleaning" "true" 50 "detailed"
    fi
  done < <(find "$directory_path" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
  if [[ "$SHOW_PROGRESS" == "true" && "$QUIET_MODE" != "true" ]]; then
    ClearProgress "true" "true"
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    QuietLogWarning "DRY RUN: Would clean $cleaned_files items ($(FormatBytes $cleaned_size 2))"
  else
    TOTAL_FILES_CLEANED=$((TOTAL_FILES_CLEANED + cleaned_files))
    TOTAL_SIZE_CLEANED=$((TOTAL_SIZE_CLEANED + cleaned_size))
    if [[ $failed_files -gt 0 ]]; then
      QuietLogWarning "Cleaned $cleaned_files items, failed: $failed_files ($(FormatBytes $cleaned_size 2))"
    else
      QuietLogSuccess "Cleaned $cleaned_files items ($(FormatBytes $cleaned_size 2))"
    fi
  fi
  return 0
}

DeleteFile() {
  local file_path="$1"
  local description="${2:-}"
  if [[ ! -f "$file_path" ]]; then
    QuietLogWarning "File not found: $file_path"
    return 1
  fi
  local file_size=$(GetFileSize "$file_path")
  QuietLogInfo "Processing file: $file_path ($(FormatBytes $file_size 2))"
  if [[ -n "$description" ]]; then
    QuietLogInfo "  Description: $description"
  fi
  if ShouldExclude "$file_path"; then
    QuietLogInfo "Excluded: $file_path"
    return 0
  fi
  if [[ "$MIN_AGE_DAYS" -gt 0 ]]; then
    if ! CheckFileAge "$file_path" "$MIN_AGE_DAYS" "days"; then
      QuietLogInfo "Skipped (too new): $file_path"
      return 0
    fi
  fi
  if [[ "$BACKUP_ENABLED" == "true" && "$DRY_RUN" == "false" ]]; then
    local backup_path=$(CreateBackup "$file_path" "$BACKUP_DIR" "true")
    if [[ $? -eq 0 ]]; then
      QuietLogSuccess "Backup created: $backup_path"
    fi
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    QuietLogWarning "Would delete: $file_path"
    DRY_RUN_ITEMS+=("$file_path")
  else
    if rm -rf "$file_path" 2>/dev/null; then
      QuietLogSuccess "Deleted: $file_path"
      TOTAL_FILES_CLEANED=$((TOTAL_FILES_CLEANED + 1))
      TOTAL_SIZE_CLEANED=$((TOTAL_SIZE_CLEANED + file_size))
    else
      LogError "Failed to delete: $file_path"
      return 1
    fi
  fi
  return 0
}

CleanupMacOS() {
  local macos_cleanup_dirs=(
    "$HOME/Downloads/:Downloaded files"
    "$HOME/Movies/:Movie files"
    "$HOME/Music/:Music files"
    "$HOME/Library/Caches/:Application caches"
    "$HOME/Library/Logs/:Application logs"
    "$HOME/.Trash/:Trash"
    "/tmp/:Temporary files"
  )
  local dirs_to_clean=()
  if [[ "$INTERACTIVE" == "true" ]]; then
    for entry in "${macos_cleanup_dirs[@]}"; do
      IFS=':' read -r dir_path description <<< "$entry"
      [[ -d "$dir_path" ]] && dirs_to_clean+=("$dir_path:$description")
    done
    readarray -t selected < <(SelectDirectoriesInteractive "${dirs_to_clean[@]}")
    for entry in "${selected[@]}"; do
      IFS=':' read -r dir_path description <<< "$entry"
      DeleteDirectoryContents "$dir_path" "$description"
    done
  else
    for entry in "${macos_cleanup_dirs[@]}"; do
      IFS=':' read -r dir_path description <<< "$entry"
      if [[ -d "$dir_path" ]]; then
        DeleteDirectoryContents "$dir_path" "$description"
      fi
    done
  fi
}

CleanupWindows() {
  local windows_cleanup_dirs=(
    "$HOME/Downloads/:Downloaded files"
    "$HOME/Videos/:Video files"
    "$HOME/Music/:Music files"
    "$HOME/AppData/Local/Temp/:Temporary files"
    "$TEMP/:System temporary files"
  )
  local dirs_to_clean=()
  if [[ "$INTERACTIVE" == "true" ]]; then
    for entry in "${windows_cleanup_dirs[@]}"; do
      IFS=':' read -r dir_path description <<< "$entry"
      [[ -d "$dir_path" ]] && dirs_to_clean+=("$dir_path:$description")
    done
    readarray -t selected < <(SelectDirectoriesInteractive "${dirs_to_clean[@]}")
    for entry in "${selected[@]}"; do
      IFS=':' read -r dir_path description <<< "$entry"
      DeleteDirectoryContents "$dir_path" "$description"
    done
  else
    for entry in "${windows_cleanup_dirs[@]}"; do
      IFS=':' read -r dir_path description <<< "$entry"
      if [[ -d "$dir_path" ]]; then
        DeleteDirectoryContents "$dir_path" "$description"
      fi
    done
  fi
}

CleanupLinux() {
  local linux_cleanup_dirs=(
    "$HOME/Downloads/:Downloaded files"
    "$HOME/.cache/:User cache"
    "/tmp/:Temporary files"
    "/var/tmp/:Variable temporary files"
  )
  local dirs_to_clean=()
  if [[ "$INTERACTIVE" == "true" ]]; then
    for entry in "${linux_cleanup_dirs[@]}"; do
      IFS=':' read -r dir_path description <<< "$entry"
      [[ -d "$dir_path" ]] && dirs_to_clean+=("$dir_path:$description")
    done
    readarray -t selected < <(SelectDirectoriesInteractive "${dirs_to_clean[@]}")
    for entry in "${selected[@]}"; do
      IFS=':' read -r dir_path description <<< "$entry"
      DeleteDirectoryContents "$dir_path" "$description"
    done
  else
    for entry in "${linux_cleanup_dirs[@]}"; do
      IFS=':' read -r dir_path description <<< "$entry"
      if [[ -d "$dir_path" ]]; then
        DeleteDirectoryContents "$dir_path" "$description"
      fi
    done
  fi
}

PrintDryRunSummary() {
  if [[ "$DRY_RUN" != "true" || ${#DRY_RUN_ITEMS[@]} -eq 0 ]]; then
    return
  fi
  QuietLogInfo "Items that would be deleted (dry run):"
  local idx=1
  for item in "${DRY_RUN_ITEMS[@]}"; do
    local item_size=$(GetFileSize "$item" 2>/dev/null || echo "0")
    printf "%2d. %s (%s)\n" "$idx" "$item" "$(FormatBytes $item_size 2)"
    ((idx++))
  done
}

ListBackups() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    LogWarning "No backup directory found"
    return 0
  fi
  local backup_count=0
  LogInfo "Available backups:"
  while IFS= read -r backup_file; do
    ((backup_count++))
    local file_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null || echo "0")
    printf "  %2d. %s (%s)\n" "$backup_count" "$(basename "$backup_file")" "$(FormatBytes "$file_size" 2)"
  done < <(find "$BACKUP_DIR" -type f \( -name "*.tar.gz" -o -name "*.zip" \) 2>/dev/null | sort -r)
  if [[ $backup_count -eq 0 ]]; then
    LogWarning "No backup files found"
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
    LogSuccess "Backup deleted: $(basename "$backup_file")"
    return 0
  else
    LogError "Failed to delete backup: $backup_file"
    return 1
  fi
}

DeleteAllBackups() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    LogWarning "No backup directory found"
    return 0
  fi
  local backup_count=0
  local deleted_count=0
  while IFS= read -r backup_file; do
    ((backup_count++))
  done < <(find "$BACKUP_DIR" -type f \( -name "*.tar.gz" -o -name "*.zip" \) 2>/dev/null)
  if [[ $backup_count -eq 0 ]]; then
    LogWarning "No backup files found"
    return 0
  fi
  LogWarning "Found $backup_count backup files to delete"
  read -p "Are you sure you want to delete all $backup_count backups? (Y/N): " -r confirm_delete
  if [[ "${confirm_delete^^}" != "Y" ]]; then
    LogInfo "Operation cancelled"
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
  done < <(find "$BACKUP_DIR" -type f \( -name "*.tar.gz" -o -name "*.zip" \) 2>/dev/null)
  if [[ "$QUIET_MODE" != "true" ]]; then
    ClearProgress "true" "true"
  fi
  LogSuccess "Deleted $deleted_count/$backup_count backups"
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
  if [[ "$backup_file" == *.tar.gz ]]; then
    if tar -xzf "$backup_file" -C / 2>/dev/null; then
      LogSuccess "Backup restored from: $(basename "$backup_file")"
      return 0
    else
      LogError "Failed to restore backup: $backup_file"
      return 1
    fi
  elif [[ "$backup_file" == *.zip ]]; then
    if unzip -q "$backup_file" -d / 2>/dev/null; then
      LogSuccess "Backup restored from: $(basename "$backup_file")"
      return 0
    else
      LogError "Failed to restore backup: $backup_file"
      return 1
    fi
  else
    LogError "Unknown backup format: $backup_file"
    return 1
  fi
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
    RestoreBackup "$BACKUP_RESTORE"
    exit $?
  fi
  local start_time=$(date +%s)
  if [[ "$QUIET_MODE" != "true" ]]; then
    LogInfo "Started at: $(GetTimestamp)"
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    if [[ "$QUIET_MODE" != "true" ]]; then
      LogWarning "Running in DRY RUN mode - no files will be deleted"
      LogInfo "Use --force to actually perform cleanup"
    fi
  else
    if [[ "$QUIET_MODE" != "true" ]]; then
      LogWarning "Running in FORCE mode - files will be deleted!"
    fi
  fi
  if [[ "$BACKUP_ENABLED" == "true" && "$QUIET_MODE" != "true" ]]; then
    LogInfo "Backup enabled: $BACKUP_DIR"
  fi
  if [[ "$MIN_AGE_DAYS" -gt 0 && "$QUIET_MODE" != "true" ]]; then
    LogInfo "Minimum file age: $MIN_AGE_DAYS days"
  fi
  if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 && "$QUIET_MODE" != "true" ]]; then
    LogInfo "Exclude patterns: ${EXCLUDE_PATTERNS[*]}"
  fi
  if [[ "$OSTYPE" == "darwin"* ]]; then
    CleanupMacOS
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    CleanupWindows
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    CleanupLinux
  else
    LogError "Unsupported operating system: $OSTYPE"
    exit 1
  fi
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  if [[ "$QUIET_MODE" != "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      LogInfo "Mode: DRY RUN (no changes made)"
    else
      LogInfo "Mode: FORCE (changes applied)"
      LogKeyValue "Files cleaned" "$TOTAL_FILES_CLEANED"
      LogKeyValue "Space freed" "$(FormatBytes $TOTAL_SIZE_CLEANED 2)"
    fi
    LogKeyValue "Duration" "$(FormatDuration $duration)"
    LogKeyValue "Finished at" "$(GetTimestamp)"
  fi
  PrintDryRunSummary
  if [[ "$DRY_RUN" == "true" ]]; then
    if [[ "$QUIET_MODE" != "true" ]]; then
      LogWarning "This was a dry run. Use --force to actually clean files."
    fi
  else
    if [[ "$QUIET_MODE" != "true" ]]; then
      LogSuccess "Cleanup completed successfully!"
    fi
  fi
}

Main "$@"
