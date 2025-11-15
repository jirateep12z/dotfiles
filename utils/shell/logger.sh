#!/usr/bin/env bash

readonly COLOR_RESET=$'\033[0;00m'
readonly COLOR_RED=$'\033[0;31m'
readonly COLOR_GREEN=$'\033[0;32m'
readonly COLOR_YELLOW=$'\033[0;33m'
readonly COLOR_BLUE=$'\033[0;34m'
readonly COLOR_MAGENTA=$'\033[0;35m'
readonly COLOR_CYAN=$'\033[0;36m'
readonly COLOR_WHITE=$'\033[0;37m'
readonly COLOR_GRAY=$'\033[0;90m'

readonly COLOR_BOLD_RED=$'\033[1;31m'
readonly COLOR_BOLD_GREEN=$'\033[1;32m'
readonly COLOR_BOLD_YELLOW=$'\033[1;33m'
readonly COLOR_BOLD_BLUE=$'\033[1;34m'
readonly COLOR_BOLD_MAGENTA=$'\033[1;35m'
readonly COLOR_BOLD_CYAN=$'\033[1;36m'
readonly COLOR_BOLD_WHITE=$'\033[1;37m'

readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARNING=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_SUCCESS=4

DEFAULT_LOG_LEVEL=$LOG_LEVEL_INFO
DEFAULT_TIMESTAMP_FORMAT='%Y-%m-%d %H:%M:%S'
DEFAULT_LOG_FILE=""
DEFAULT_SHOW_TIMESTAMP=true
DEFAULT_SHOW_LEVEL=true
DEFAULT_USE_COLOR=true

CURRENT_LOG_LEVEL=$DEFAULT_LOG_LEVEL
CURRENT_LOG_FILE=$DEFAULT_LOG_FILE

_GetLogLevelName() {
    local level="${1:-}"
    case "$level" in
        $LOG_LEVEL_DEBUG) echo "DEBUG" ;;
        $LOG_LEVEL_INFO) echo "INFO" ;;
        $LOG_LEVEL_WARNING) echo "WARNING" ;;
        $LOG_LEVEL_ERROR) echo "ERROR" ;;
        $LOG_LEVEL_SUCCESS) echo "SUCCESS" ;;
        *) echo "UNKNOWN" ;;
    esac
}

_GetLogLevelNumber() {
    local level_name="${1:-}"
    level_name="${level_name^^}"
    case "$level_name" in
        DEBUG) echo $LOG_LEVEL_DEBUG ;;
        INFO) echo $LOG_LEVEL_INFO ;;
        WARNING|WARN) echo $LOG_LEVEL_WARNING ;;
        ERROR) echo $LOG_LEVEL_ERROR ;;
        SUCCESS) echo $LOG_LEVEL_SUCCESS ;;
        *) echo $LOG_LEVEL_INFO ;;
    esac
}

_SupportsColor() {
    local color_count
    color_count=$(tput colors 2>/dev/null || true)
    if [[ -t 1 ]] && [[ "$color_count" =~ ^[0-9]+$ ]] && [[ "$color_count" -ge 8 ]]; then
        return 0
    fi
    return 1
}

GetTimestamp() {
    local format="${1:-$DEFAULT_TIMESTAMP_FORMAT}"
    date +"$format"
}

