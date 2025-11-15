#!/usr/bin/env bash

if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Error: This script requires bash 4+ (detected: ${BASH_VERSION:-unknown}). On macOS: brew install bash" >&2
  exit 1
fi

shopt -s dotglob

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
if [[ ! -f "$UTILS_DIR/file.sh" || ! -f "$UTILS_DIR/logger.sh" || ! -f "$UTILS_DIR/progress.sh" ]]; then
  UTILS_DIR="$SCRIPT_DIR/../utils/shell"
fi
readonly UTILS_DIR
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SYSTEM_OS_TYPE="$(uname -s)"
readonly OS_PATTERN_SUPPORTED="^(Darwin|Linux|MINGW|MSYS|CYGWIN)"

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

declare CLEANUP_DRY_RUN=true
declare CLEANUP_MIN_AGE_DAYS=0
declare CLEANUP_SHOW_PROGRESS=true
declare -a CLEANUP_EXCLUDE_PATTERNS=()
declare CLEANUP_MIN_SIZE_BYTES=0
declare CLEANUP_INTERACTIVE=false
declare CLEANUP_QUIET_MODE=false
declare -a CLEANUP_FILE_EXTENSIONS=()
declare CLEANUP_ONLY_EXTENSIONS=false

declare DRY_RUN=$CLEANUP_DRY_RUN
declare MIN_AGE_DAYS=$CLEANUP_MIN_AGE_DAYS
declare SHOW_PROGRESS=$CLEANUP_SHOW_PROGRESS
declare -a EXCLUDE_PATTERNS=()
declare TOTAL_SIZE_CLEANED=0
declare TOTAL_FILES_CLEANED=0
declare -a DRY_RUN_ITEMS=()
declare MIN_SIZE_BYTES=$CLEANUP_MIN_SIZE_BYTES
declare INTERACTIVE=$CLEANUP_INTERACTIVE
declare QUIET_MODE=$CLEANUP_QUIET_MODE

ValidateSystemEnvironment() {
  if [[ ! "${SYSTEM_OS_TYPE}" =~ ${OS_PATTERN_SUPPORTED} ]]; then
    LogError "Unsupported OS: ${SYSTEM_OS_TYPE}"
    return 1
  fi
  LogInfo "OS detected: ${SYSTEM_OS_TYPE}"
  return 0
}

ShowUsage() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Directory Cleanup Script - Clean temporary files and directories safely

OPTIONS:
  -h, --help              Show this help message
  -f, --force             Force cleanup (disable dry run)
  -a, --age DAYS          Only clean files older than DAYS (default: 0)
  -s, --min-size SIZE     Only clean files larger than SIZE (e.g., 10M, 1G)
  -e, --exclude PATTERN   Exclude files matching PATTERN (can be used multiple times)
  -i, --interactive       Interactive mode (select directories to clean)
  -q, --quiet             Suppress log output
  --ext EXTENSION         Only delete files with this extension (can be used multiple times)
                          Examples: --ext .log --ext .tmp

