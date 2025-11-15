#!/usr/bin/env bash

readonly DEFAULT_HASH_METHOD="md5"
readonly DEFAULT_BACKUP_COMPRESS="false"
readonly DEFAULT_MIN_SIZE=0
readonly DEFAULT_MAX_SIZE=0
readonly DEFAULT_MIN_AGE_DAYS=0

readonly ERR_INVALID_PATH=1
readonly ERR_PATH_NOT_FOUND=2
readonly ERR_INVALID_PARAM=3
readonly ERR_OPERATION_FAILED=4
readonly ERR_PERMISSION_DENIED=5

_ValidateDirectory() {
  local path="$1"
  if [[ -z "$path" ]]; then
    echo "Error: Path parameter is required" >&2
    return $ERR_INVALID_PARAM
  fi
  if [[ ! -e "$path" ]]; then
    echo "Error: Path does not exist: $path" >&2
    return $ERR_PATH_NOT_FOUND
  fi
  if [[ ! -d "$path" ]]; then
    echo "Error: Path is not a directory: $path" >&2
    return $ERR_INVALID_PATH
  fi
  if [[ ! -r "$path" ]]; then
    echo "Error: Permission denied: $path" >&2
    return $ERR_PERMISSION_DENIED
  fi
  return 0
}

_ValidateFile() {
  local path="$1"
  if [[ -z "$path" ]]; then
    echo "Error: Path parameter is required" >&2
    return $ERR_INVALID_PARAM
  fi
  if [[ ! -e "$path" ]]; then
    echo "Error: File does not exist: $path" >&2
    return $ERR_PATH_NOT_FOUND
  fi
  if [[ ! -f "$path" ]]; then
    echo "Error: Path is not a file: $path" >&2
    return $ERR_INVALID_PATH
  fi
  if [[ ! -r "$path" ]]; then
    echo "Error: Permission denied: $path" >&2
    return $ERR_PERMISSION_DENIED
  fi
  return 0
}

GetDirectorySize() {
  local dir_path="$1"
  local human_readable="${2:-true}"
  _ValidateDirectory "$dir_path" || return $?
  local size_output
  if [[ "$human_readable" == "true" ]]; then
    size_output=$(du -sh "$dir_path" 2>/dev/null | cut -f1)
  else
    size_output=$(du -sb "$dir_path" 2>/dev/null | cut -f1)
  fi
  if [[ -z "$size_output" ]]; then
    echo "0B"
    return $ERR_OPERATION_FAILED
  fi
  echo "$size_output"
  return 0
}

CountFiles() {
  local dir_path="$1"
  local max_depth="${2:-}"
  _ValidateDirectory "$dir_path" || {
    echo "0"
    return $?
  }
  local find_cmd="find \"$dir_path\" -type f"
  if [[ -n "$max_depth" ]]; then
    find_cmd="$find_cmd -maxdepth $max_depth"
  fi
  local count=$(eval "$find_cmd" 2>/dev/null | wc -l | tr -d ' ')
  echo "${count:-0}"
  return 0
}

