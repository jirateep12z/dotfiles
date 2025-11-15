#!/usr/bin/env bash

readonly COLOR_RESET='\033[0;00m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[0;37m'
readonly COLOR_GRAY='\033[0;90m'

readonly COLOR_BOLD_RED='\033[1;31m'
readonly COLOR_BOLD_GREEN='\033[1;32m'
readonly COLOR_BOLD_YELLOW='\033[1;33m'
readonly COLOR_BOLD_BLUE='\033[1;34m'
readonly COLOR_BOLD_MAGENTA='\033[1;35m'
readonly COLOR_BOLD_CYAN='\033[1;36m'
readonly COLOR_BOLD_WHITE='\033[1;37m'

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
    local level="$1"
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
    local level_name="${1^^}"
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
    if [[ -t 1 ]] && command -v tput &> /dev/null && [[ $(tput colors 2>/dev/null) -ge 8 ]]; then
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
                log_type="$2"
                shift 2
                ;;
            -message|--message)
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
                log_file="$2"
                shift 2
                ;;
            -bold|--bold)
                use_bold=true
                shift
                ;;
            *)
                echo -e "${COLOR_RED}Unknown parameter: $1${COLOR_RESET}" >&2
                return 1
                ;;
        esac
    done
    if [[ -z "$log_message" ]]; then
        echo -e "${COLOR_RED}Error: -message parameter is required${COLOR_RESET}" >&2
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
        echo -e "$output" >&2
    else
        echo -e "$output"
    fi
    if [[ -n "$log_file" ]]; then
        local plain_output="${timestamp} - ${level_tag}${log_message}"
        echo "$plain_output" >> "$log_file" 2>/dev/null
    fi
    return 0
}

LogDebug() {
    local message="$1"
    local file="${2:-$CURRENT_LOG_FILE}"
    Logger -type "DEBUG" -message "$message" ${file:+-file "$file"}
}

LogInfo() {
    local message="$1"
    local file="${2:-$CURRENT_LOG_FILE}"
    Logger -type "INFO" -message "$message" ${file:+-file "$file"}
}

LogWarning() {
    local message="$1"
    local file="${2:-$CURRENT_LOG_FILE}"
    Logger -type "WARNING" -message "$message" ${file:+-file "$file"}
}

LogError() {
    local message="$1"
    local file="${2:-$CURRENT_LOG_FILE}"
    Logger -type "ERROR" -message "$message" ${file:+-file "$file"}
}

LogSuccess() {
    local message="$1"
    local file="${2:-$CURRENT_LOG_FILE}"
    Logger -type "SUCCESS" -message "$message" ${file:+-file "$file"}
}

SetLogLevel() {
    local level_name="${1^^}"
    CURRENT_LOG_LEVEL=$(_GetLogLevelNumber "$level_name")
    LogDebug "Log level set to: $level_name"
}

SetLogFile() {
    local file_path="$1"
    if [[ -z "$file_path" ]]; then
        CURRENT_LOG_FILE=""
        return 0
    fi
    local log_dir=$(dirname "$file_path")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null
        if [[ ! -d "$log_dir" ]]; then
            LogError "Failed to create log directory: $log_dir"
            return 1
        fi
    fi
    CURRENT_LOG_FILE="$file_path"
    LogInfo "Log file set to: $file_path"
    return 0
}

LogSeparator() {
    local char="${1:-=}"
    local width="${2:-60}"
    local color_name="${3:-GRAY}"
    local color_var="COLOR_${color_name^^}"
    local color="${!color_var:-$COLOR_GRAY}"
    local line=$(printf "%${width}s" | tr ' ' "$char")
    echo -e "${color}${line}${COLOR_RESET}"
}

LogHeader() {
    local title="$1"
    local width="${2:-60}"
    local line=$(printf "%${width}s" | tr ' ' "=")
    echo -e "${COLOR_BOLD_CYAN}${line}${COLOR_RESET}"
    printf "${COLOR_BOLD_CYAN}%*s%s%*s${COLOR_RESET}\n" $(((width - ${#title}) / 2)) "" "$title" $(((width - ${#title} + 1) / 2)) ""
    echo -e "${COLOR_BOLD_CYAN}${line}${COLOR_RESET}"
}

LogIndent() {
    local indent_level="$1"
    local message="$2"
    local log_type="${3:-INFO}"
    local indent=$(printf "%$((indent_level * 2))s" "")
    Logger -type "$log_type" -message "${indent}${message}"
}

LogKeyValue() {
    local key="$1"
    local value="$2"
    local log_type="${3:-INFO}"
    Logger -type "$log_type" -message "${key}: ${value}"
}

LogArray() {
    local -n arr=$1
    local log_type="${2:-INFO}"
    local index=0
    for item in "${arr[@]}"; do
        Logger -type "$log_type" -message "  [$index] $item"
        ((index++))
    done
}

LogCommand() {
    local command="$1"
    local show_output="${2:-false}"
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