Logger() {
    local log_type=""
    local log_message=""
    local show_timestamp=$DEFAULT_SHOW_TIMESTAMP
    local use_color=$DEFAULT_USE_COLOR
    local log_file="$CURRENT_LOG_FILE"
    local use_bold=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -type|--type)
                if [[ $# -lt 2 ]]; then
                    printf 'Error: %s requires a value\n' "$1" >&2
                    return 1
                fi
                log_type="$2"
                shift 2
                ;;
            -message|--message)
                if [[ $# -lt 2 ]]; then
                    printf 'Error: %s requires a value\n' "$1" >&2
                    return 1
                fi
                log_message="$2"
                shift 2
                ;;
            -no-timestamp|--no-timestamp)
                show_timestamp=false
                shift
                ;;
            -no-color|--no-color)
                use_color=false
                shift
                ;;
            -file|--file)
                if [[ $# -lt 2 ]]; then
                    printf 'Error: %s requires a value\n' "$1" >&2
                    return 1
                fi
                log_file="$2"
                shift 2
                ;;
            -bold|--bold)
                use_bold=true
                shift
                ;;
            *)
                printf 'Unknown parameter: %s\n' "$1" >&2
                return 1
                ;;
        esac
    done
    if [[ -z "$log_message" ]]; then
        printf '%s\n' 'Error: -message parameter is required' >&2
        return 1
    fi
    local level_number=$(_GetLogLevelNumber "$log_type")
    if [[ $level_number -lt $CURRENT_LOG_LEVEL ]]; then
        return 0
    fi
    local timestamp=""
    if [[ "$show_timestamp" == true ]]; then
        timestamp="[$(GetTimestamp)]"
    fi
    local color=""
    local reset=""
    if [[ "$use_color" == true ]] && _SupportsColor; then
        reset="$COLOR_RESET"
        case "${log_type^^}" in
            ERROR)
                color=$([ "$use_bold" == true ] && echo "$COLOR_BOLD_RED" || echo "$COLOR_RED")
                ;;
            SUCCESS)
                color=$([ "$use_bold" == true ] && echo "$COLOR_BOLD_GREEN" || echo "$COLOR_GREEN")
                ;;
            WARNING|WARN)
                color=$([ "$use_bold" == true ] && echo "$COLOR_BOLD_YELLOW" || echo "$COLOR_YELLOW")
                ;;
            INFO)
                color=$([ "$use_bold" == true ] && echo "$COLOR_BOLD_CYAN" || echo "$COLOR_CYAN")
                ;;
            DEBUG)
                color=$([ "$use_bold" == true ] && echo "$COLOR_BOLD_MAGENTA" || echo "$COLOR_MAGENTA")
                ;;
            *)
                color=$([ "$use_bold" == true ] && echo "$COLOR_BOLD_WHITE" || echo "$COLOR_WHITE")
                ;;
        esac
    fi
    local level_tag=""
    if [[ -n "$log_type" ]]; then
        level_tag="[${log_type^^}]: "
    fi
    local output="${color}${timestamp} - ${level_tag}${log_message}${reset}"
    if [[ "${log_type^^}" == "ERROR" ]]; then
        printf '%s\n' "$output" >&2
    else
        printf '%s\n' "$output"
    fi
    if [[ -n "$log_file" ]]; then
        local plain_output="${timestamp} - ${level_tag}${log_message}"
        if ! printf '%s\n' "$plain_output" >> "$log_file" 2>/dev/null; then
            printf '%s\n' 'Error: Failed to write log file' >&2
            return 1
        fi
    fi
    return 0
}

LogDebug() {
    local message="${1:-}"
    local file="${2:-$CURRENT_LOG_FILE}"
    local logger_args=(-type "DEBUG" -message "$message")
    [[ -n "$file" ]] && logger_args+=(-file "$file")
    Logger "${logger_args[@]}"
}

LogInfo() {
    local message="${1:-}"
    local file="${2:-$CURRENT_LOG_FILE}"
    local logger_args=(-type "INFO" -message "$message")
    [[ -n "$file" ]] && logger_args+=(-file "$file")
    Logger "${logger_args[@]}"
}

LogWarning() {
    local message="${1:-}"
    local file="${2:-$CURRENT_LOG_FILE}"
    local logger_args=(-type "WARNING" -message "$message")
    [[ -n "$file" ]] && logger_args+=(-file "$file")
    Logger "${logger_args[@]}"
}

LogError() {
    local message="${1:-}"
    local file="${2:-$CURRENT_LOG_FILE}"
    local logger_args=(-type "ERROR" -message "$message")
    [[ -n "$file" ]] && logger_args+=(-file "$file")
    Logger "${logger_args[@]}"
}

LogSuccess() {
    local message="${1:-}"
    local file="${2:-$CURRENT_LOG_FILE}"
    local logger_args=(-type "SUCCESS" -message "$message")
    [[ -n "$file" ]] && logger_args+=(-file "$file")
    Logger "${logger_args[@]}"
}

SetLogLevel() {
    local level_name="${1:-}"
    level_name="${level_name^^}"
    CURRENT_LOG_LEVEL=$(_GetLogLevelNumber "$level_name")
    LogDebug "Log level set to: $level_name"
}

SetLogFile() {
    local file_path="${1:-}"
    if [[ -z "$file_path" ]]; then
        CURRENT_LOG_FILE=""
        return 0
    fi
    local log_dir
    if ! log_dir=$(dirname -- "$file_path"); then
        printf 'Error: Failed to determine log directory: %s\n' "$file_path" >&2
        return 1
    fi
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null
        if [[ ! -d "$log_dir" ]]; then
            LogError "Failed to create log directory: $log_dir"
            return 1
        fi
    fi
    local previous_log_file="$CURRENT_LOG_FILE"
    CURRENT_LOG_FILE="$file_path"
    if ! LogInfo "Log file set to: $file_path"; then
        CURRENT_LOG_FILE="$previous_log_file"
        return 1
    fi
    return 0
}