CountDirectories() {
  local dir_path="$1"
  local max_depth="${2:-}"
  local exclude_self="${3:-true}"
  _ValidateDirectory "$dir_path" || {
    echo "0"
    return $?
  }
  local find_cmd="find \"$dir_path\" -type d"
  if [[ -n "$max_depth" ]]; then
    find_cmd="$find_cmd -maxdepth $max_depth"
  fi
  local count=$(eval "$find_cmd" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$exclude_self" == "true" && "$count" -gt 0 ]]; then
    count=$((count - 1))
  fi
  echo "${count:-0}"
  return 0
}

GetFileSize() {
  local file_path="$1"
  local human_readable="${2:-false}"
  _ValidateFile "$file_path" || {
    echo "0"
    return $?
  }
  local size=$(stat -c %s "$file_path" 2>/dev/null || stat -f %z "$file_path" 2>/dev/null || echo "0")
  if [[ -z "$size" ]]; then
    echo "0"
    return $ERR_OPERATION_FAILED
  fi
  if [[ "$human_readable" == "true" ]]; then
    if command -v numfmt &> /dev/null; then
      size=$(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size}B")
    else
      if [[ "$size" -lt 1024 ]]; then
        size="${size}B"
      elif [[ "$size" -lt 1048576 ]]; then
        size="$((size / 1024))KB"
      elif [[ "$size" -lt 1073741824 ]]; then
        size="$((size / 1048576))MB"
      else
        size="$((size / 1073741824))GB"
      fi
    fi
  fi
  echo "$size"
  return 0
}

GetFileMD5() {
  local file_path="$1"
  _ValidateFile "$file_path" || {
    echo ""
    return $?
  }
  local hash=""
  if command -v md5sum &> /dev/null; then
    hash=$(md5sum "$file_path" 2>/dev/null | cut -d' ' -f1)
  elif command -v md5 &> /dev/null; then
    hash=$(md5 -q "$file_path" 2>/dev/null)
  else
    echo "Error: No MD5 utility found (md5sum or md5)" >&2
    return $ERR_OPERATION_FAILED
  fi
  echo "$hash"
  return 0
}

GetFileSHA256() {
  local file_path="$1"
  _ValidateFile "$file_path" || {
    echo ""
    return $?
  }
  local hash=""
  if command -v sha256sum &> /dev/null; then
    hash=$(sha256sum "$file_path" 2>/dev/null | cut -d' ' -f1)
  elif command -v shasum &> /dev/null; then
    hash=$(shasum -a 256 "$file_path" 2>/dev/null | cut -d' ' -f1)
  else
    echo "Error: No SHA256 utility found (sha256sum or shasum)" >&2
    return $ERR_OPERATION_FAILED
  fi
  echo "$hash"
  return 0
}

GetFileAge() {
  local file_path="$1"
  local unit="${2:-days}"
  _ValidateFile "$file_path" || {
    echo "0"
    return $?
  }
  local file_time=$(stat -c %Y "$file_path" 2>/dev/null || stat -f %m "$file_path" 2>/dev/null)
  if [[ -z "$file_time" ]]; then
    echo "0"
    return $ERR_OPERATION_FAILED
  fi
  local current_time=$(date +%s)
  if [[ -z "$current_time" ]]; then
    echo "0"
    return $ERR_OPERATION_FAILED
  fi
  local age_seconds=$((current_time - file_time))
  local result=0
  case "$unit" in
    seconds)
      result=$age_seconds
      ;;
    minutes)
      result=$((age_seconds / 60))
      ;;
    hours)
      result=$((age_seconds / 3600))
      ;;
    days)
      result=$((age_seconds / 86400))
      ;;
    *)
      echo "Error: Invalid unit '$unit'. Use: seconds, minutes, hours, days" >&2
      return $ERR_INVALID_PARAM
      ;;
  esac
  echo "$result"
  return 0
}

GetTrashPath() {
  local custom_path="${1:-}"
  if [[ -n "$custom_path" ]]; then
    echo "$custom_path"
    return 0
  fi
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "$HOME/.Trash"
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "$HOME/AppData/Local/Temp/RecycleBin"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "$HOME/.local/share/Trash/files"
  else
    echo "Error: Unsupported operating system: $OSTYPE" >&2
    return $ERR_OPERATION_FAILED
  fi
  return 0
}

