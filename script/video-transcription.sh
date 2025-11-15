#!/usr/bin/env bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SYSTEM_OS_TYPE="$(uname -s)"
readonly OS_PATTERN_SUPPORTED="^(Darwin|Linux|MINGW|MSYS|CYGWIN)"

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

declare INPUT_FILE=""
declare OUTPUT_DIR=""
declare OUTPUT_FORMAT="srt"
declare WHISPER_MODEL="base"
declare WHISPER_DEVICE="cuda"
declare LANGUAGE="auto"
declare TASK="transcribe"
declare WORD_TIMESTAMPS=false
declare MAX_LINE_WIDTH=42
declare MAX_LINE_COUNT=2
declare HIGHLIGHT_WORDS=false
declare VERBOSE=false

readonly SUPPORTED_VIDEO_EXTENSIONS="mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpeg|mpg|3gp"
readonly SUPPORTED_AUDIO_EXTENSIONS="mp3|wav|flac|aac|ogg|m4a|wma|opus"
readonly SUPPORTED_OUTPUT_FORMATS="txt|srt|vtt|json|tsv|all"
readonly WHISPER_MODELS="tiny|base|small|medium|large|large-v2|large-v3"

ValidateSystemEnvironment() {
  if [[ ! "${SYSTEM_OS_TYPE}" =~ ${OS_PATTERN_SUPPORTED} ]]; then
    LogError "Unsupported OS: ${SYSTEM_OS_TYPE}"
    return 1
  fi
  LogInfo "OS detected: ${SYSTEM_OS_TYPE}"
  return 0
}

CheckTranscriptionDependencies() {
  local required_commands="whisper ffmpeg"
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
    LogInfo "Install whisper: pip install openai-whisper"
    LogInfo "Install ffmpeg: brew install ffmpeg (macOS) or apt install ffmpeg (Linux)"
    exit 1
  fi
  if CheckCudaAvailable; then
    LogSuccess "CUDA available: GPU acceleration enabled"
    WHISPER_DEVICE="cuda"
  else
    LogWarning "CUDA not available: using CPU (slower)"
    LogInfo "To enable GPU: pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121"
    WHISPER_DEVICE="cpu"
  fi
  LogSuccess "All dependencies are installed"
}

ValidateInputFile() {
  local input_file="$1"
  if [[ -z "$input_file" ]]; then
    LogError "Input file parameter is required"
    exit 1
  fi
  if [[ ! -f "$input_file" ]]; then
    LogError "Input file does not exist: $input_file"
    exit 1
  fi
  local extension=$(GetFileExtension "$input_file" | tr '[:upper:]' '[:lower:]')
  if [[ ! "$extension" =~ ^($SUPPORTED_VIDEO_EXTENSIONS|$SUPPORTED_AUDIO_EXTENSIONS)$ ]]; then
    LogError "Unsupported file format: $extension"
    LogInfo "Supported video formats: ${SUPPORTED_VIDEO_EXTENSIONS//|/, }"
    LogInfo "Supported audio formats: ${SUPPORTED_AUDIO_EXTENSIONS//|/, }"
    exit 1
  fi
  local file_size=$(GetFileSize "$input_file" "true")
  LogKeyValue "Input file" "$input_file"
  LogKeyValue "File size" "$file_size"
  LogKeyValue "Format" "$extension"
  LogSuccess "Input file validation successful"
}

ValidateOutputFormat() {
  local format="$1"
  if [[ ! "$format" =~ ^($SUPPORTED_OUTPUT_FORMATS)$ ]]; then
    LogError "Unsupported output format: $format"
    LogInfo "Supported formats: ${SUPPORTED_OUTPUT_FORMATS//|/, }"
    exit 1
  fi
  LogSuccess "Output format validated: $format"
}

ValidateWhisperModel() {
  local model="$1"
  if [[ ! "$model" =~ ^($WHISPER_MODELS)$ ]]; then
    LogError "Unsupported Whisper model: $model"
    LogInfo "Supported models: ${WHISPER_MODELS//|/, }"
    exit 1
  fi
  LogSuccess "Whisper model validated: $model"
}

