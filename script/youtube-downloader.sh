#!/usr/bin/env bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

source "$SCRIPT_DIR/utils/file.sh" 2>/dev/null || {
  echo "Error: Cannot load file.sh utility" >&2
  exit 1
}
source "$SCRIPT_DIR/utils/logger.sh" 2>/dev/null || {
  echo "Error: Cannot load logger.sh utility" >&2
  exit 1
}
source "$SCRIPT_DIR/utils/progress.sh" 2>/dev/null || {
  echo "Error: Cannot load progress.sh utility" >&2
  exit 1
}

declare YOUTUBE_INPUT=""
declare YOUTUBE_ID=""
declare DOWNLOAD_TYPE=""
declare YOUTUBE_DOWNLOAD_DIR=""
declare DOWNLOAD_PLAYLIST=false
declare VIDEO_FORMAT="best"
declare DOWNLOAD_SUBTITLE=false
declare SUBTITLE_LANG="en"
declare MAX_RETRIES=5
declare EMBED_METADATA=true
declare ORGANIZE_BY="date"
declare VERIFY_DOWNLOAD=false

CheckYoutubeDownloadCompatibility() {
  if [[ "$OSTYPE" != "darwin"* && "$OSTYPE" != "msys" && "$OSTYPE" != "linux-gnu"* ]]; then
    LogError "This youtube download script does not support the current OS: $OSTYPE"
    exit 1
  fi
  LogSuccess "OS compatibility check passed: $OSTYPE"
}

