set -g LOG_LEVEL_DEBUG 0
set -g LOG_LEVEL_INFO 1
set -g LOG_LEVEL_WARNING 2
set -g LOG_LEVEL_ERROR 3
set -g LOG_LEVEL_SUCCESS 4

set -g CURRENT_LOG_LEVEL $LOG_LEVEL_INFO
set -g DEFAULT_TIMESTAMP_FORMAT "+%Y-%m-%d %H:%M:%S"

function GetTimestamp
  set format $argv[1]
  if test -z "$format"
    set format $DEFAULT_TIMESTAMP_FORMAT
  end
  date "$format"
end

function GetLogLevelNumber
  set level_name (string upper "$argv[1]")
  switch $level_name
    case DEBUG
      echo $LOG_LEVEL_DEBUG
    case INFO
      echo $LOG_LEVEL_INFO
    case WARNING WARN
      echo $LOG_LEVEL_WARNING
    case ERROR
      echo $LOG_LEVEL_ERROR
    case SUCCESS
      echo $LOG_LEVEL_SUCCESS
    case '*'
      echo $LOG_LEVEL_INFO
  end
end

function Logger
  set log_type ""
  set log_message ""
  set index 1
  while test $index -le (count $argv)
    set current_arg $argv[$index]
    switch $current_arg
      case --type -type
        set index (math $index + 1)
        set log_type $argv[$index]
      case --message -message
        set index (math $index + 1)
        set log_message $argv[$index]
      case '*'
        echo "Unknown parameter: $current_arg" >&2
        return 1
    end
    set index (math $index + 1)
  end

  if test -z "$log_message"
    echo "Error: --message parameter is required" >&2
    return 1
  end

  set level_number (GetLogLevelNumber "$log_type")
  if test "$level_number" -lt "$CURRENT_LOG_LEVEL"
    return 0
  end

  set timestamp (GetTimestamp)
  set level_tag ""
  if test -n "$log_type"
    set level_tag "["(string upper "$log_type")"]: "
  end

  set output "[$timestamp] - $level_tag$log_message"
  if test (string upper "$log_type") = ERROR
    echo "$output" >&2
  else
    echo "$output"
  end
end

function LogDebug
  Logger --type DEBUG --message "$argv[1]"
end

function LogInfo
  Logger --type INFO --message "$argv[1]"
end

function LogWarning
  Logger --type WARNING --message "$argv[1]"
end

function LogError
  Logger --type ERROR --message "$argv[1]"
end

function LogSuccess
  Logger --type SUCCESS --message "$argv[1]"
end

function SetLogLevel
  set -g CURRENT_LOG_LEVEL (GetLogLevelNumber "$argv[1]")
end