GetMediaDuration() {
  local input_file="$1"
  local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null)
  if [[ -z "$duration" ]]; then
    echo "0"
    return 1
  fi
  printf "%.0f" "$duration"
}

GetMediaInfo() {
  local input_file="$1"
  LogInfo "Analyzing media file..."
  local duration=$(GetMediaDuration "$input_file")
  local duration_formatted=$(FormatDuration "$duration" "long")
  LogKeyValue "Duration" "$duration_formatted"
  local has_audio=$(ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 "$input_file" 2>/dev/null | head -1)
  if [[ -z "$has_audio" ]]; then
    LogError "No audio stream found in the file"
    exit 1
  fi
  LogSuccess "Audio stream detected"
  local audio_info=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,sample_rate,channels -of csv=p=0 "$input_file" 2>/dev/null | head -1)
  if [[ -n "$audio_info" ]]; then
    local codec=$(echo "$audio_info" | cut -d',' -f1)
    local sample_rate=$(echo "$audio_info" | cut -d',' -f2)
    local channels=$(echo "$audio_info" | cut -d',' -f3)
    LogKeyValue "Audio codec" "$codec"
    LogKeyValue "Sample rate" "${sample_rate}Hz"
    LogKeyValue "Channels" "$channels"
  fi
}

GetOutputDirectory() {
  local input_file="$1"
  local custom_output_dir="$2"
  local output_dir=""
  if [[ -n "$custom_output_dir" ]]; then
    output_dir="$custom_output_dir"
  else
    output_dir=$(dirname "$input_file")
  fi
  if [[ ! -d "$output_dir" ]]; then
    LogWarning "Output directory does not exist: $output_dir"
    LogInfo "Creating output directory..."
    mkdir -p "$output_dir" 2>/dev/null
    if [[ ! -d "$output_dir" ]]; then
      LogError "Failed to create output directory: $output_dir"
      exit 1
    fi
  fi
  echo "$output_dir"
}

ExtractAudio() {
  local input_file="$1"
  local temp_audio_file="$2"
  LogInfo "Extracting audio from video..."
  local extension=$(GetFileExtension "$input_file" | tr '[:upper:]' '[:lower:]')
  if [[ "$extension" =~ ^($SUPPORTED_AUDIO_EXTENSIONS)$ ]]; then
    LogInfo "Input is already an audio file, skipping extraction"
    cp "$input_file" "$temp_audio_file"
    return 0
  fi
  ffmpeg -i "$input_file" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$temp_audio_file" -y -loglevel error 2>&1
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    LogError "Failed to extract audio from video"
    return 1
  fi
  local audio_size=$(GetFileSize "$temp_audio_file" "true")
  LogSuccess "Audio extracted successfully (size: $audio_size)"
  return 0
}

RunWhisperTranscription() {
  local audio_file="$1"
  local output_dir="$2"
  local output_format="$3"
  local model="$4"
  local language="$5"
  local task="$6"
  LogInfo "Starting Whisper transcription..."
  LogKeyValue "Model" "$model"
  LogKeyValue "Language" "$language"
  LogKeyValue "Task" "$task"
  LogKeyValue "Output format" "$output_format"
  local whisper_args=()
  whisper_args+=("$audio_file")
  whisper_args+=("--model" "$model")
  whisper_args+=("--device" "$WHISPER_DEVICE")
  whisper_args+=("--output_dir" "$output_dir")
  if [[ "$output_format" == "all" ]]; then
    whisper_args+=("--output_format" "all")
  else
    whisper_args+=("--output_format" "$output_format")
  fi
  if [[ "$language" != "auto" ]]; then
    whisper_args+=("--language" "$language")
  fi
  if [[ "$task" == "translate" ]]; then
    whisper_args+=("--task" "translate")
  fi
  if [[ "$WORD_TIMESTAMPS" == "true" ]]; then
    whisper_args+=("--word_timestamps" "True")
    whisper_args+=("--max_line_width" "$MAX_LINE_WIDTH")
    whisper_args+=("--max_line_count" "$MAX_LINE_COUNT")
    if [[ "$HIGHLIGHT_WORDS" == "true" ]]; then
      whisper_args+=("--highlight_words" "True")
    fi
  fi
  if [[ "$VERBOSE" == "true" ]]; then
    whisper_args+=("--verbose" "True")
  fi
  LogInfo "Running Whisper..."
  local start_time=$(date +%s)
  local temp_dir="${TMPDIR:-/tmp}"
  local temp_log="$temp_dir/whisper_log_$$.txt"
  PYTHONIOENCODING=utf-8 PYTHONUTF8=1 whisper "${whisper_args[@]}" > "$temp_log" 2>&1
  local exit_code=$?
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  if [[ -f "$temp_log" ]]; then
    while IFS= read -r line; do
      if [[ "$VERBOSE" == "true" ]]; then
        echo "$line"
      else
        if [[ "$line" =~ ^\[.*\] ]]; then
          echo "$line"
        fi
      fi
    done < "$temp_log"
    if [[ $exit_code -ne 0 ]]; then
      LogError "Whisper output:"
      cat "$temp_log" >&2
    fi
    rm -f "$temp_log"
  fi
  if [[ $exit_code -ne 0 ]]; then
    LogError "Whisper transcription failed (exit code: $exit_code)"
    return 1
  fi
  local duration_formatted=$(FormatDuration "$duration" "long")
  LogSuccess "Transcription completed in $duration_formatted"
  return 0
}

