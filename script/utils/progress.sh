#!/usr/bin/env bash

DEFAULT_PROGRESS_WIDTH=50
DEFAULT_PROGRESS_FILL_CHAR="█"
DEFAULT_PROGRESS_EMPTY_CHAR="░"
DEFAULT_PROGRESS_FILL_CHAR_WIN="#"
DEFAULT_PROGRESS_EMPTY_CHAR_WIN="-"
DEFAULT_SPINNER_DELAY=0.1
DEFAULT_BOX_WIDTH=60

readonly SPINNER_STYLE_DEFAULT='|/-\'
readonly SPINNER_STYLE_DOTS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
readonly SPINNER_STYLE_ARROWS='←↖↑↗→↘↓↙'
readonly SPINNER_STYLE_CIRCLE='◐◓◑◒'
readonly SPINNER_STYLE_BOUNCE='⠁⠂⠄⡀⢀⠠⠐⠈'

_SupportsUnicode() {
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    return 1
  fi
  if [[ -n "$LC_ALL" ]] && [[ "$LC_ALL" == *"UTF-8"* ]]; then
    return 0
  fi
  return 1
}

_GetTerminalWidth() {
  if command -v tput &> /dev/null; then
    tput cols 2>/dev/null || echo 80
  else
    echo 80
  fi
}

ShowProgress() {
  local current="$1"
  local total="$2"
  local item_name="${3:-}"
  local show_progress="${4:-true}"
  local width="${5:-$DEFAULT_PROGRESS_WIDTH}"
  local style="${6:-detailed}"
  if [[ "$show_progress" != "true" ]]; then
    return 0
  fi
  if [[ -z "$current" || -z "$total" ]]; then
    return 1
  fi
  if [[ "$total" -eq 0 ]]; then
    return 0
  fi
  local percent=$((current * 100 / total))
  local filled=$((percent * width / 100))
  local empty=$((width - filled))
  local fill_char="$DEFAULT_PROGRESS_FILL_CHAR"
  local empty_char="$DEFAULT_PROGRESS_EMPTY_CHAR"
  if ! _SupportsUnicode; then
    fill_char="$DEFAULT_PROGRESS_FILL_CHAR_WIN"
    empty_char="$DEFAULT_PROGRESS_EMPTY_CHAR_WIN"
  fi
  case "$style" in
    simple)
      printf "\r[%3d%%] %s" "$percent" "$item_name"
      ;;
    minimal)
      printf "\r%3d%%" "$percent"
      ;;
    detailed|*)
      printf "\r["
      printf "%${filled}s" | tr ' ' "$fill_char"
      printf "%${empty}s" | tr ' ' "$empty_char"
      printf "] %3d%% (%d/%d)" "$percent" "$current" "$total"
      if [[ -n "$item_name" ]]; then
        printf " %s" "$item_name"
      fi
      ;;
  esac
  return 0
}

ClearProgress() {
  local show_progress="${1:-true}"
  local clear_line="${2:-false}"
  if [[ "$show_progress" == "true" ]]; then
    if [[ "$clear_line" == "true" ]]; then
      printf "\r%80s\r" ""
    else
      echo ""
    fi
  fi
}

ShowSpinner() {
  local pid=$1
  local message="${2:-Processing...}"
  local style="${3:-default}"
  local delay="${4:-$DEFAULT_SPINNER_DELAY}"
  if [[ -z "$pid" ]]; then
    return 1
  fi
  local spinstr="$SPINNER_STYLE_DEFAULT"
  case "$style" in
    dots) spinstr="$SPINNER_STYLE_DOTS" ;;
    arrows) spinstr="$SPINNER_STYLE_ARROWS" ;;
    circle) spinstr="$SPINNER_STYLE_CIRCLE" ;;
    bounce) spinstr="$SPINNER_STYLE_BOUNCE" ;;
  esac
  if ! _SupportsUnicode && [[ "$style" != "default" ]]; then
    spinstr="$SPINNER_STYLE_DEFAULT"
  fi
  while ps -p $pid > /dev/null 2>&1; do
    local temp=${spinstr#?}
    printf "\r[%c] %s" "$spinstr" "$message"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
  done
  wait $pid
  local exit_code=$?
  printf "\r%80s\r" ""
  return $exit_code
}

