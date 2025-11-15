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

_IsNonNegativeInteger() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

_GetUniquePath() {
  local requested_path="${1:-}"
  local candidate_path="$requested_path"
  local suffix=1
  while [[ -e "$candidate_path" || -L "$candidate_path" ]]; do
    candidate_path="${requested_path}_${suffix}"
    suffix=$((suffix + 1))
  done
  printf '%s\n' "$candidate_path"
}

_ValidateDirectory() {
  local path="${1:-}"
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
  local path="${1:-}"
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
  local dir_path="${1:-}"
  local human_readable="${2:-true}"
  _ValidateDirectory "$dir_path" || return $?
  local size_output du_output
  if [[ "$human_readable" == "true" ]]; then
    if ! du_output=$(du -sh -- "$dir_path" 2>/dev/null); then
      echo "0B"
      return $ERR_OPERATION_FAILED
    fi
    size_output=$(printf '%s\n' "$du_output" | cut -f1)
  else
    if du_output=$(du -sb -- "$dir_path" 2>/dev/null); then
      size_output=$(printf '%s\n' "$du_output" | cut -f1)
    else
      if ! du_output=$(du -sk -- "$dir_path" 2>/dev/null); then
        echo "0"
        return $ERR_OPERATION_FAILED
      fi
      local size_kib="${du_output%%$'\t'*}"
      if [[ "$size_kib" == "$du_output" ]]; then
        size_kib="${du_output%% *}"
      fi
      if ! _IsNonNegativeInteger "$size_kib"; then
        echo "0"
        return $ERR_OPERATION_FAILED
      fi
      size_output=$((10#$size_kib * 1024))
    fi
    if ! _IsNonNegativeInteger "$size_output"; then
      echo "0"
      return $ERR_OPERATION_FAILED
    fi
  fi
  if [[ -z "$size_output" ]]; then
    echo "0B"
    return $ERR_OPERATION_FAILED
  fi
  echo "$size_output"
  return 0
}

CountFiles() {
  local dir_path="${1:-}"
  local max_depth="${2:-}"
  local validation_status
  if _ValidateDirectory "$dir_path"; then
    :
  else
    validation_status=$?
    return "$validation_status"
  fi
  local find_args=("$dir_path")
  if [[ -n "$max_depth" ]]; then
    if ! _IsNonNegativeInteger "$max_depth"; then
      echo "Error: max_depth must be a non-negative integer" >&2
      echo "0"
      return $ERR_INVALID_PARAM
    fi
    max_depth=$((10#$max_depth))
    find_args+=("-maxdepth" "$max_depth")
  fi
  find_args+=("-type" "f")
  local pipefail_state
  pipefail_state=$(set -o pipefail)
  set -o pipefail
  local count
  if ! count=$(find "${find_args[@]}" -print0 2>/dev/null | tr -cd '\0' | wc -c); then
    [[ "$pipefail_state" == *'off'* ]] && set +o pipefail
    echo "0"
    return $ERR_OPERATION_FAILED
  fi
  [[ "$pipefail_state" == *'off'* ]] && set +o pipefail
  count="${count//[[:space:]]/}"
  echo "$count"
  return 0
}

CountDirectories() {
  local dir_path="${1:-}"
  local max_depth="${2:-}"
  local exclude_self="${3:-true}"
  local validation_status
  if _ValidateDirectory "$dir_path"; then
    :
  else
    validation_status=$?
    echo "0"
    return "$validation_status"
  fi
  local find_args=("$dir_path")
  if [[ -n "$max_depth" ]]; then
    if ! _IsNonNegativeInteger "$max_depth"; then
      echo "Error: max_depth must be a non-negative integer" >&2
      echo "0"
      return $ERR_INVALID_PARAM
    fi
    max_depth=$((10#$max_depth))
    find_args+=("-maxdepth" "$max_depth")
  fi
  find_args+=("-type" "d")
  local pipefail_state
  pipefail_state=$(set -o pipefail)
  set -o pipefail
  local count
  if ! count=$(find "${find_args[@]}" -print0 2>/dev/null | tr -cd '\0' | wc -c); then
    [[ "$pipefail_state" == *'off'* ]] && set +o pipefail
    echo "0"
    return $ERR_OPERATION_FAILED
  fi
  [[ "$pipefail_state" == *'off'* ]] && set +o pipefail
  count="${count//[[:space:]]/}"
  if [[ "$exclude_self" == "true" && "$count" -gt 0 ]]; then
    count=$((count - 1))
  fi
  echo "${count:-0}"
  return 0
}

GetFileSize() {
  local file_path="${1:-}"
  local human_readable="${2:-false}"
  local validation_status
  if _ValidateFile "$file_path"; then
    :
  else
    validation_status=$?
    return "$validation_status"
  fi
  local size
  if size=$(stat -c %s -- "$file_path" 2>/dev/null); then
    :
  elif size=$(stat -f %z -- "$file_path" 2>/dev/null); then
    :
  else
    return $ERR_OPERATION_FAILED
  fi
  if [[ -z "$size" ]]; then
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
  local file_path="${1:-}"
  local validation_status
  if _ValidateFile "$file_path"; then
    :
  else
    validation_status=$?
    echo ""
    return "$validation_status"
  fi
  local hash=""
  if command -v md5sum &> /dev/null; then
    local hash_output
    if ! hash_output=$(md5sum -- "$file_path" 2>/dev/null); then
      echo "Error: Failed to calculate MD5 hash" >&2
      return $ERR_OPERATION_FAILED
    fi
    hash="${hash_output%% *}"
  elif command -v md5 &> /dev/null; then
    if ! hash=$(md5 -q -- "$file_path" 2>/dev/null); then
      echo "Error: Failed to calculate MD5 hash" >&2
      return $ERR_OPERATION_FAILED
    fi
  else
    echo "Error: No MD5 utility found (md5sum or md5)" >&2
    return $ERR_OPERATION_FAILED
  fi
  if [[ -z "$hash" ]]; then
    echo "Error: Failed to calculate MD5 hash" >&2
    return $ERR_OPERATION_FAILED
  fi
  echo "$hash"
  return 0
}

GetFileSHA256() {
  local file_path="${1:-}"
  local validation_status
  if _ValidateFile "$file_path"; then
    :
  else
    validation_status=$?
    echo ""
    return "$validation_status"
  fi
  local hash=""
  if command -v sha256sum &> /dev/null; then
    local hash_output
    if ! hash_output=$(sha256sum -- "$file_path" 2>/dev/null); then
      echo "Error: Failed to calculate SHA256 hash" >&2
      return $ERR_OPERATION_FAILED
    fi
    hash="${hash_output%% *}"
  elif command -v shasum &> /dev/null; then
    if ! hash=$(shasum -a 256 -- "$file_path" 2>/dev/null); then
      echo "Error: Failed to calculate SHA256 hash" >&2
      return $ERR_OPERATION_FAILED
    fi
    hash="${hash%% *}"
  else
    echo "Error: No SHA256 utility found (sha256sum or shasum)" >&2
    return $ERR_OPERATION_FAILED
  fi
  if [[ -z "$hash" ]]; then
    echo "Error: Failed to calculate SHA256 hash" >&2
    return $ERR_OPERATION_FAILED
  fi
  echo "$hash"
  return 0
}

GetFileAge() {
  local file_path="${1:-}"
  local unit="${2:-days}"
  local validation_status
  if _ValidateFile "$file_path"; then
    :
  else
    validation_status=$?
    echo "0"
    return "$validation_status"
  fi
  local file_time
  if file_time=$(stat -c %Y -- "$file_path" 2>/dev/null); then
    :
  elif file_time=$(stat -f %m -- "$file_path" 2>/dev/null); then
    :
  else
    echo "0"
    return $ERR_OPERATION_FAILED
  fi
  if [[ -z "$file_time" ]]; then
    echo "0"
    return $ERR_OPERATION_FAILED
  fi
  local current_time
  if ! current_time=$(date +%s); then
    echo "0"
    return $ERR_OPERATION_FAILED
  fi
  if [[ -z "$current_time" ]]; then
    echo "0"
    return $ERR_OPERATION_FAILED
  fi
  local age_seconds=$((current_time - file_time))
  if [[ "$age_seconds" -lt 0 ]]; then
    age_seconds=0
  fi
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
  local operating_system="${OSTYPE:-}"
  local home_path="${HOME:-}"
  if [[ -z "$home_path" ]]; then
    echo "Error: HOME is not set" >&2
    return $ERR_OPERATION_FAILED
  fi
  if [[ "$operating_system" == "darwin"* ]]; then
    echo "$home_path/.Trash"
  elif [[ "$operating_system" == msys* || "$operating_system" == mingw* || "$operating_system" == cygwin* || "$operating_system" == "win32" ]]; then
    echo "$home_path/AppData/Local/Temp/RecycleBin"
  elif [[ "$operating_system" == "linux-gnu"* ]]; then
    echo "$home_path/.local/share/Trash/files"
  else
    echo "Error: Unsupported operating system: $operating_system" >&2
    return $ERR_OPERATION_FAILED
  fi
  return 0
}

MoveToTrash() {
  local source_path="${1:-}"
  local custom_trash_path="${2:-}"
  local add_timestamp="${3:-true}"
  if [[ -z "$source_path" ]]; then
    echo "Error: Source path parameter is required" >&2
    return $ERR_INVALID_PARAM
  fi
  if [[ ! -e "$source_path" && ! -L "$source_path" ]]; then
    echo "Error: Source path does not exist: $source_path" >&2
    return $ERR_PATH_NOT_FOUND
  fi
  local trash_path
  if ! trash_path=$(GetTrashPath "$custom_trash_path"); then
    echo "Error: Could not determine trash path" >&2
    return $ERR_OPERATION_FAILED
  fi
  if [[ -z "$trash_path" ]]; then
    echo "Error: Could not determine trash path" >&2
    return $ERR_OPERATION_FAILED
  fi
  mkdir -p "$trash_path" 2>/dev/null
  if [[ ! -d "$trash_path" ]]; then
    echo "Error: Failed to create trash directory: $trash_path" >&2
    return $ERR_OPERATION_FAILED
  fi
  local item_name=$(basename -- "$source_path")
  local dest_name="$item_name"
  if [[ "$add_timestamp" == "true" ]]; then
    local timestamp
    if ! timestamp=$(date +%Y%m%d_%H%M%S); then
      echo "Error: Failed to generate trash timestamp" >&2
      return $ERR_OPERATION_FAILED
    fi
    dest_name="${item_name}_${timestamp}"
  fi
  local dest_path
  dest_path=$(_GetUniquePath "$trash_path/$dest_name")
  if ! mv -- "$source_path" "$dest_path" 2>/dev/null; then
    echo "Error: Failed to move to trash: $source_path" >&2
    return $ERR_OPERATION_FAILED
  fi
  return 0
}

CreateBackup() {
  local source_path="${1:-}"
  local backup_dir="${2:-}"
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
  local timestamp
  if ! timestamp=$(date +"$timestamp_format"); then
    echo "Error: Failed to generate backup timestamp" >&2
    return $ERR_OPERATION_FAILED
  fi
  if [[ -z "$timestamp" ]]; then
    echo "Error: Backup timestamp is empty" >&2
    return $ERR_OPERATION_FAILED
  fi
  local backup_subdir="$backup_dir"
  if [[ "$keep_structure" == "true" ]]; then
    backup_subdir="$backup_dir/$timestamp"
    backup_subdir=$(_GetUniquePath "$backup_subdir")
  fi
  mkdir -p "$backup_subdir" 2>/dev/null
  if [[ ! -d "$backup_subdir" ]]; then
    echo "Error: Failed to create backup directory: $backup_subdir" >&2
    return $ERR_OPERATION_FAILED
  fi
  local item_name=$(basename -- "$source_path")
  if [[ "$compress" == "true" ]]; then
    if ! command -v tar &> /dev/null; then
      echo "Error: tar command not found" >&2
      return $ERR_OPERATION_FAILED
    fi
    local archive_path="$backup_subdir/${item_name}_${timestamp}.tar.gz"
    archive_path=$(_GetUniquePath "$archive_path")
    if ! tar -czf "$archive_path" -C "$(dirname -- "$source_path")" -- "$(basename -- "$source_path")" 2>/dev/null; then
      echo "Error: Failed to create compressed backup: $archive_path" >&2
      return $ERR_OPERATION_FAILED
    fi
    echo "$archive_path"
  else
    local backup_path="$backup_subdir/$item_name"
    backup_path=$(_GetUniquePath "$backup_path")
    if [[ -d "$source_path" ]]; then
      if ! cp -r -- "$source_path" "$backup_path" 2>/dev/null; then
        echo "Error: Failed to backup directory: $source_path" >&2
        return $ERR_OPERATION_FAILED
      fi
    else
      if ! cp -- "$source_path" "$backup_path" 2>/dev/null; then
        echo "Error: Failed to backup file: $source_path" >&2
        return $ERR_OPERATION_FAILED
      fi
    fi
    echo "$backup_path"
  fi
  return 0
}

FindDuplicates() {
  local dir_path="${1:-}"
  local hash_method="${2:-$DEFAULT_HASH_METHOD}"
  local output_format="${3:-list}"
  local min_size="${4:-0}"
  _ValidateDirectory "$dir_path" || return $?
  if [[ "$hash_method" != "md5" && "$hash_method" != "sha256" ]]; then
    echo "Error: Invalid hash method '$hash_method'. Use: md5, sha256" >&2
    return $ERR_INVALID_PARAM
  fi
  if [[ "$output_format" != "list" && "$output_format" != "grouped" ]]; then
    echo "Error: Invalid output format '$output_format'. Use: list, grouped" >&2
    return $ERR_INVALID_PARAM
  fi
  if ! _IsNonNegativeInteger "$min_size"; then
    echo "Error: min_size must be a non-negative integer" >&2
    return $ERR_INVALID_PARAM
  fi
  min_size=$((10#$min_size))
  if ! find "$dir_path" -type f -print0 >/dev/null 2>/dev/null; then
    echo "Error: Failed to enumerate files: $dir_path" >&2
    return $ERR_OPERATION_FAILED
  fi
  declare -A file_hashes
  local duplicates=()
  while IFS= read -r -d '' file; do
    if [[ "$min_size" -gt 0 ]]; then
      local file_size
      if ! file_size=$(GetFileSize "$file"); then
        echo "Error: Failed to read file size: $file" >&2
        return $ERR_OPERATION_FAILED
      fi
      if [[ "$file_size" -lt "$min_size" ]]; then
        continue
      fi
    fi
    local hash=""
    if [[ "$hash_method" == "sha256" ]]; then
      if ! hash=$(GetFileSHA256 "$file"); then
        echo "Error: Failed to hash file: $file" >&2
        return $ERR_OPERATION_FAILED
      fi
    else
      if ! hash=$(GetFileMD5 "$file"); then
        echo "Error: Failed to hash file: $file" >&2
        return $ERR_OPERATION_FAILED
      fi
    fi
    if [[ -n "$hash" ]]; then
      if [[ -n "${file_hashes[$hash]+set}" ]]; then
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
  local file_path="${1:-}"
  local pattern="${2:-}"
  local case_sensitive="${3:-true}"
  if [[ -z "$file_path" || -z "$pattern" ]]; then
    echo "Error: file_path and pattern parameters are required" >&2
    return $ERR_INVALID_PARAM
  fi
  local file_name=$(basename -- "$file_path")
  if [[ "$pattern" == "*" ]]; then
    return 0
  fi
  if [[ "$case_sensitive" == "false" ]]; then
    (shopt -s nocasematch; [[ "$file_name" == $pattern ]])
    return $?
  fi
  (shopt -u nocasematch; [[ "$file_name" == $pattern ]])
}

CheckFileSize() {
  local file_path="${1:-}"
  local min_size="${2:-$DEFAULT_MIN_SIZE}"
  local max_size="${3:-$DEFAULT_MAX_SIZE}"
  _ValidateFile "$file_path" || return $?
  if ! _IsNonNegativeInteger "$min_size" || ! _IsNonNegativeInteger "$max_size"; then
    echo "Error: min_size and max_size must be non-negative integers" >&2
    return $ERR_INVALID_PARAM
  fi
  min_size=$((10#$min_size))
  max_size=$((10#$max_size))
  if [[ "$max_size" -gt 0 && "$min_size" -gt "$max_size" ]]; then
    echo "Error: min_size cannot exceed max_size" >&2
    return $ERR_INVALID_PARAM
  fi
  local file_size
  if ! file_size=$(GetFileSize "$file_path"); then
    return $ERR_OPERATION_FAILED
  fi
  if [[ "$min_size" -gt 0 && "$file_size" -lt "$min_size" ]]; then
    return 1
  fi
  if [[ "$max_size" -gt 0 && "$file_size" -gt "$max_size" ]]; then
    return 1
  fi
  return 0
}

CheckFileAge() {
  local file_path="${1:-}"
  local min_age="${2:-$DEFAULT_MIN_AGE_DAYS}"
  local unit="${3:-days}"
  _ValidateFile "$file_path" || return $?
  if ! _IsNonNegativeInteger "$min_age"; then
    echo "Error: min_age must be a non-negative integer" >&2
    return $ERR_INVALID_PARAM
  fi
  min_age=$((10#$min_age))
  local file_age
  if ! file_age=$(GetFileAge "$file_path" "$unit"); then
    return $ERR_OPERATION_FAILED
  fi
  if [[ "$min_age" -gt 0 && "$file_age" -lt "$min_age" ]]; then
    return 1
  fi
  return 0
}

GetFileExtension() {
  local file_path="${1:-}"
  if [[ -z "$file_path" ]]; then
    echo "Error: file_path parameter is required" >&2
    return $ERR_INVALID_PARAM
  fi
  local filename=$(basename -- "$file_path")
  if [[ "$filename" == .* && "${filename:1}" != *.* ]]; then
    echo ""
    return 0
  fi
  local extension="${filename##*.}"
  if [[ "$extension" == "$filename" ]]; then
    echo ""
  else
    echo "$extension"
  fi
  return 0
}

GetFileBasename() {
  local file_path="${1:-}"
  if [[ -z "$file_path" ]]; then
    echo "Error: file_path parameter is required" >&2
    return $ERR_INVALID_PARAM
  fi
  local filename=$(basename -- "$file_path")
  if [[ "$filename" == .* && "${filename:1}" != *.* ]]; then
    echo "$filename"
    return 0
  fi
  echo "${filename%.*}"
  return 0
}

CompareFiles() {
  local file1="${1:-}"
  local file2="${2:-}"
  local method="${3:-hash}"
  _ValidateFile "$file1" || return $?
  _ValidateFile "$file2" || return $?
  case "$method" in
    hash)
      local hash1 hash2
      if ! hash1=$(GetFileMD5 "$file1") || ! hash2=$(GetFileMD5 "$file2"); then
        return $ERR_OPERATION_FAILED
      fi
      [[ "$hash1" == "$hash2" ]] && return 0 || return 1
      ;;
    content)
      if ! command -v cmp &>/dev/null; then
        echo "Error: cmp command not found" >&2
        return $ERR_OPERATION_FAILED
      fi
      cmp -s "$file1" "$file2"
      local compare_status=$?
      if [[ "$compare_status" -eq 0 ]]; then
        return 0
      elif [[ "$compare_status" -eq 1 ]]; then
        return 1
      fi
      return $ERR_OPERATION_FAILED
      ;;
    size)
      local size1 size2
      if ! size1=$(GetFileSize "$file1") || ! size2=$(GetFileSize "$file2"); then
        return $ERR_OPERATION_FAILED
      fi
      [[ "$size1" == "$size2" ]] && return 0 || return 1
      ;;
    *)
      echo "Error: Invalid method '$method'. Use: hash, content, size" >&2
      return $ERR_INVALID_PARAM
      ;;
  esac
}

FindFilesByExtension() {
  local dir_path="${1:-}"
  local extension="${2:-}"
  local max_depth="${3:-}"
  _ValidateDirectory "$dir_path" || return $?
  if [[ -z "$extension" ]]; then
    echo "Error: extension parameter is required" >&2
    return $ERR_INVALID_PARAM
  fi
  extension="${extension#.}"
  local find_args=("$dir_path")
  if [[ -n "$max_depth" ]]; then
    if [[ ! "$max_depth" =~ ^[0-9]+$ ]]; then
      echo "Error: max_depth must be a non-negative integer" >&2
      return $ERR_INVALID_PARAM
    fi
    max_depth=$((10#$max_depth))
    find_args+=("-maxdepth" "$max_depth")
  fi
  find_args+=("-type" "f" "-name" "*.$extension")
  if ! find "${find_args[@]}" 2>/dev/null; then
    return $ERR_OPERATION_FAILED
  fi
  return 0
}

FindEmpty() {
  local dir_path="${1:-}"
  local type="${2:-both}"
  _ValidateDirectory "$dir_path" || return $?
  case "$type" in
    files)
      find "$dir_path" -type f -empty 2>/dev/null || return $ERR_OPERATION_FAILED
      ;;
    dirs)
      find "$dir_path" -type d -empty 2>/dev/null || return $ERR_OPERATION_FAILED
      ;;
    both)
      find "$dir_path" \( -type f -o -type d \) -empty 2>/dev/null || return $ERR_OPERATION_FAILED
      ;;
    *)
      echo "Error: Invalid type '$type'. Use: files, dirs, both" >&2
      return $ERR_INVALID_PARAM
      ;;
  esac
  return 0
}

GetDirectoryTree() {
  local dir_path="${1:-}"
  local max_depth="${2:-3}"
  local show_hidden="${3:-false}"
  _ValidateDirectory "$dir_path" || return $?
  if [[ ! "$max_depth" =~ ^[0-9]+$ ]]; then
    echo "Error: max_depth must be a non-negative integer" >&2
    return $ERR_INVALID_PARAM
  fi
  max_depth=$((10#$max_depth))
  if command -v tree &> /dev/null; then
    local tree_args=("-L" "$max_depth")
    [[ "$show_hidden" == "true" ]] && tree_args+=("-a")
    if ! tree "${tree_args[@]}" "$dir_path" 2>/dev/null; then
      return $ERR_OPERATION_FAILED
    fi
  else
    local find_args=("$dir_path" "-maxdepth" "$max_depth")
    [[ "$show_hidden" == "false" ]] && find_args+=("-not" "-path" "*/.*")
    find "${find_args[@]}" 2>/dev/null | sort
    local find_status=${PIPESTATUS[0]}
    if [[ "$find_status" -ne 0 ]]; then
      return $ERR_OPERATION_FAILED
    fi
  fi
  return 0
}

CleanOldFiles() {
  local dir_path="${1:-}"
  local min_age_days="${2:-}"
  local pattern="${3:-*}"
  local dry_run="${4:-true}"
  _ValidateDirectory "$dir_path" || return $?
  if [[ -z "$min_age_days" ]]; then
    echo "Error: min_age_days parameter is required" >&2
    return $ERR_INVALID_PARAM
  fi
  if ! _IsNonNegativeInteger "$min_age_days"; then
    echo "Error: min_age_days must be a non-negative integer" >&2
    return $ERR_INVALID_PARAM
  fi
  min_age_days=$((10#$min_age_days))
  if ! find "$dir_path" -type f -print0 >/dev/null 2>/dev/null; then
    echo "Error: Failed to enumerate files: $dir_path" >&2
    return $ERR_OPERATION_FAILED
  fi
  local count=0
  while IFS= read -r -d '' file; do
    if CheckFileAge "$file" "$min_age_days" "days"; then
      if CheckFilePattern "$file" "$pattern"; then
        if [[ "$dry_run" == "true" ]]; then
          echo "Would delete: $file"
        else
          if rm -- "$file" 2>/dev/null; then
            echo "Deleted: $file"
          else
            echo "Failed to delete: $file" >&2
          fi
        fi
        count=$((count + 1))
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
