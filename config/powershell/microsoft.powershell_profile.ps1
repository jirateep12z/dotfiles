[console]::inputencoding = [console]::outputencoding = new-object system.text.utf8encoding

if (test-path alias:where) {
  remove-item alias:where -force
}

$profile_omp = "$PSSCRIPTROOT/jirateep12_black.omp.json"
oh-my-posh init pwsh --config $profile_omp | invoke-expression

set-psreadlinekeyhandler -chord "enter" -function validateandacceptline
set-psreadlinekeyhandler -chord "enter" -scriptblock {
  sh "$ENV:USERPROFILE\AppData\Local\script\sort-command-history.sh" -f -q
  [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}
set-psreadlineoption -editmode emacs -bellstyle none

set-alias grep "findstr"
set-alias py "python3"
set-alias pip "pip3"
set-alias vim "nvim"
set-alias g "git"
set-alias lg "lazygit"
set-alias tig "$ENV:USERPROFILE\scoop\apps\git\current\usr\bin\tig.exe"
set-alias less "$ENV:USERPROFILE\scoop\apps\git\current\usr\bin\less.exe"

function ls() {
  eza -g --icons
}

function la() {
  eza -g --icons -a
}

function ll() {
  eza -l -g --icons
}

function lla() {
  eza -l -g --icons -a
}

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

function where ($command) {
  get-command -name $command -erroraction silentlycontinue | select-object -expandproperty definition -erroraction silentlycontinue
}