ShowSpinnerWithTime() {
  local pid=$1
  local message="${2:-Processing...}"
  local start_time=$(date +%s)
  local spinstr='|/-\'
  while ps -p $pid > /dev/null 2>&1; do
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    local temp=${spinstr#?}
    printf "\r[%c] %s (Elapsed: %ds)" "$spinstr" "$message" "$elapsed"
    local spinstr=$temp${spinstr%"$temp"}
    sleep 0.1
  done
  wait $pid
  local exit_code=$?
  local end_time=$(date +%s)
  local total_elapsed=$((end_time - start_time))
  printf "\r%80s\r" ""
  printf "Completed in %ds\n" "$total_elapsed"
  return $exit_code
}

DrawBox() {
  local title="$1"
  local width="${2:-$DEFAULT_BOX_WIDTH}"
  local style="${3:-double}"
  local color="${4:-}"
  local reset="\033[0m"
  local top_left="╔"
  local top_right="╗"
  local bottom_left="╚"
  local bottom_right="╝"
  local horizontal="═"
  local vertical="║"
  if [[ "$style" == "single" ]] && _SupportsUnicode; then
    top_left="┌"
    top_right="┐"
    bottom_left="└"
    bottom_right="┘"
    horizontal="─"
    vertical="│"
  elif [[ "$style" == "ascii" ]] || ! _SupportsUnicode; then
    top_left="+"
    top_right="+"
    bottom_left="+"
    bottom_right="+"
    horizontal="-"
    vertical="|"
  fi
  local horizontal_line=$(printf "%${width}s" | tr ' ' "$horizontal")
  echo -e "${color}${top_left}${horizontal_line}${top_right}${reset}"
  printf "${color}${vertical}%*s%s%*s${vertical}${reset}\n" $(((width - ${#title}) / 2)) "" "$title" $(((width - ${#title} + 1) / 2)) ""
  echo -e "${color}${bottom_left}${horizontal_line}${bottom_right}${reset}"
}

DrawLine() {
  local char="${1:-═}"
  local width="${2:-$DEFAULT_BOX_WIDTH}"
  local color="${3:-}"
  local reset="\033[0m"
  if ! _SupportsUnicode; then
    case "$char" in
      "═"|"─"|"━") char="-" ;;
      "║"|"│"|"┃") char="|" ;;
    esac
  fi
  local line=$(printf "%${width}s" | tr ' ' "$char")
  echo -e "${color}${line}${reset}"
}

ShowPercentage() {
  local current="$1"
  local total="$2"
  local decimals="${3:-0}"
  if [[ -z "$current" || -z "$total" ]]; then
    echo "0%"
    return 1
  fi
  if [[ "$total" -eq 0 ]]; then
    echo "0%"
    return 0
  fi
  if [[ "$decimals" -eq 0 ]]; then
    local percent=$((current * 100 / total))
    echo "${percent}%"
  else
    local percent=$(awk "BEGIN {printf \"%.${decimals}f\", ($current * 100 / $total)}")
    echo "${percent}%"
  fi
}

FormatBytes() {
  local bytes="$1"
  local precision="${2:-0}"
  if [[ -z "$bytes" ]]; then
    echo "0B"
    return 1
  fi
  if [[ "$bytes" -lt 1024 ]]; then
    echo "${bytes}B"
  elif [[ "$bytes" -lt 1048576 ]]; then
    if [[ "$precision" -gt 0 ]]; then
      echo "$(awk "BEGIN {printf \"%.${precision}f\", ($bytes / 1024)}")KB"
    else
      echo "$((bytes / 1024))KB"
    fi
  elif [[ "$bytes" -lt 1073741824 ]]; then
    if [[ "$precision" -gt 0 ]]; then
      echo "$(awk "BEGIN {printf \"%.${precision}f\", ($bytes / 1048576)}")MB"
    else
      echo "$((bytes / 1048576))MB"
    fi
  else
    if [[ "$precision" -gt 0 ]]; then
      echo "$(awk "BEGIN {printf \"%.${precision}f\", ($bytes / 1073741824)}")GB"
    else
      echo "$((bytes / 1073741824))GB"
    fi
  fi
}

FormatDuration() {
  local seconds="$1"
  local style="${2:-short}"
  if [[ -z "$seconds" ]]; then
    echo "0s"
    return 1
  fi
  local days=$((seconds / 86400))
  local hours=$(((seconds % 86400) / 3600))
  local minutes=$(((seconds % 3600) / 60))
  local secs=$((seconds % 60))
  case "$style" in
    long)
      local result=""
      [[ $days -gt 0 ]] && result="${days} day(s) "
      [[ $hours -gt 0 ]] && result="${result}${hours} hour(s) "
      [[ $minutes -gt 0 ]] && result="${result}${minutes} minute(s) "
      [[ $secs -gt 0 || -z "$result" ]] && result="${result}${secs} second(s)"
      echo "$result"
      ;;
    compact)
      if [[ $days -gt 0 ]]; then
        echo "${days}d${hours}h"
      elif [[ $hours -gt 0 ]]; then
        echo "${hours}h${minutes}m"
      elif [[ $minutes -gt 0 ]]; then
        echo "${minutes}m${secs}s"
      else
        echo "${secs}s"
      fi
      ;;
    short|*)
      if [[ $seconds -lt 60 ]]; then
        echo "${seconds}s"
      elif [[ $seconds -lt 3600 ]]; then
        echo "$((seconds / 60))m $((seconds % 60))s"
      elif [[ $seconds -lt 86400 ]]; then
        echo "$((seconds / 3600))h $((seconds % 3600 / 60))m"
      else
        echo "${days}d ${hours}h"
      fi
      ;;
  esac
}

ShowTableHeader() {
  local -a columns=("$@")
  local total_width=0
  local col_width=20
  printf "┌"
  for col in "${columns[@]}"; do
    printf "%${col_width}s" | tr ' ' "─"
    printf "┬"
  done
  printf "\b┐\n"
  printf "│"
  for col in "${columns[@]}"; do
    printf " %-$((col_width - 1))s│" "$col"
  done
  printf "\n"
  printf "├"
  for col in "${columns[@]}"; do
    printf "%${col_width}s" | tr ' ' "─"
    printf "┼"
  done
  printf "\b┤\n"
}

ShowTableRow() {
  local -a values=("$@")
  local col_width=20
  printf "│"
  for val in "${values[@]}"; do
    printf " %-$((col_width - 1))s│" "$val"
  done
  printf "\n"
}

ShowTableFooter() {
  local col_count="$1"
  local col_width=20
  printf "└"
  for ((i=0; i<col_count; i++)); do
    printf "%${col_width}s" | tr ' ' "─"
    [[ $i -lt $((col_count - 1)) ]] && printf "┴" || printf "┘"
  done
  printf "\n"
}

export -f ShowProgress
export -f ClearProgress
export -f ShowSpinner
export -f ShowSpinnerWithTime
export -f DrawBox
export -f DrawLine
export -f ShowPercentage
export -f FormatBytes
export -f FormatDuration
export -f ShowTableHeader
export -f ShowTableRow
export -f ShowTableFooter