CheckYoutubeDownloadDependencies() {
  local required_commands="yt-dlp ffmpeg"
  local missing_commands=()
  LogInfo "Checking required dependencies..."
  for command in $required_commands; do
    if [[ ! -x "$(command -v "$command")" ]]; then
      missing_commands+=("$command")
      LogError "Missing dependency: $command"
    else
      LogSuccess "Found dependency: $command"
    fi
  done
  if [[ ${#missing_commands[@]} -gt 0 ]]; then
    LogError "Missing required dependencies: ${missing_commands[*]}"
    LogInfo "Please install missing dependencies and try again"
    exit 1
  fi
  LogSuccess "All dependencies are installed"
}

ValidateYoutubeUrl() {
  local youtube_input="$1"
  if [[ "$youtube_input" =~ ^(http(s)?:\/\/)?(www\.)?youtube\.com\/watch.* ]]; then
    if [[ "$youtube_input" =~ ^.*\&list=[A-Za-z0-9_-].* ]] || [[ "$youtube_input" =~ ^.*\?list=[A-Za-z0-9_-].* ]]; then
      LogInfo "Youtube playlist url detected"
      YOUTUBE_ID="$youtube_input"
      DOWNLOAD_PLAYLIST=true
      local playlist_count=$(yt-dlp --flat-playlist --dump-json "$youtube_input" 2>/dev/null | wc -l)
      if [[ $playlist_count -gt 0 ]]; then
        LogKeyValue "Playlist videos" "$playlist_count"
      fi
    else
      LogInfo "Youtube video url detected"
      YOUTUBE_ID="${youtube_input#*v=}"
      YOUTUBE_ID="${YOUTUBE_ID%%&*}"
    fi
  elif [[ "$youtube_input" =~ ^(http(s)?:\/\/)?(www\.)?youtube\.com\/playlist.* ]]; then
    LogInfo "Youtube playlist url detected"
    YOUTUBE_ID="$youtube_input"
    DOWNLOAD_PLAYLIST=true
    local playlist_count=$(yt-dlp --flat-playlist --dump-json "$youtube_input" 2>/dev/null | wc -l)
    if [[ $playlist_count -gt 0 ]]; then
      LogKeyValue "Playlist videos" "$playlist_count"
    fi
  elif [[ "$youtube_input" =~ ^[A-Za-z0-9_-]{11}$ ]]; then
    LogInfo "Youtube video id detected"
    YOUTUBE_ID="$youtube_input"
  else
    LogError "Invalid youtube video id or url: $youtube_input"
    LogInfo "Please enter a valid youtube video id or url"
    exit 1
  fi
  LogSuccess "URL validation successful"
}

CheckAvailableFormats() {
  local youtube_url="$1"
  local requested_format="$2"
  if [[ -z "$youtube_url" ]] || [[ -z "$requested_format" ]]; then
    return 1
  fi
  local height="${requested_format%p*}"
  local format_list=$(yt-dlp -F "$youtube_url" 2>&1 | grep -v "WARNING" | grep -E "^[0-9]+" | awk '{print $3, $4}')
  if [[ -z "$format_list" ]]; then
    return 0
  fi
  if echo "$format_list" | grep -qE "x${height}"; then
    return 0
  else
    return 1
  fi
}

GetAvailableVideoFormats() {
  local youtube_url="$1"
  LogInfo "Fetching video formats..."
  local temp_file="/tmp/ytdl_formats_$$.txt"
  yt-dlp -F "$youtube_url" > "$temp_file" 2>&1
  local formats_data=$(cat "$temp_file" | grep -E "^[0-9]+" | grep -v "^sb[0-9]" | grep -E "[0-9]+x[0-9]+")
  rm -f "$temp_file"
  if [[ -z "$formats_data" ]]; then
    LogError "No video formats found"
    return 1
  fi
  declare -gA VIDEO_FORMATS_MAP
  declare -ga VIDEO_FORMATS_LIST
  local index=1
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local format_id=$(echo "$line" | awk '{print $1}' | sed 's/-drc$//' | sed 's/-.*//')
    local ext=$(echo "$line" | awk '{print $2}')
    local resolution=$(echo "$line" | awk '{print $3}')
    local fps=$(echo "$line" | awk '{print $4}')
    [[ "$fps" == "audio" ]] && continue
    [[ "$ext" == "mhtml" ]] && continue
    if [[ "$resolution" =~ ^[0-9]+x[0-9]+$ ]]; then
      local height=$(echo "$resolution" | cut -d'x' -f2)
      local display_text="${height}p"
      if [[ "$fps" =~ ^[0-9]+$ ]] && [[ $fps -gt 30 ]]; then
        display_text="${display_text}${fps}"
      fi
      if echo "$line" | grep -qi "HDR"; then
        display_text="${display_text} HDR"
      fi
      if echo "$line" | grep -qi "drc"; then
        continue
      fi
      display_text="${display_text} (${ext})"
      local quality_key="${height}p${fps}_${ext}_${format_id}"
      if [[ -z "${VIDEO_FORMATS_MAP[$quality_key]}" ]]; then
        VIDEO_FORMATS_MAP[$quality_key]="$format_id"
        VIDEO_FORMATS_LIST+=("$index|$display_text|$format_id")
        ((index++))
      fi
    fi
  done <<< "$formats_data"
  if [[ ${#VIDEO_FORMATS_LIST[@]} -eq 0 ]]; then
    LogError "No supported video formats found"
    return 1
  fi
  LogSuccess "Found ${#VIDEO_FORMATS_LIST[@]} video formats"
  return 0
}

GetAvailableAudioFormats() {
  local youtube_url="$1"
  LogInfo "Fetching audio formats..."
  local temp_file="/tmp/ytdl_formats_$$.txt"
  yt-dlp -F "$youtube_url" > "$temp_file" 2>&1
  local formats_data=$(cat "$temp_file" | grep -E "^[0-9]+" | grep "audio only")
  rm -f "$temp_file"
  if [[ -z "$formats_data" ]]; then
    LogError "No audio formats found"
    return 1
  fi
  declare -gA AUDIO_FORMATS_MAP
  declare -ga AUDIO_FORMATS_LIST
  local index=1
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local format_id=$(echo "$line" | awk '{print $1}' | sed 's/-drc$//' | sed 's/-.*//')
    local ext=$(echo "$line" | awk '{print $2}')
    local codec=""
    local bitrate=""
    local lang=""
    if echo "$line" | grep -qi "drc"; then
      continue
    fi
    if echo "$line" | grep -qi "opus"; then
      codec="opus"
    elif echo "$line" | grep -qi "mp4a"; then
      codec="aac"
    else
      codec="$ext"
    fi
    bitrate=$(echo "$line" | awk '{for(i=1;i<=NF;i++){if($i~/^[0-9]+k$/){print $i; exit}}}' | head -1)
    if echo "$line" | grep -qE "\[(en|th|ja|ko|zh|es|fr|de)[-_]?[A-Z]*\]"; then
      lang=$(echo "$line" | grep -oE "\[(en|th|ja|ko|zh|es|fr|de)[-_]?[A-Z]*\]" | head -1 | tr -d '[]')
    fi
    local display_text=""
    if [[ -n "$bitrate" ]]; then
      display_text="${bitrate}"
    else
      display_text="unknown"
    fi
    display_text="${display_text} ${codec}"
    if [[ -n "$lang" ]]; then
      display_text="${display_text} [${lang}]"
    fi
    display_text="${display_text} (${ext})"
    local quality_key="${bitrate}_${codec}_${ext}_${format_id}"
    if [[ -z "${AUDIO_FORMATS_MAP[$quality_key]}" ]]; then
      AUDIO_FORMATS_MAP[$quality_key]="$format_id"
      AUDIO_FORMATS_LIST+=("$index|$display_text|$format_id")
      ((index++))
    fi
  done <<< "$formats_data"
  if [[ ${#AUDIO_FORMATS_LIST[@]} -eq 0 ]]; then
    LogError "No supported audio formats found"
    return 1
  fi
  LogSuccess "Found ${#AUDIO_FORMATS_LIST[@]} audio formats"
  return 0
}

SelectDynamicAudioFormat() {
  local youtube_url="$1"
  LogInfo "Fetching available audio formats..."
  if ! GetAvailableAudioFormats "$youtube_url"; then
    LogWarning "Failed to fetch formats, using best quality"
    VIDEO_FORMAT="best"
    return 1
  fi
  LogInfo "Available audio formats:"
  LogInfo "[0] Best quality (highest available)"
  local max_display=50
  local display_count=0
  for item in "${AUDIO_FORMATS_LIST[@]}"; do
    if [[ $display_count -ge $max_display ]]; then
      LogInfo "... and $((${#AUDIO_FORMATS_LIST[@]} - max_display)) more formats"
      break
    fi
    local index=$(echo "$item" | cut -d'|' -f1)
    local text=$(echo "$item" | cut -d'|' -f2)
    LogInfo "[$index] $text"
    ((display_count++))
  done
  read -r -p "Select format (0-${#AUDIO_FORMATS_LIST[@]}, press Enter for best): " format_selection
  if [[ -z "$format_selection" ]] || [[ "$format_selection" == "0" ]]; then
    VIDEO_FORMAT="best"
    LogKeyValue "Selected format" "best (highest available)"
    return 0
  fi
  if [[ ! "$format_selection" =~ ^[0-9]+$ ]] || [[ "$format_selection" -lt 1 ]] || [[ "$format_selection" -gt ${#AUDIO_FORMATS_LIST[@]} ]]; then
    LogWarning "Invalid selection, using best quality"
    VIDEO_FORMAT="best"
    return 0
  fi
  for item in "${AUDIO_FORMATS_LIST[@]}"; do
    local index=$(echo "$item" | cut -d'|' -f1)
    if [[ "$index" == "$format_selection" ]]; then
      local text=$(echo "$item" | cut -d'|' -f2)
      local format_id=$(echo "$item" | cut -d'|' -f3)
      VIDEO_FORMAT="audio_format_id:$format_id"
      LogKeyValue "Selected format" "$text (ID: $format_id)"
      return 0
    fi
  done
  LogWarning "Format not found, using best quality"
  VIDEO_FORMAT="best"
  return 0
}

SelectDynamicFormat() {
  local youtube_url="$1"
  LogInfo "Fetching available video formats..."
  if ! GetAvailableVideoFormats "$youtube_url"; then
    LogWarning "Failed to fetch formats, using best quality"
    VIDEO_FORMAT="best"
    return 1
  fi
  LogInfo "Available video formats:"
  LogInfo "[0] Best quality (highest available)"
  local max_display=50
  local display_count=0
  for item in "${VIDEO_FORMATS_LIST[@]}"; do
    if [[ $display_count -ge $max_display ]]; then
      LogInfo "... and $((${#VIDEO_FORMATS_LIST[@]} - max_display)) more formats"
      break
    fi
    local index=$(echo "$item" | cut -d'|' -f1)
    local text=$(echo "$item" | cut -d'|' -f2)
    LogInfo "[$index] $text"
    ((display_count++))
  done
  read -r -p "Select format (0-${#VIDEO_FORMATS_LIST[@]}, press Enter for best): " format_selection
  if [[ -z "$format_selection" ]] || [[ "$format_selection" == "0" ]]; then
    VIDEO_FORMAT="best"
    LogKeyValue "Selected format" "best (highest available)"
    return 0
  fi
  if [[ ! "$format_selection" =~ ^[0-9]+$ ]] || [[ "$format_selection" -lt 1 ]] || [[ "$format_selection" -gt ${#VIDEO_FORMATS_LIST[@]} ]]; then
    LogWarning "Invalid selection, using best quality"
    VIDEO_FORMAT="best"
    return 0
  fi
  for item in "${VIDEO_FORMATS_LIST[@]}"; do
    local index=$(echo "$item" | cut -d'|' -f1)
    if [[ "$index" == "$format_selection" ]]; then
      local text=$(echo "$item" | cut -d'|' -f2)
      local format_id=$(echo "$item" | cut -d'|' -f3)
      VIDEO_FORMAT="format_id:$format_id"
      LogKeyValue "Selected format" "$text (ID: $format_id)"
      return 0
    fi
  done
  LogWarning "Format not found, using best quality"
  VIDEO_FORMAT="best"
  return 0
}
GetFormatString() {
  local format="$1"
  local download_type="$2"
  local youtube_url="$3"
  if [[ "$format" =~ ^format_id: ]]; then
    local format_id="${format#format_id:}"
    echo "${format_id}+bestaudio/best"
    return 0
  fi
  if [[ "$format" =~ ^audio_format_id: ]]; then
    local format_id="${format#audio_format_id:}"
    echo "${format_id}"
    return 0
  fi
  case "$format" in
    best)
      if [[ "$download_type" =~ ^[vV]$ ]]; then
        echo "bestvideo*+bestaudio/best"
      else
        echo "bestaudio*[ext=m4a]/bestaudio*/bestaudio/best"
      fi
      ;;
    worst)
      if [[ "$download_type" =~ ^[vV]$ ]]; then
        echo "worstvideo*+worstaudio*/worst"
      else
        echo "worstaudio*/worst"
      fi
      ;;
    144p*|240p*|360p*|480p*|720p*|1080p*|1440p*|2160p*)
      local height="${format%p*}"
      echo "bestvideo*[height<=${height}]+bestaudio*/best*[height<=${height}]/bestvideo*+bestaudio*/best"
      ;;
    *)
      if [[ "$download_type" =~ ^[vV]$ ]]; then
        echo "bestvideo*+bestaudio*/best"
      else
        echo "bestaudio*[ext=m4a]/bestaudio*/bestaudio/best"
      fi
      ;;
  esac
}

GetYoutubeDownloadDirectory() {
  local download_type="$1"
  local youtube_download_dir=""
  if [[ "$download_type" =~ ^[vV]$ ]]; then
    if [[ $OSTYPE == "darwin"* ]]; then
      youtube_download_dir="$HOME/Movies"
    elif [[ $OSTYPE == "msys" ]]; then
      youtube_download_dir="$HOME/Videos"
    elif [[ $OSTYPE == "linux-gnu"* ]]; then
      youtube_download_dir="$HOME/Videos"
    fi
  elif [[ "$download_type" =~ ^[aA]$ ]]; then
    youtube_download_dir="$HOME/Music"
  else
    LogError "Invalid download type: $download_type"
    LogInfo "Please enter video (v) or audio (a) for youtube download"
    exit 1
  fi
  if [[ "$ORGANIZE_BY" != "none" ]]; then
    if [[ "$ORGANIZE_BY" == "date" ]]; then
      local date_dir=$(date "+%Y-%m-%d")
      youtube_download_dir="$youtube_download_dir/$date_dir"
    elif [[ "$ORGANIZE_BY" == "channel" ]]; then
      youtube_download_dir="$youtube_download_dir/%(uploader)s"
    fi
  fi
  if [[ ! -d "$youtube_download_dir" ]] && [[ "$ORGANIZE_BY" != "channel" ]]; then
    LogWarning "Download directory does not exist: $youtube_download_dir" >&2
    LogInfo "Creating download directory..." >&2
    mkdir -p "$youtube_download_dir" 2>/dev/null
    if ! _ValidateDirectory "$youtube_download_dir" >/dev/null 2>&1; then
      LogError "Failed to create or validate download directory: $youtube_download_dir" >&2
      exit 1
    fi
    local dir_size=$(GetDirectorySize "$youtube_download_dir" "true")
    LogSuccess "Download directory ready: $youtube_download_dir (current size: $dir_size)" >&2
  else
    if [[ -d "$youtube_download_dir" ]]; then
      local dir_size=$(GetDirectorySize "$youtube_download_dir" "true")
      local file_count=$(CountFiles "$youtube_download_dir" "1")
      LogInfo "Using existing directory: $youtube_download_dir" >&2
      LogInfo "Directory size: $dir_size, Files: $file_count" >&2
    fi
  fi
  echo "$youtube_download_dir"
}

DownloadYoutubeContent() {
  local youtube_id="$1"
  local download_type="$2"
  local youtube_download_dir="$3"
  local download_url=""
  if [[ "$DOWNLOAD_PLAYLIST" == "true" ]]; then
    download_url="$youtube_id"
  else
    download_url="https://www.youtube.com/watch?v=$youtube_id"
  fi
  LogInfo "Starting download..."
  LogKeyValue "URL" "$download_url"
  LogKeyValue "Type" "$(if [[ "$download_type" =~ ^[vV]$ ]]; then echo "Video"; else echo "Audio"; fi)"
  LogKeyValue "Output" "$youtube_download_dir"
  local format_string=$(GetFormatString "$VIDEO_FORMAT" "$download_type" "$download_url")
  local ytdlp_args=()
  ytdlp_args+=("-f" "$format_string")
  ytdlp_args+=("-o" "$youtube_download_dir/%(title)s.%(ext)s")
  if [[ "$DOWNLOAD_SUBTITLE" == "true" ]]; then
    ytdlp_args+=("--write-sub" "--sub-lang" "$SUBTITLE_LANG" "--embed-subs")
    LogInfo "Downloading subtitles: $SUBTITLE_LANG"
  fi
  if [[ "$EMBED_METADATA" == "true" ]]; then
    ytdlp_args+=("--embed-metadata")
    ytdlp_args+=("--embed-thumbnail" "--convert-thumbnails" "jpg" "--no-abort-on-error")
    LogInfo "Embedding metadata and thumbnail (if format supports it)"
  fi
  ytdlp_args+=("--retries" "$MAX_RETRIES")
  ytdlp_args+=("--continue")
  if [[ "$DOWNLOAD_PLAYLIST" == "true" ]]; then
    ytdlp_args+=("--yes-playlist")
    LogInfo "Downloading entire playlist..."
  else
    ytdlp_args+=("--no-playlist")
  fi
  ytdlp_args+=("$download_url")
  local attempt=1
  local success=false
  while [[ $attempt -le $MAX_RETRIES ]]; do
    if [[ $attempt -gt 1 ]]; then
      LogWarning "Retry attempt $attempt/$MAX_RETRIES"
      if [[ $attempt -eq 2 ]] && [[ "$VIDEO_FORMAT" != "best" ]] && [[ "$download_type" =~ ^[vV]$ ]]; then
        LogInfo "Falling back to best available quality..."
        format_string=$(GetFormatString "best" "$download_type" "$download_url")
        ytdlp_args[1]="$format_string"
      fi
    fi
    local temp_output_file="/tmp/ytdl_output_$$_$attempt.txt"
    yt-dlp "${ytdlp_args[@]}" 2>&1 | tee "$temp_output_file"
    local exit_code=$?
    local output=$(cat "$temp_output_file" 2>/dev/null)
    rm -f "$temp_output_file"
    if echo "$output" | grep -q "Sign in to confirm you.*re not a bot"; then
      LogError "YouTube detected bot activity and requires authentication"
      LogInfo "Please use --cookies-from-browser option or wait and try again later"
      success=false
      break
    elif echo "$output" | grep -q "\[download\] 100%" && echo "$output" | grep -q "ERROR: Postprocessing: Supported filetypes for thumbnail embedding"; then
      LogWarning "Download completed but thumbnail embedding not supported for this format"
      find "$youtube_download_dir" -maxdepth 1 \( -name "*.jpg" -o -name "*.webp" \) -type f -print0 | xargs -0 rm -f 2>/dev/null
      LogInfo "Removed unsupported thumbnail files"
      success=true
      break
    elif [[ $exit_code -eq 0 ]]; then
      success=true
      break
    else
      ((attempt++))
      if [[ $attempt -le $MAX_RETRIES ]]; then
        LogWarning "Download failed, retrying in 3 seconds..."
        sleep 3
      fi
    fi
  done
  if [[ "$success" == "true" ]]; then
    LogSuccess "Download completed successfully!"
  else
    LogError "Download failed after $MAX_RETRIES attempts"
    exit 1
  fi
}

OpenYoutubeDownloadDirectory() {
  local youtube_download_dir="$1"
  local open_command=""
  if [[ $OSTYPE == "darwin"* ]]; then
    open_command="open"
  elif [[ $OSTYPE == "msys" ]]; then
    open_command="start"
  elif [[ $OSTYPE == "linux-gnu"* ]]; then
    open_command="xdg-open"
  fi
  LogInfo "Opening download directory..."
  if "$open_command" "$youtube_download_dir" 2>/dev/null; then
    LogSuccess "Directory opened: $youtube_download_dir"
  else
    LogWarning "Could not open directory automatically"
  fi
  LogInfo "Files saved to: $youtube_download_dir"
}

InteractiveMenu() {
  LogInfo "YouTube Downloader - Interactive Mode"
  read -r -p "Enter YouTube video ID or URL: " YOUTUBE_INPUT
  if [[ -z "$YOUTUBE_INPUT" ]]; then
    LogError "URL cannot be empty"
    return 1
  fi
  ValidateYoutubeUrl "$YOUTUBE_INPUT"
  if [[ "$DOWNLOAD_PLAYLIST" == "true" ]]; then
    LogInfo "Playlist detected"
    read -r -p "Download entire playlist? (Y/N): " playlist_choice
    if [[ "${playlist_choice^^}" != "Y" ]]; then
      DOWNLOAD_PLAYLIST=false
      YOUTUBE_ID="${YOUTUBE_INPUT#*v=}"
      YOUTUBE_ID="${YOUTUBE_ID%%&*}"
      LogInfo "Will download only the first video"
    fi
  fi
  read -r -p "Download video or audio? (V/A): " DOWNLOAD_TYPE
  DOWNLOAD_TYPE="${DOWNLOAD_TYPE^^}"
  if [[ ! "$DOWNLOAD_TYPE" =~ ^[VA]$ ]]; then
    LogError "Invalid choice. Please enter V or A"
    return 1
  fi
  if [[ "$DOWNLOAD_TYPE" == "V" ]]; then
    local download_url=""
    if [[ "$DOWNLOAD_PLAYLIST" == "true" ]]; then
      download_url="$YOUTUBE_ID"
    else
      download_url="https://www.youtube.com/watch?v=$YOUTUBE_ID"
    fi
    SelectDynamicFormat "$download_url"
    read -r -p "Download subtitles? (Y/N): " subtitle_choice
    if [[ "${subtitle_choice^^}" == "Y" ]]; then
      DOWNLOAD_SUBTITLE=true
      read -r -p "Subtitle language (default: en): " SUBTITLE_LANG
      [[ -z "$SUBTITLE_LANG" ]] && SUBTITLE_LANG="en"
    fi
  else
    local download_url=""
    if [[ "$DOWNLOAD_PLAYLIST" == "true" ]]; then
      download_url="$YOUTUBE_ID"
    else
      download_url="https://www.youtube.com/watch?v=$YOUTUBE_ID"
    fi
    SelectDynamicAudioFormat "$download_url"
  fi
  read -r -p "Embed metadata? (Y/N, default: Y): " metadata_choice
  if [[ "${metadata_choice^^}" != "N" ]]; then
    EMBED_METADATA=true
  fi
  read -r -p "Organize files by date? (Y/N, default: Y): " organize_choice
  if [[ "${organize_choice^^}" != "N" ]]; then
    ORGANIZE_BY="date"
  else
    ORGANIZE_BY="none"
  fi
  YOUTUBE_DOWNLOAD_DIR=$(GetYoutubeDownloadDirectory "$DOWNLOAD_TYPE")
  LogInfo "Download settings:"
  LogKeyValue "Type" "$(if [[ "$DOWNLOAD_TYPE" == "V" ]]; then echo "Video"; else echo "Audio"; fi)"
  LogKeyValue "Format" "$VIDEO_FORMAT"
  LogKeyValue "Subtitles" "$(if [[ "$DOWNLOAD_SUBTITLE" == "true" ]]; then echo "Yes ($SUBTITLE_LANG)"; else echo "No"; fi)"
  LogKeyValue "Metadata" "$(if [[ "$EMBED_METADATA" == "true" ]]; then echo "Yes"; else echo "No"; fi)"
  LogKeyValue "Organize by" "$ORGANIZE_BY"
  read -r -p "Proceed with download? (Y/N): " confirm_download
  if [[ "${confirm_download^^}" != "Y" ]]; then
    LogInfo "Download cancelled"
    return 1
  fi
  touch /tmp/ytdl_marker_$$
  DownloadYoutubeContent "$YOUTUBE_ID" "$DOWNLOAD_TYPE" "$YOUTUBE_DOWNLOAD_DIR"
  rm -f /tmp/ytdl_marker_$$
  OpenYoutubeDownloadDirectory "$YOUTUBE_DOWNLOAD_DIR"
  return 0
}

Main() {
  local start_time=$(date +%s)
  LogInfo "YouTube Downloader"
  LogInfo "Started at: $(date '+%Y-%m-%d %H:%M:%S')"
  CheckYoutubeDownloadCompatibility
  CheckYoutubeDownloadDependencies
  InteractiveMenu
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  local hours=$((duration / 3600))
  local minutes=$(((duration % 3600) / 60))
  local seconds=$((duration % 60))
  local duration_str=""
  [[ $hours -gt 0 ]] && duration_str="${hours}h "
  [[ $minutes -gt 0 ]] && duration_str="${duration_str}${minutes}m "
  duration_str="${duration_str}${seconds}s"
  LogKeyValue "Duration" "$duration_str"
  LogKeyValue "Finished at" "$(date '+%Y-%m-%d %H:%M:%S')"
  LogSuccess "Process completed successfully!"
}

Main