CleanupTempFiles() {
  local temp_file="$1"
  if [[ -f "$temp_file" ]]; then
    rm -f "$temp_file" 2>/dev/null
    LogDebug "Cleaned up temporary file: $temp_file"
  fi
}

ListOutputFiles() {
  local output_dir="$1"
  local base_name="$2"
  LogInfo "Generated output files:"
  local found_files=0
  for ext in txt srt vtt json tsv; do
    local output_file="$output_dir/${base_name}.${ext}"
    if [[ -f "$output_file" ]]; then
      local file_size=$(GetFileSize "$output_file" "true")
      LogKeyValue "  $ext" "$output_file ($file_size)"
      ((found_files++))
    fi
  done
  if [[ $found_files -eq 0 ]]; then
    LogWarning "No output files found"
  fi
}

OpenOutputDirectory() {
  local output_dir="$1"
  local open_command=()
  local open_path="$output_dir"
  if [[ $OSTYPE == "darwin"* ]]; then
    open_command=("open")
  elif [[ $OSTYPE == msys* ]] || [[ $OSTYPE == mingw* ]] || [[ $OSTYPE == cygwin* ]] || [[ $SYSTEM_OS_TYPE == MINGW* ]] || [[ $SYSTEM_OS_TYPE == MSYS* ]] || [[ $SYSTEM_OS_TYPE == CYGWIN* ]]; then
    open_path="$(cygpath -w "$output_dir" 2>/dev/null || echo "$output_dir")"
    if command -v cygstart >/dev/null 2>&1; then
      open_command=("cygstart")
    elif command -v powershell.exe >/dev/null 2>&1; then
      open_command=("powershell.exe" "-NoProfile" "-Command" "& { param(\$target_path) Invoke-Item -LiteralPath \$target_path }")
    elif command -v cmd.exe >/dev/null 2>&1; then
      open_command=("cmd.exe" "//c" "start" "")
    elif command -v explorer.exe >/dev/null 2>&1; then
      open_command=("explorer.exe")
    fi
  elif [[ $OSTYPE == "linux-gnu"* ]]; then
    open_command=("xdg-open")
  fi
  LogInfo "Opening output directory..."
  if [[ ${#open_command[@]} -gt 0 ]] && "${open_command[@]}" "$open_path" 2>/dev/null; then
    LogSuccess "Directory opened: $output_dir"
  else
    LogWarning "Could not open directory automatically"
  fi
  LogInfo "Files saved to: $output_dir"
}

CheckCudaAvailable() {
  python -c "import torch; exit(0 if torch.cuda.is_available() else 1)" 2>/dev/null
  return $?
}

SelectWhisperModel() {
  LogInfo "Available Whisper models:"
  LogInfo "[1] tiny    - Fastest, lowest accuracy (~1GB VRAM)"
  LogInfo "[2] base    - Fast, good accuracy (~1GB VRAM) [Default]"
  LogInfo "[3] small   - Balanced speed/accuracy (~2GB VRAM)"
  LogInfo "[4] medium  - Good accuracy, slower (~5GB VRAM)"
  LogInfo "[5] large   - Best accuracy, slowest (~10GB VRAM)"
  LogInfo "[6] large-v2 - Improved large model"
  LogInfo "[7] large-v3 - Latest large model"
  read -r -p "Select model (1-7, press Enter for base): " model_choice
  case "$model_choice" in
    1) WHISPER_MODEL="tiny" ;;
    2|"") WHISPER_MODEL="base" ;;
    3) WHISPER_MODEL="small" ;;
    4) WHISPER_MODEL="medium" ;;
    5) WHISPER_MODEL="large" ;;
    6) WHISPER_MODEL="large-v2" ;;
    7) WHISPER_MODEL="large-v3" ;;
    *)
      LogWarning "Invalid selection, using base model"
      WHISPER_MODEL="base"
      ;;
  esac
  LogKeyValue "Selected model" "$WHISPER_MODEL"
}