MoveToTrash() {
  local source_path="$1"
  local custom_trash_path="${2:-}"
  local add_timestamp="${3:-true}"
  if [[ -z "$source_path" ]]; then
    echo "Error: Source path parameter is required" >&2
    return $ERR_INVALID_PARAM
  fi
  if [[ ! -e "$source_path" ]]; then
    echo "Error: Source path does not exist: $source_path" >&2
    return $ERR_PATH_NOT_FOUND
  fi
  local trash_path=$(GetTrashPath "$custom_trash_path")
  if [[ -z "$trash_path" ]]; then
    echo "Error: Could not determine trash path" >&2
    return $ERR_OPERATION_FAILED
  fi
  mkdir -p "$trash_path" 2>/dev/null
  if [[ ! -d "$trash_path" ]]; then
    echo "Error: Failed to create trash directory: $trash_path" >&2
    return $ERR_OPERATION_FAILED
  fi
  local item_name=$(basename "$source_path")
  local dest_name="$item_name"
  if [[ "$add_timestamp" == "true" ]]; then
    local timestamp=$(date +%Y%m%d_%H%M%S)
    dest_name="${item_name}_${timestamp}"
  fi
  local dest_path="$trash_path/$dest_name"
  if ! mv "$source_path" "$dest_path" 2>/dev/null; then
    echo "Error: Failed to move to trash: $source_path" >&2
    return $ERR_OPERATION_FAILED
  fi
  return 0
}

CreateBackup() {
  local source_path="$1"
  local backup_dir="$2"
  local compress="${3:-$DEFAULT_BACKUP_COMPRESS}"
  local timestamp_format="${4:-%Y%m%d_%H%M%S}"
  local keep_structure="${5:-true}"
  if [[ -z "$source_path" ]]; then
    echo "Error: Source path parameter is required" >&2
    return $ERR_INVALID_PARAM
  fi
  if [[ -z "$backup_dir" ]]; then
    echo "Error: Backup directory parameter is required" >&2
    return $ERR_INVALID_PARAM
  fi
  if [[ ! -e "$source_path" ]]; then
    echo "Error: Source path does not exist: $source_path" >&2
    return $ERR_PATH_NOT_FOUND
  fi
  local timestamp=$(date +"$timestamp_format")
  local backup_subdir="$backup_dir"
  if [[ "$keep_structure" == "true" ]]; then
    backup_subdir="$backup_dir/$timestamp"
  fi
  mkdir -p "$backup_subdir" 2>/dev/null
  if [[ ! -d "$backup_subdir" ]]; then
    echo "Error: Failed to create backup directory: $backup_subdir" >&2
    return $ERR_OPERATION_FAILED
  fi
  local item_name=$(basename "$source_path")
  if [[ "$compress" == "true" ]]; then
    if ! command -v tar &> /dev/null; then
      echo "Error: tar command not found" >&2
      return $ERR_OPERATION_FAILED
    fi
    local archive_path="$backup_subdir/${item_name}_${timestamp}.tar.gz"
    if ! tar -czf "$archive_path" -C "$(dirname "$source_path")" "$(basename "$source_path")" 2>/dev/null; then
      echo "Error: Failed to create compressed backup: $archive_path" >&2
      return $ERR_OPERATION_FAILED
    fi
    echo "$archive_path"
  else
    local backup_path="$backup_subdir/$item_name"
    if [[ -d "$source_path" ]]; then
      if ! cp -r "$source_path" "$backup_path" 2>/dev/null; then
        echo "Error: Failed to backup directory: $source_path" >&2
        return $ERR_OPERATION_FAILED
      fi
    else
      if ! cp "$source_path" "$backup_path" 2>/dev/null; then
        echo "Error: Failed to backup file: $source_path" >&2
        return $ERR_OPERATION_FAILED
      fi
    fi
    echo "$backup_path"
  fi
  return 0
}

