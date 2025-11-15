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

_IsNonNegativeInteger() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

_IsNonNegativeNumber() {
  [[ "${1:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

_RepeatCharacter() {
  local character="${1:-}"
  local count="${2:-}"
  if ! _IsNonNegativeInteger "$count"; then
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

_SupportsUnicode() {
  if [[ "$OSTYPE" == msys* || "$OSTYPE" == mingw* || "$OSTYPE" == cygwin* || "$OSTYPE" == "win32" ]]; then
    return 1
  fi
  local locale_name="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
  if [[ "$locale_name" == *"UTF-8"* || "$locale_name" == *"utf8"* || "$locale_name" == *"UTF8"* ]]; then
    return 0
  fi
  return 1
}

_GetTerminalWidth() {
  if command -v tput &> /dev/null; then
    local terminal_width
    terminal_width=$(tput cols 2>/dev/null || true)
    if _IsNonNegativeInteger "$terminal_width" && [[ "$terminal_width" -gt 0 ]]; then
      printf '%s\n' "$terminal_width"
      return 0
    fi
  fi
  printf '80\n'
}

ShowProgress() {
  local current="${1:-}"
  local total="${2:-}"
  local item_name="${3:-}"
  local show_progress="${4:-true}"
  local width="${5:-$DEFAULT_PROGRESS_WIDTH}"
  local style="${6:-detailed}"
  if [[ "$show_progress" != "true" ]]; then
    return 0
  fi
  if ! _IsNonNegativeInteger "$current" || ! _IsNonNegativeInteger "$total" || ! _IsNonNegativeInteger "$width" || [[ "$width" -eq 0 ]]; then
    printf 'Error: current, total, and width must be positive or non-negative integers\n' >&2
    return 1
  fi
  current=$((10#$current))
  total=$((10#$total))
  width=$((10#$width))
  if [[ "$total" -eq 0 ]]; then
    return 0
  fi
  if [[ "$current" -gt "$total" ]]; then
    current="$total"
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
      printf '\r[%3d%%] %s' "$percent" "$item_name"
      ;;
    minimal)
      printf '\r%3d%%' "$percent"
      ;;
    detailed|*)
      local filled_line empty_line
      filled_line=$(_RepeatCharacter "$fill_char" "$filled") || return 1
      empty_line=$(_RepeatCharacter "$empty_char" "$empty") || return 1
      printf '\r[%s%s] %3d%% (%d/%d)' "$filled_line" "$empty_line" "$percent" "$current" "$total"
      if [[ -n "$item_name" ]]; then
        printf ' %s' "$item_name"
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
      local terminal_width
      terminal_width=$(_GetTerminalWidth)
      local blank_line
      blank_line=$(_RepeatCharacter ' ' "$terminal_width") || return 1
      printf '\r%s\r' "$blank_line"
    else
      printf '\n'
    fi
  fi
  return 0
}

ShowSpinner() {
  local pid="${1:-}"
  local message="${2:-Processing...}"
  local style="${3:-default}"
  local delay="${4:-$DEFAULT_SPINNER_DELAY}"
  if ! _IsNonNegativeInteger "$pid" || [[ "$pid" -eq 0 ]]; then
    printf 'Error: pid must be a positive integer\n' >&2
    return 1
  fi
  if ! _IsNonNegativeNumber "$delay"; then
    printf 'Error: delay must be a non-negative number\n' >&2
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
  while ps -p "$pid" > /dev/null 2>&1; do
    printf '\r[%s] %s' "${spinstr:0:1}" "$message"
    spinstr="${spinstr:1}${spinstr:0:1}"
    sleep "$delay"
  done
  wait "$pid"
  local exit_code=$?
  local terminal_width
  terminal_width=$(_GetTerminalWidth)
  local blank_line
  blank_line=$(_RepeatCharacter ' ' "$terminal_width") || return 1
  printf '\r%s\r' "$blank_line"
  return "$exit_code"
}

ShowSpinnerWithTime() {
  local pid="${1:-}"
  local message="${2:-Processing...}"
  if ! _IsNonNegativeInteger "$pid" || [[ "$pid" -eq 0 ]]; then
    printf 'Error: pid must be a positive integer\n' >&2
    return 1
  fi
  local start_time
  if ! start_time=$(date +%s); then
    return 1
  fi
  local spinstr='|/-\'
  while ps -p "$pid" > /dev/null 2>&1; do
    local current_time
    current_time=$(date +%s) || return 1
    local elapsed=$((current_time - start_time))
    printf '\r[%s] %s (Elapsed: %ds)' "${spinstr:0:1}" "$message" "$elapsed"
    spinstr="${spinstr:1}${spinstr:0:1}"
    sleep 0.1
  done
  wait "$pid"
  local exit_code=$?
  local end_time
  end_time=$(date +%s) || return 1
  local total_elapsed=$((end_time - start_time))
  local terminal_width
  terminal_width=$(_GetTerminalWidth)
  local blank_line
  blank_line=$(_RepeatCharacter ' ' "$terminal_width") || return 1
  printf '\r%s\r' "$blank_line"
  printf 'Completed in %ds\n' "$total_elapsed"
  return "$exit_code"
}

DrawBox() {
  local title="${1:-}"
  local width="${2:-$DEFAULT_BOX_WIDTH}"
  local style="${3:-double}"
  local color="${4:-}"
  if ! _IsNonNegativeInteger "$width" || [[ "$width" -eq 0 ]]; then
    printf 'Error: width must be a positive integer\n' >&2
    return 1
  fi
  width=$((10#$width))
  local reset=""
  [[ -n "$color" ]] && reset=$'\033[0m'
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
  local horizontal_line
  horizontal_line=$(_RepeatCharacter "$horizontal" "$width") || return 1
  local left_padding=$(( (width - ${#title}) / 2 ))
  (( left_padding < 0 )) && left_padding=0
  local right_padding=$(( width - ${#title} - left_padding ))
  (( right_padding < 0 )) && right_padding=0
  printf '%s%s%s%s\n' "$color" "$top_left" "$horizontal_line" "$top_right$reset"
  printf '%s%s%*s%s%*s%s%s\n' "$color" "$vertical" "$left_padding" '' "$title" "$right_padding" '' "$vertical" "$reset"
  printf '%s%s%s%s\n' "$color" "$bottom_left" "$horizontal_line" "$bottom_right$reset"
}

DrawLine() {
  local char="${1:-═}"
  local width="${2:-$DEFAULT_BOX_WIDTH}"
  local color="${3:-}"
  if [[ -z "$char" ]] || ! _IsNonNegativeInteger "$width"; then
    printf 'Error: char and width are required; width must be non-negative\n' >&2
    return 1
  fi
  width=$((10#$width))
  if ! _SupportsUnicode; then
    case "$char" in
      "═"|"─"|"━") char="-" ;;
      "║"|"│"|"┃") char="|" ;;
    esac
  fi
  local line
  line=$(_RepeatCharacter "$char" "$width") || return 1
  local reset=""
  [[ -n "$color" ]] && reset=$'\033[0m'
  printf '%s%s%s\n' "$color" "$line" "$reset"
}

ShowPercentage() {
  local current="${1:-}"
  local total="${2:-}"
  local decimals="${3:-0}"
  if ! _IsNonNegativeInteger "$current" || ! _IsNonNegativeInteger "$total" || ! _IsNonNegativeInteger "$decimals"; then
    printf '0%%\n'
    return 1
  fi
  current=$((10#$current))
  total=$((10#$total))
  decimals=$((10#$decimals))
  if [[ "$total" -eq 0 ]]; then
    printf '0%%\n'
    return 0
  fi
  if [[ "$current" -gt "$total" ]]; then
    current="$total"
  fi
  if [[ "$decimals" -eq 0 ]]; then
    local percent=$((current * 100 / total))
    printf '%s%%\n' "$percent"
  else
    local percent
    percent=$(awk -v current="$current" -v total="$total" -v decimals="$decimals" 'BEGIN {printf "%.*f", decimals, (current * 100 / total)}') || return 1
    printf '%s%%\n' "$percent"
  fi
  return 0
}

FormatBytes() {
  local bytes="${1:-}"
  local precision="${2:-0}"
  if ! _IsNonNegativeInteger "$bytes" || ! _IsNonNegativeInteger "$precision"; then
    printf '0B\n'
    return 1
  fi
  bytes=$((10#$bytes))
  precision=$((10#$precision))
  if [[ "$bytes" -lt 1024 ]]; then
    printf '%sB\n' "$bytes"
  elif [[ "$bytes" -lt 1048576 ]]; then
    if [[ "$precision" -gt 0 ]]; then
      awk -v bytes="$bytes" -v precision="$precision" 'BEGIN {printf "%.*fKB\n", precision, (bytes / 1024)}'
    else
      printf '%sKB\n' "$((bytes / 1024))"
    fi
  elif [[ "$bytes" -lt 1073741824 ]]; then
    if [[ "$precision" -gt 0 ]]; then
      awk -v bytes="$bytes" -v precision="$precision" 'BEGIN {printf "%.*fMB\n", precision, (bytes / 1048576)}'
    else
      printf '%sMB\n' "$((bytes / 1048576))"
    fi
  else
    if [[ "$precision" -gt 0 ]]; then
      awk -v bytes="$bytes" -v precision="$precision" 'BEGIN {printf "%.*fGB\n", precision, (bytes / 1073741824)}'
    else
      printf '%sGB\n' "$((bytes / 1073741824))"
    fi
  fi
}

FormatDuration() {
  local seconds="${1:-}"
  local style="${2:-short}"
  if ! _IsNonNegativeInteger "$seconds"; then
    printf '0s\n'
    return 1
  fi
  seconds=$((10#$seconds))
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
      printf '%s\n' "$result"
      ;;
    compact)
      if [[ $days -gt 0 ]]; then
        printf '%sd%sh\n' "$days" "$hours"
      elif [[ $hours -gt 0 ]]; then
        printf '%sh%sm\n' "$hours" "$minutes"
      elif [[ $minutes -gt 0 ]]; then
        printf '%sm%ss\n' "$minutes" "$secs"
      else
        printf '%ss\n' "$secs"
      fi
      ;;
    short|*)
      if [[ $seconds -lt 60 ]]; then
        printf '%ss\n' "$seconds"
      elif [[ $seconds -lt 3600 ]]; then
        printf '%sm %ss\n' "$((seconds / 60))" "$((seconds % 60))"
      elif [[ $seconds -lt 86400 ]]; then
        printf '%sh %sm\n' "$((seconds / 3600))" "$((seconds % 3600 / 60))"
      else
        printf '%sd %sh\n' "$days" "$hours"
      fi
      ;;
  esac
  return 0
}

ShowTableHeader() {
  local -a columns=("$@")
  local col_width=20
  local top_left='┌' top_right='┐' top_junction='┬'
  local middle_left='├' middle_right='┤' middle_junction='┼'
  local horizontal='─' vertical='│'
  if ! _SupportsUnicode; then
    top_left='+'; top_right='+'; top_junction='+'
    middle_left='+'; middle_right='+'; middle_junction='+'
    horizontal='-'; vertical='|'
  fi
  local horizontal_line
  horizontal_line=$(_RepeatCharacter "$horizontal" "$col_width") || return 1
  printf '%s' "$top_left"
  local column_index
  for ((column_index = 0; column_index < ${#columns[@]}; column_index++)); do
    printf '%s' "$horizontal_line"
    if [[ "$column_index" -lt $(( ${#columns[@]} - 1 )) ]]; then
      printf '%s' "$top_junction"
    else
      printf '%s' "$top_right"
    fi
  done
  printf '\n%s' "$vertical"
  for col in "${columns[@]}"; do
    printf ' %-19s%s' "$col" "$vertical"
  done
  printf '\n%s' "$middle_left"
  for ((column_index = 0; column_index < ${#columns[@]}; column_index++)); do
    printf '%s' "$horizontal_line"
    if [[ "$column_index" -lt $(( ${#columns[@]} - 1 )) ]]; then
      printf '%s' "$middle_junction"
    else
      printf '%s' "$middle_right"
    fi
  done
  printf '\n'
}

ShowTableRow() {
  local -a values=("$@")
  local vertical='│'
  ! _SupportsUnicode && vertical='|'
  printf '%s' "$vertical"
  for val in "${values[@]}"; do
    printf ' %-19s%s' "$val" "$vertical"
  done
  printf '\n'
}

ShowTableFooter() {
  local col_count="${1:-}"
  local col_width=20
  if ! _IsNonNegativeInteger "$col_count"; then
    printf 'Error: col_count must be a non-negative integer\n' >&2
    return 1
  fi
  col_count=$((10#$col_count))
  local left='└' right='┘' junction='┴' horizontal='─'
  if ! _SupportsUnicode; then
    left='+'; right='+'; junction='+'; horizontal='-'
  fi
  local horizontal_line
  horizontal_line=$(_RepeatCharacter "$horizontal" "$col_width") || return 1
  printf '%s' "$left"
  local column_index
  for ((column_index = 0; column_index < col_count; column_index++)); do
    printf '%s' "$horizontal_line"
    if [[ "$column_index" -lt $((col_count - 1)) ]]; then
      printf '%s' "$junction"
    else
      printf '%s' "$right"
    fi
  done
  printf '\n'
}

export -f _IsNonNegativeInteger
export -f _IsNonNegativeNumber
export -f _RepeatCharacter
export -f _SupportsUnicode
export -f _GetTerminalWidth
export DEFAULT_PROGRESS_WIDTH DEFAULT_PROGRESS_FILL_CHAR DEFAULT_PROGRESS_EMPTY_CHAR
export DEFAULT_PROGRESS_FILL_CHAR_WIN DEFAULT_PROGRESS_EMPTY_CHAR_WIN DEFAULT_SPINNER_DELAY DEFAULT_BOX_WIDTH
export SPINNER_STYLE_DEFAULT SPINNER_STYLE_DOTS SPINNER_STYLE_ARROWS SPINNER_STYLE_CIRCLE SPINNER_STYLE_BOUNCE

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