SelectOutputFormat() {
  LogInfo "Available output formats:"
  LogInfo "[1] srt  - SubRip subtitle format [Default]"
  LogInfo "[2] vtt  - WebVTT subtitle format"
  LogInfo "[3] txt  - Plain text transcript"
  LogInfo "[4] json - JSON with timestamps"
  LogInfo "[5] tsv  - Tab-separated values"
  LogInfo "[6] all  - Generate all formats"
  read -r -p "Select format (1-6, press Enter for srt): " format_choice
  case "$format_choice" in
    1|"") OUTPUT_FORMAT="srt" ;;
    2) OUTPUT_FORMAT="vtt" ;;
    3) OUTPUT_FORMAT="txt" ;;
    4) OUTPUT_FORMAT="json" ;;
    5) OUTPUT_FORMAT="tsv" ;;
    6) OUTPUT_FORMAT="all" ;;
    *)
      LogWarning "Invalid selection, using srt format"
      OUTPUT_FORMAT="srt"
      ;;
  esac
  LogKeyValue "Selected format" "$OUTPUT_FORMAT"
}

SelectLanguage() {
  LogInfo "Language options:"
  LogInfo "[1] auto    - Auto-detect language [Default]"
  LogInfo "[2] en      - English"
  LogInfo "[3] th      - Thai"
  LogInfo "[4] ja      - Japanese"
  LogInfo "[5] ko      - Korean"
  LogInfo "[6] zh      - Chinese"
  LogInfo "[7] custom  - Enter custom language code"
  read -r -p "Select language (1-7, press Enter for auto): " lang_choice
  case "$lang_choice" in
    1|"") LANGUAGE="auto" ;;
    2) LANGUAGE="en" ;;
    3) LANGUAGE="th" ;;
    4) LANGUAGE="ja" ;;
    5) LANGUAGE="ko" ;;
    6) LANGUAGE="zh" ;;
    7)
      read -r -p "Enter language code (e.g., es, fr, de): " custom_lang
      if [[ -n "$custom_lang" ]]; then
        LANGUAGE="$custom_lang"
      else
        LANGUAGE="auto"
      fi
      ;;
    *)
      LogWarning "Invalid selection, using auto-detect"
      LANGUAGE="auto"
      ;;
  esac
  LogKeyValue "Selected language" "$LANGUAGE"
}

SelectTask() {
  LogInfo "Task options:"
  LogInfo "[1] transcribe - Transcribe in original language [Default]"
  LogInfo "[2] translate  - Translate to English"
  read -r -p "Select task (1-2, press Enter for transcribe): " task_choice
  case "$task_choice" in
    1|"") TASK="transcribe" ;;
    2) TASK="translate" ;;
    *)
      LogWarning "Invalid selection, using transcribe"
      TASK="transcribe"
      ;;
  esac
  LogKeyValue "Selected task" "$TASK"
}