FindDuplicates() {
  local dir_path="$1"
  local hash_method="${2:-$DEFAULT_HASH_METHOD}"
  local output_format="${3:-list}"
  local min_size="${4:-0}"
  _ValidateDirectory "$dir_path" || return $?
  if [[ "$hash_method" != "md5" && "$hash_method" != "sha256" ]]; then
    echo "Error: Invalid hash method '$hash_method'. Use: md5, sha256" >&2
    return $ERR_INVALID_PARAM
  fi
  declare -A file_hashes
  local duplicates=()
  while IFS= read -r -d '' file; do
    if [[ "$min_size" -gt 0 ]]; then
      local file_size=$(GetFileSize "$file")
      if [[ "$file_size" -lt "$min_size" ]]; then
        continue
      fi
    fi
    local hash=""
    if [[ "$hash_method" == "sha256" ]]; then
      hash=$(GetFileSHA256 "$file")
    else
      hash=$(GetFileMD5 "$file")
    fi
    if [[ -n "$hash" ]]; then
      if [[ -n "${file_hashes[$hash]}" ]]; then
        if [[ "$output_format" == "grouped" ]]; then
          duplicates+=("${file_hashes[$hash]}|$file")
        else
          duplicates+=("$file")
        fi
      else
        file_hashes[$hash]="$file"
      fi
    fi
  done < <(find "$dir_path" -type f -print0 2>/dev/null)
  if [[ "${#duplicates[@]}" -eq 0 ]]; then
    return 0
  fi
  printf '%s\n' "${duplicates[@]}"
  return 0
}

CheckFilePattern() {
  local file_path="$1"
  local pattern="$2"
  local case_sensitive="${3:-true}"
  if [[ -z "$file_path" || -z "$pattern" ]]; then
    echo "Error: file_path and pattern parameters are required" >&2
    return $ERR_INVALID_PARAM
  fi
  local file_name=$(basename "$file_path")
  if [[ "$pattern" == "*" ]]; then
    return 0
  fi
  if [[ "$case_sensitive" == "false" ]]; then
    shopt -s nocasematch
  fi
  if [[ "$file_name" == $pattern ]]; then
    [[ "$case_sensitive" == "false" ]] && shopt -u nocasematch
    return 0
  fi
  [[ "$case_sensitive" == "false" ]] && shopt -u nocasematch
  return 1
}

CheckFileSize() {
  local file_path="$1"
  local min_size="${2:-$DEFAULT_MIN_SIZE}"
  local max_size="${3:-$DEFAULT_MAX_SIZE}"
  _ValidateFile "$file_path" || return $?
  local file_size=$(GetFileSize "$file_path")
  if [[ "$min_size" -gt 0 && "$file_size" -lt "$min_size" ]]; then
    return 1
  fi
  if [[ "$max_size" -gt 0 && "$file_size" -gt "$max_size" ]]; then
    return 1
  fi
  return 0
}

CheckFileAge() {
  local file_path="$1"
  local min_age="${2:-$DEFAULT_MIN_AGE_DAYS}"
  local unit="${3:-days}"
  _ValidateFile "$file_path" || return $?
  local file_age=$(GetFileAge "$file_path" "$unit")
  if [[ "$min_age" -gt 0 && "$file_age" -lt "$min_age" ]]; then
    return 1
  fi
  return 0
}

GetFileExtension() {
  local file_path="$1"
  if [[ -z "$file_path" ]]; then
    echo "Error: file_path parameter is required" >&2
    return $ERR_INVALID_PARAM
  fi
  local filename=$(basename "$file_path")
  local extension="${filename##*.}"
  if [[ "$extension" == "$filename" ]]; then
    echo ""
  else
    echo "$extension"
  fi
  return 0
}

GetFileBasename() {
  local file_path="$1"
  if [[ -z "$file_path" ]]; then
    echo "Error: file_path parameter is required" >&2
    return $ERR_INVALID_PARAM
  fi
  local filename=$(basename "$file_path")
  echo "${filename%.*}"
  return 0
}

CompareFiles() {
  local file1="$1"
  local file2="$2"
  local method="${3:-hash}"
  _ValidateFile "$file1" || return $?
  _ValidateFile "$file2" || return $?
  case "$method" in
    hash)
      local hash1=$(GetFileMD5 "$file1")
      local hash2=$(GetFileMD5 "$file2")
      [[ "$hash1" == "$hash2" ]] && return 0 || return 1
      ;;
    content)
      diff -q "$file1" "$file2" &>/dev/null && return 0 || return 1
      ;;
    size)
      local size1=$(GetFileSize "$file1")
      local size2=$(GetFileSize "$file2")
      [[ "$size1" == "$size2" ]] && return 0 || return 1
      ;;
    *)
      echo "Error: Invalid method '$method'. Use: hash, content, size" >&2
      return $ERR_INVALID_PARAM
      ;;
  esac
}

