function InvokeLocalShellScript {
  param (
    [Parameter(Mandatory = $true)]
    [string]$script_name,
    [string[]]$script_arguments = @()
  )
  $script_path = "$ENV:USERPROFILE\appdata\local\script\$script_name"
  $unix_path = $script_path -replace '\\', '/' -replace '^([A-Z]):', '/$1'
  $unix_path = $unix_path.ToLower()
  & sh $unix_path @script_arguments
}

function cleanup_directories {
  InvokeLocalShellScript -script_name "cleanup-directories.sh" -script_arguments $args
}

function get_open_with_manager {
  InvokeLocalShellScript -script_name "get-open-with-manager.sh" -script_arguments $args
}

function ide {
  InvokeLocalShellScript -script_name "ide.sh" -script_arguments $args
}

function initialize_command_history {
  InvokeLocalShellScript -script_name "initialize-command-history.sh" -script_arguments $args
}

function reinstall_anydesk {
  InvokeLocalShellScript -script_name "reinstall-anydesk.sh" -script_arguments $args
}

function resize_dock {
  InvokeLocalShellScript -script_name "resize-dock.sh" -script_arguments $args
}

function sort_command_history {
  InvokeLocalShellScript -script_name "sort-command-history.sh" -script_arguments $args
}

function ssh_key_manager {
  InvokeLocalShellScript -script_name "ssh-key-manager.sh" -script_arguments $args
}

function video_transcription {
  InvokeLocalShellScript -script_name "video-transcription.sh" -script_arguments $args
}

function youtube_downloader {
  InvokeLocalShellScript -script_name "youtube-downloader.sh" -script_arguments $args
}

export-modulemember -function @(
  'cleanup_directories',
  'get_open_with_manager',
  'ide',
  'initialize_command_history',
  'reinstall_anydesk',
  'resize_dock',
  'sort_command_history',
  'ssh_key_manager',
  'video_transcription',
  'youtube_downloader'
)