ConfigureAdvancedOptions() {
  read -r -p "Configure advanced options? (Y/N, default: N): " advanced_choice
  if [[ "${advanced_choice^^}" != "Y" ]]; then
    return 0
  fi
  LogInfo "Advanced options:"
  read -r -p "Enable word-level timestamps? (Y/N, default: N): " word_ts_choice
  if [[ "${word_ts_choice^^}" == "Y" ]]; then
    WORD_TIMESTAMPS=true
    LogKeyValue "Word timestamps" "enabled"
  fi
  read -r -p "Highlight words in output? (Y/N, default: N): " highlight_choice
  if [[ "${highlight_choice^^}" == "Y" ]]; then
    HIGHLIGHT_WORDS=true
    LogKeyValue "Highlight words" "enabled"
  fi
  read -r -p "Max characters per line (default: 42): " max_width
  if [[ -n "$max_width" && "$max_width" =~ ^[0-9]+$ ]]; then
    MAX_LINE_WIDTH=$max_width
    LogKeyValue "Max line width" "$MAX_LINE_WIDTH"
  fi
  read -r -p "Max lines per subtitle (default: 2): " max_lines
  if [[ -n "$max_lines" && "$max_lines" =~ ^[0-9]+$ ]]; then
    MAX_LINE_COUNT=$max_lines
    LogKeyValue "Max line count" "$MAX_LINE_COUNT"
  fi
  read -r -p "Enable verbose output? (Y/N, default: N): " verbose_choice
  if [[ "${verbose_choice^^}" == "Y" ]]; then
    VERBOSE=true
    LogKeyValue "Verbose mode" "enabled"
  fi
}