_RepeatCharacter() {
    local character="${1:-}"
    local count="${2:-}"
    if [[ ! "$count" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    count=$((10#$count))
    if [[ "$count" -eq 0 ]]; then
        return 0
    fi
    local blank_line
    printf -v blank_line '%*s' "$count" ''
    printf '%s' "${blank_line// /$character}"
}

LogSeparator() {
    local char="${1:-=}"
    local width="${2:-60}"
    local color_name="${3:-GRAY}"
    color_name="${color_name^^}"
    if [[ ! "$color_name" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
        color_name="GRAY"
    fi
    local color_var="COLOR_${color_name}"
    local color=""
    local reset=""
    if [[ "$DEFAULT_USE_COLOR" == true ]] && _SupportsColor; then
        color="${!color_var:-$COLOR_GRAY}"
        reset="$COLOR_RESET"
    fi
    if [[ ! "$width" =~ ^[0-9]+$ ]]; then
        printf 'Error: width must be a non-negative integer\n' >&2
        return 1
    fi
    width=$((10#$width))
    local line
    line=$(_RepeatCharacter "$char" "$width") || return 1
    printf '%s%s%s\n' "$color" "$line" "$reset"
}

LogHeader() {
    local title="${1:-}"
    local width="${2:-60}"
    if [[ ! "$width" =~ ^[0-9]+$ ]]; then
        printf 'Error: width must be a non-negative integer\n' >&2
        return 1
    fi
    width=$((10#$width))
    local line
    line=$(_RepeatCharacter '=' "$width") || return 1
    local left_padding=$(( (width - ${#title}) / 2 ))
    (( left_padding < 0 )) && left_padding=0
    local right_padding=$(( width - ${#title} - left_padding ))
    (( right_padding < 0 )) && right_padding=0
    local color=""
    local reset=""
    if [[ "$DEFAULT_USE_COLOR" == true ]] && _SupportsColor; then
        color="$COLOR_BOLD_CYAN"
        reset="$COLOR_RESET"
    fi
    printf '%s%s%s\n' "$color" "$line" "$reset"
    printf '%s%*s%s%*s%s\n' "$color" "$left_padding" '' "$title" "$right_padding" '' "$reset"
    printf '%s%s%s\n' "$color" "$line" "$reset"
}

LogIndent() {
    local indent_level="${1:-}"
    local message="${2:-}"
    local log_type="${3:-INFO}"
    if [[ ! "$indent_level" =~ ^[0-9]+$ ]]; then
        printf 'Error: indent_level must be a non-negative integer\n' >&2
        return 1
    fi
    indent_level=$((10#$indent_level))
    local indent
    indent=$(_RepeatCharacter ' ' "$((indent_level * 2))") || return 1
    Logger -type "$log_type" -message "${indent}${message}"
}

LogKeyValue() {
    local key="${1:-}"
    local value="${2:-}"
    local log_type="${3:-INFO}"
    Logger -type "$log_type" -message "${key}: ${value}"
}

LogArray() {
    if [[ $# -lt 1 || ! "$1" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        printf 'Error: array variable name is required\n' >&2
        return 1
    fi
    local -n arr="$1"
    local log_type="${2:-INFO}"
    local index=0
    local item
    for item in "${arr[@]}"; do
        if ! Logger -type "$log_type" -message "  [$index] $item"; then
            return 1
        fi
        index=$((index + 1))
    done
    return 0
}

LogCommand() {
    local command="${1:-}"
    local show_output="${2:-false}"
    if [[ -z "$command" ]]; then
        printf 'Error: command parameter is required\n' >&2
        return 1
    fi
    LogInfo "Executing: $command"
    if [[ "$show_output" == "true" ]]; then
        eval "$command" 2>&1 | while IFS= read -r line; do
            LogDebug "  $line"
        done
        local exit_code=${PIPESTATUS[0]}
    else
        eval "$command" &>/dev/null
        local exit_code=$?
    fi
    if [[ $exit_code -eq 0 ]]; then
        LogSuccess "Command completed successfully"
    else
        LogError "Command failed with exit code: $exit_code"
    fi
    return $exit_code
}

export -f _GetLogLevelName
export -f _GetLogLevelNumber
export -f _SupportsColor
export -f _RepeatCharacter
export -f GetTimestamp
export -f Logger
export -f LogDebug
export -f LogInfo
export -f LogWarning
export -f LogError
export -f LogSuccess
export -f SetLogLevel
export -f SetLogFile
export -f LogSeparator
export -f LogHeader
export -f LogIndent
export -f LogKeyValue
export -f LogArray
export -f LogCommand

export DEFAULT_LOG_LEVEL DEFAULT_TIMESTAMP_FORMAT DEFAULT_LOG_FILE
export DEFAULT_SHOW_TIMESTAMP DEFAULT_SHOW_LEVEL DEFAULT_USE_COLOR
export CURRENT_LOG_LEVEL CURRENT_LOG_FILE
export COLOR_RESET COLOR_RED COLOR_GREEN COLOR_YELLOW COLOR_BLUE COLOR_MAGENTA COLOR_CYAN COLOR_WHITE COLOR_GRAY
export COLOR_BOLD_RED COLOR_BOLD_GREEN COLOR_BOLD_YELLOW COLOR_BOLD_BLUE COLOR_BOLD_MAGENTA COLOR_BOLD_CYAN COLOR_BOLD_WHITE