FindFilesByExtension() {
  local dir_path="$1"
  local extension="$2"
  local max_depth="${3:-}"
  _ValidateDirectory "$dir_path" || return $?
  if [[ -z "$extension" ]]; then
    echo "Error: extension parameter is required" >&2
    return $ERR_INVALID_PARAM
  fi
  local find_cmd="find \"$dir_path\" -type f -name \"*.$extension\""
  if [[ -n "$max_depth" ]]; then
    find_cmd="$find_cmd -maxdepth $max_depth"
  fi
  eval "$find_cmd" 2>/dev/null
  return 0
}

FindEmpty() {
  local dir_path="$1"
  local type="${2:-both}"
  _ValidateDirectory "$dir_path" || return $?
  case "$type" in
    files)
      find "$dir_path" -type f -empty 2>/dev/null
      ;;
    dirs)
      find "$dir_path" -type d -empty 2>/dev/null
      ;;
    both)
      find "$dir_path" \( -type f -o -type d \) -empty 2>/dev/null
      ;;
    *)
      echo "Error: Invalid type '$type'. Use: files, dirs, both" >&2
      return $ERR_INVALID_PARAM
      ;;
  esac
  return 0
}

GetDirectoryTree() {
  local dir_path="$1"
  local max_depth="${2:-3}"
  local show_hidden="${3:-false}"
  _ValidateDirectory "$dir_path" || return $?
  if command -v tree &> /dev/null; then
    local tree_cmd="tree -L $max_depth"
    [[ "$show_hidden" == "true" ]] && tree_cmd="$tree_cmd -a"
    eval "$tree_cmd \"$dir_path\"" 2>/dev/null
  else
    local find_cmd="find \"$dir_path\" -maxdepth $max_depth"
    [[ "$show_hidden" == "false" ]] && find_cmd="$find_cmd -not -path '*/.*'"
    eval "$find_cmd" 2>/dev/null | sort
  fi
  return 0
}

CleanOldFiles() {
  local dir_path="$1"
  local min_age_days="$2"
  local pattern="${3:-*}"
  local dry_run="${4:-true}"
  _ValidateDirectory "$dir_path" || return $?
  if [[ -z "$min_age_days" ]]; then
    echo "Error: min_age_days parameter is required" >&2
    return $ERR_INVALID_PARAM
  fi
  local count=0
  while IFS= read -r -d '' file; do
    if CheckFileAge "$file" "$min_age_days" "days"; then
      if CheckFilePattern "$file" "$pattern"; then
        if [[ "$dry_run" == "true" ]]; then
          echo "Would delete: $file"
        else
          if rm "$file" 2>/dev/null; then
            echo "Deleted: $file"
          else
            echo "Failed to delete: $file" >&2
          fi
        fi
        ((count++))
      fi
    fi
  done < <(find "$dir_path" -type f -print0 2>/dev/null)
  echo "Total files processed: $count"
  return 0
}

# Helper functions (private)
export -f _ValidateDirectory
export -f _ValidateFile

# Directory operations
export -f GetDirectorySize
export -f CountFiles
export -f CountDirectories

# File operations
export -f GetFileSize
export -f GetFileMD5
export -f GetFileSHA256
export -f GetFileAge

# Trash & backup operations
export -f GetTrashPath
export -f MoveToTrash
export -f CreateBackup

# Advanced operations
export -f FindDuplicates

# Validation functions
export -f CheckFilePattern
export -f CheckFileSize
export -f CheckFileAge

# Additional utilities
export -f GetFileExtension
export -f GetFileBasename
export -f CompareFiles
export -f FindFilesByExtension
export -f FindEmpty
export -f GetDirectoryTree
export -f CleanOldFiles