BatchTranscribe() {
  local input_dir="$1"
  local pattern="${2:-*}"
  if [[ ! -d "$input_dir" ]]; then
    LogError "Input directory does not exist: $input_dir"
    return 1
  fi
  LogInfo "Batch transcription mode"
  LogKeyValue "Directory" "$input_dir"
  LogKeyValue "Pattern" "$pattern"
  local files=()
  while IFS= read -r -d '' file; do
    local ext=$(GetFileExtension "$file" | tr '[:upper:]' '[:lower:]')
    if [[ "$ext" =~ ^($SUPPORTED_VIDEO_EXTENSIONS|$SUPPORTED_AUDIO_EXTENSIONS)$ ]]; then
      files+=("$file")
    fi
  done < <(find "$input_dir" -maxdepth 1 -type f -name "$pattern" -print0 2>/dev/null)
  if [[ ${#files[@]} -eq 0 ]]; then
    LogWarning "No supported media files found in directory"
    return 1
  fi
  LogInfo "Found ${#files[@]} media files:"
  local index=1
  for file in "${files[@]}"; do
    local file_name=$(basename "$file")
    local file_size=$(GetFileSize "$file" "true")
    LogInfo "  [$index] $file_name ($file_size)"
    ((index++))
  done
  read -r -p "Proceed with batch transcription? (Y/N, default: Y): " confirm_choice
  if [[ "${confirm_choice^^}" == "N" ]]; then
    LogInfo "Batch transcription cancelled"
    return 1
  fi
  SelectWhisperModel
  SelectOutputFormat
  SelectLanguage
  SelectTask
  local success_count=0
  local fail_count=0
  local total=${#files[@]}
  for i in "${!files[@]}"; do
    local file="${files[$i]}"
    local current=$((i + 1))
    LogInfo "Processing file $current/$total: $(basename "$file")"
    ShowProgress "$current" "$total" "$(basename "$file")"
    local batch_base_name=$(GetFileBasename "$file")
    local batch_output_dir=$(dirname "$file")
    local temp_audio_file="$batch_output_dir/${batch_base_name}_temp_audio.wav"
    if ExtractAudio "$file" "$temp_audio_file"; then
      if RunWhisperTranscription "$temp_audio_file" "$batch_output_dir" "$OUTPUT_FORMAT" "$WHISPER_MODEL" "$LANGUAGE" "$TASK"; then
        local temp_base_name=$(GetFileBasename "$temp_audio_file")
        for ext in txt srt vtt json tsv; do
          local temp_output="$batch_output_dir/${temp_base_name}.${ext}"
          local final_output="$batch_output_dir/${batch_base_name}.${ext}"
          if [[ -f "$temp_output" ]]; then
            mv "$temp_output" "$final_output" 2>/dev/null
          fi
        done
        ((success_count++))
        LogSuccess "Completed: $(basename "$file")"
      else
        ((fail_count++))
        LogError "Failed: $(basename "$file")"
      fi
    else
      ((fail_count++))
      LogError "Failed to extract audio: $(basename "$file")"
    fi
    CleanupTempFiles "$temp_audio_file"
  done
  ClearProgress
  LogInfo "Batch transcription completed"
  LogKeyValue "Successful" "$success_count/$total"
  LogKeyValue "Failed" "$fail_count/$total"
  return 0
}

InteractiveMenu() {
  LogInfo "Video Transcription - Interactive Mode"
  LogInfo "Mode options:"
  LogInfo "[1] Transcribe single file"
  LogInfo "[2] Batch transcribe directory"
  read -r -p "Select mode (1-2, press Enter for single file): " mode_choice
  case "$mode_choice" in
    1|"")
      read -r -p "Enter video/audio file path: " INPUT_FILE
      if [[ -z "$INPUT_FILE" ]]; then
        LogError "File path cannot be empty"
        return 1
      fi
      INPUT_FILE="${INPUT_FILE//\"/}"
      INPUT_FILE="${INPUT_FILE//\'/}"
      INPUT_FILE="${INPUT_FILE/#\~/$HOME}"
      ValidateInputFile "$INPUT_FILE"
      GetMediaInfo "$INPUT_FILE"
      ;;
    2)
      read -r -p "Enter directory path: " input_dir
      if [[ -z "$input_dir" ]]; then
        LogError "Directory path cannot be empty"
        return 1
      fi
      input_dir="${input_dir/#\~/$HOME}"
      read -r -p "File pattern (default: *): " pattern
      [[ -z "$pattern" ]] && pattern="*"
      BatchTranscribe "$input_dir" "$pattern"
      return $?
      ;;
    *)
      LogError "Invalid option"
      return 1
      ;;
  esac
  SelectWhisperModel
  SelectOutputFormat
  SelectLanguage
  SelectTask
  ConfigureAdvancedOptions
  local output_dir=$(GetOutputDirectory "$INPUT_FILE" "$OUTPUT_DIR")
  LogKeyValue "Output directory" "$output_dir"
  LogInfo "Transcription settings:"
  LogKeyValue "Input" "$INPUT_FILE"
  LogKeyValue "Device" "$WHISPER_DEVICE"
  LogKeyValue "Model" "$WHISPER_MODEL"
  LogKeyValue "Format" "$OUTPUT_FORMAT"
  LogKeyValue "Language" "$LANGUAGE"
  LogKeyValue "Task" "$TASK"
  read -r -p "Proceed with transcription? (Y/N, default: Y): " confirm_choice
  if [[ "${confirm_choice^^}" == "N" ]]; then
    LogInfo "Transcription cancelled"
    return 1
  fi
  local original_base_name=$(GetFileBasename "$INPUT_FILE")
  local temp_audio_file="$output_dir/${original_base_name}_temp_audio.wav"
  if ! ExtractAudio "$INPUT_FILE" "$temp_audio_file"; then
    LogError "Failed to extract audio"
    return 1
  fi
  if ! RunWhisperTranscription "$temp_audio_file" "$output_dir" "$OUTPUT_FORMAT" "$WHISPER_MODEL" "$LANGUAGE" "$TASK"; then
    LogError "Transcription failed"
    CleanupTempFiles "$temp_audio_file"
    return 1
  fi
  local temp_base_name=$(GetFileBasename "$temp_audio_file")
  for ext in txt srt vtt json tsv; do
    local temp_output="$output_dir/${temp_base_name}.${ext}"
    local final_output="$output_dir/${original_base_name}.${ext}"
    if [[ -f "$temp_output" ]]; then
      mv "$temp_output" "$final_output" 2>/dev/null
      LogDebug "Renamed: $temp_output -> $final_output"
    fi
  done
  CleanupTempFiles "$temp_audio_file"
  ListOutputFiles "$output_dir" "$original_base_name"
  OpenOutputDirectory "$output_dir"
  return 0
}

Main() {
  if ! ValidateSystemEnvironment; then
    exit 1
  fi
  CheckTranscriptionDependencies
  InteractiveMenu
  LogSuccess "Process completed successfully!"
}

Main