EXAMPLES:
  $SCRIPT_NAME                           # Dry run with default settings
  $SCRIPT_NAME --force                   # Actually perform cleanup
  $SCRIPT_NAME --force --age 30          # Clean files older than 30 days
  $SCRIPT_NAME --force --min-size 100M   # Clean files larger than 100MB
  $SCRIPT_NAME --force --interactive     # Interactive mode
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
      -f|--force)
        DRY_RUN=false
        shift
        ;;
      -a|--age)
        if [[ $# -lt 2 || -z "$2" ]]; then
          LogError "--age requires a value"
          exit 1
        fi
        MIN_AGE_DAYS="$2"
        shift 2
        ;;
      -s|--min-size)
        if [[ $# -lt 2 || -z "$2" ]]; then
          LogError "--min-size requires a value"
          exit 1
        fi
        MIN_SIZE_BYTES=$(ConvertSizeToBytes "$2")
        shift 2
        ;;
      -e|--exclude)
        if [[ $# -lt 2 || -z "$2" ]]; then
          LogError "--exclude requires a value"
          exit 1
        fi
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
      --ext)
        if [[ $# -lt 2 || -z "$2" ]]; then
          LogError "--ext requires a value"
          exit 1
        fi
        CLEANUP_FILE_EXTENSIONS+=("$2")
        CLEANUP_ONLY_EXTENSIONS=true
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

ShouldCleanByExtension() {
  local file="$1"
  local dir_extensions="$2"
  if [[ -n "$dir_extensions" ]]; then
    local filename=$(basename "$file")
    IFS=',' read -ra ext_array <<< "$dir_extensions"
    for ext in "${ext_array[@]}"; do
      ext="${ext#"${ext%%[![:space:]]*}"}"
      ext="${ext%"${ext##*[![:space:]]}"}"
      if [[ "$filename" == $ext ]]; then
        return 0
      fi
    done
    return 1
  fi
  if [[ "$CLEANUP_ONLY_EXTENSIONS" != "true" || ${#CLEANUP_FILE_EXTENSIONS[@]} -eq 0 ]]; then
    return 0
  fi
  local filename=$(basename "$file")
  for ext in "${CLEANUP_FILE_EXTENSIONS[@]}"; do
    if [[ "$filename" == *"$ext" ]]; then
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

SelectDirectoriesInteractive() {
  local available_dirs=("$@")
  local selected_dirs=()
  local idx=1
  QuietLogInfo "Available directories:" >&2
  for dir in "${available_dirs[@]}"; do
    printf "%2d. %s\n" "$idx" "$dir" >&2
    ((idx++))
  done
  read -p "Enter directory numbers to clean (comma-separated, or 'all'): " -r selection
  if [[ "$selection" == "all" ]]; then
    selected_dirs=("${available_dirs[@]}")
  else
    IFS=',' read -ra indices <<< "$selection"
    for i in "${indices[@]}"; do
      i="${i#"${i%%[![:space:]]*}"}"
      i="${i%"${i##*[![:space:]]}"}"
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
  local dir_extensions="${3:-}"
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
  local current=0
  local cleaned_size=0
  local cleaned_files=0
  local failed_files=0
  while IFS= read -r -d '' item; do
    ((current++))
    if ShouldExclude "$item"; then
      continue
    fi
    if ! ShouldCleanByExtension "$item" "$dir_extensions"; then
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
  if ! ShouldCleanByExtension "$file_path" ""; then
    QuietLogInfo "Skipped (not matching extension filter): $file_path"
    return 0
  fi
  if [[ "$MIN_AGE_DAYS" -gt 0 ]]; then
    if ! CheckFileAge "$file_path" "$MIN_AGE_DAYS" "days"; then
      QuietLogInfo "Skipped (too new): $file_path"
      return 0
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
  declare -A macos_dirs=(
    ["$HOME/Downloads"]="Downloaded files|"
    ["$HOME/Desktop"]="Desktop files|*.png,*.jpg,*.jpeg,*.gif,*.webp,*.heic"
    ["$HOME/Movies"]="Movie files|"
    ["$HOME/Music"]="Music files|"
    ["$HOME/Library/Application Support/obs-studio/logs"]="OBS Studio logs|"
    ["$HOME/Library/Application Support/obs-studio/profiler_data"]="OBS Studio profiler data|"
    ["$HOME/Library/Caches"]="Application caches|"
    ["$HOME/Library/Logs"]="Application logs|"
    ["$HOME/.Trash"]="Trash|"
    ["/tmp"]="Temporary files|"
  )
  local dirs_to_clean=()
  if [[ "$INTERACTIVE" == "true" ]]; then
    for dir_path in "${!macos_dirs[@]}"; do
      if [[ -d "$dir_path" ]]; then
        IFS='|' read -r description extensions <<< "${macos_dirs[$dir_path]}"
        dirs_to_clean+=("$dir_path|$description|$extensions")
      fi
    done
    readarray -t selected < <(SelectDirectoriesInteractive "${dirs_to_clean[@]}")
    for entry in "${selected[@]}"; do
      IFS='|' read -r dir_path description extensions <<< "$entry"
      DeleteDirectoryContents "$dir_path" "$description" "$extensions"
    done
  else
    for dir_path in "${!macos_dirs[@]}"; do
      if [[ -d "$dir_path" ]]; then
        IFS='|' read -r description extensions <<< "${macos_dirs[$dir_path]}"
        DeleteDirectoryContents "$dir_path" "$description" "$extensions"
      fi
    done
  fi
}

CleanupWindows() {
  declare -A windows_dirs=(
    ["$HOME/Downloads"]="Downloaded files|"
    ["$HOME/Videos"]="Video files|"
    ["$HOME/Music"]="Music files|"
    ["$HOME/Pictures/Screenshots"]="Screenshot files|*.png,*.jpg,*.jpeg,*.gif,*.webp,*.bmp"
    ["$HOME/scoop/apps/obs-studio/current/config/obs-studio/logs"]="Log files|"
    ["$HOME/scoop/apps/obs-studio/current/config/obs-studio/profiler_data"]="Profile data files|"
    ["$HOME/AppData/Local/Temp"]="Temporary files|"
    ["$TEMP"]="System temporary files|"
  )
  local dirs_to_clean=()
  if [[ "$INTERACTIVE" == "true" ]]; then
    for dir_path in "${!windows_dirs[@]}"; do
      if [[ -d "$dir_path" ]]; then
        IFS='|' read -r description extensions <<< "${windows_dirs[$dir_path]}"
        dirs_to_clean+=("$dir_path|$description|$extensions")
      fi
    done
    readarray -t selected < <(SelectDirectoriesInteractive "${dirs_to_clean[@]}")
    for entry in "${selected[@]}"; do
      IFS='|' read -r dir_path description extensions <<< "$entry"
      DeleteDirectoryContents "$dir_path" "$description" "$extensions"
    done
  else
    for dir_path in "${!windows_dirs[@]}"; do
      if [[ -d "$dir_path" ]]; then
        IFS='|' read -r description extensions <<< "${windows_dirs[$dir_path]}"
        DeleteDirectoryContents "$dir_path" "$description" "$extensions"
      fi
    done
  fi
}

CleanupLinux() {
  declare -A linux_dirs=(
    ["$HOME/Downloads"]="Downloaded files|"
    ["$HOME/Pictures/Screenshots"]="Screenshot files|*.png,*.jpg,*.jpeg,*.gif,*.webp,*.bmp"
    ["$HOME/.config/obs-studio/logs"]="OBS Studio logs|"
    ["$HOME/.config/obs-studio/profiler_data"]="OBS Studio profiler data|"
    ["$HOME/.cache"]="User cache|"
    ["/tmp"]="Temporary files|"
    ["/var/tmp"]="Variable temporary files|"
  )
  local dirs_to_clean=()
  if [[ "$INTERACTIVE" == "true" ]]; then
    for dir_path in "${!linux_dirs[@]}"; do
      if [[ -d "$dir_path" ]]; then
        IFS='|' read -r description extensions <<< "${linux_dirs[$dir_path]}"
        dirs_to_clean+=("$dir_path|$description|$extensions")
      fi
    done
    readarray -t selected < <(SelectDirectoriesInteractive "${dirs_to_clean[@]}")
    for entry in "${selected[@]}"; do
      IFS='|' read -r dir_path description extensions <<< "$entry"
      DeleteDirectoryContents "$dir_path" "$description" "$extensions"
    done
  else
    for dir_path in "${!linux_dirs[@]}"; do
      if [[ -d "$dir_path" ]]; then
        IFS='|' read -r description extensions <<< "${linux_dirs[$dir_path]}"
        DeleteDirectoryContents "$dir_path" "$description" "$extensions"
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

Main() {
  ParseArguments "$@"
  if ! ValidateSystemEnvironment; then
    exit 1
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
  if [[ "$MIN_AGE_DAYS" -gt 0 && "$QUIET_MODE" != "true" ]]; then
    LogInfo "Minimum file age: $MIN_AGE_DAYS days"
  fi
  if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 && "$QUIET_MODE" != "true" ]]; then
    LogInfo "Exclude patterns: ${EXCLUDE_PATTERNS[*]}"
  fi
  if [[ ${#CLEANUP_FILE_EXTENSIONS[@]} -gt 0 && "$QUIET_MODE" != "true" ]]; then
    LogInfo "File extensions filter: ${CLEANUP_FILE_EXTENSIONS[*]}"
  fi
  case "${SYSTEM_OS_TYPE}" in
    "Darwin")
      CleanupMacOS
      ;;
    "Linux")
      CleanupLinux
      ;;
    MINGW*|MSYS*|CYGWIN*)
      CleanupWindows
      ;;
  esac
  if [[ "$QUIET_MODE" != "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      LogInfo "Mode: DRY RUN (no changes made)"
    else
      LogInfo "Mode: FORCE (changes applied)"
      LogKeyValue "Files cleaned" "$TOTAL_FILES_CLEANED"
      LogKeyValue "Space freed" "$(FormatBytes $TOTAL_SIZE_CLEANED 2)"
    fi
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
