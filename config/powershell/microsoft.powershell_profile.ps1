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
set-alias wind "windsurf"
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

function cleanup_directories {
  $script_path = "$ENV:USERPROFILE\appdata\local\script\cleanup-directories.sh"
  $unix_path = $script_path -replace '\\', '/' -replace '^([A-Z]):', '/$1'
  $unix_path = $unix_path.ToLower()
  $arg_string = $args -join ' '
  sh -c "$unix_path $arg_string"
}

function get_open_with_manager {
  $script_path = "$ENV:USERPROFILE\appdata\local\script\get-open-with-manager.sh"
  $unix_path = $script_path -replace '\\', '/' -replace '^([A-Z]):', '/$1'
  $unix_path = $unix_path.ToLower()
  $arg_string = $args -join ' '
  sh -c "$unix_path $arg_string"
}

function ide {
  $script_path = "$ENV:USERPROFILE\appdata\local\script\ide.sh"
  $unix_path = $script_path -replace '\\', '/' -replace '^([A-Z]):', '/$1'
  $unix_path = $unix_path.ToLower()
  $arg_string = $args -join ' '
  sh -c "$unix_path $arg_string"
}

function initialize_command_history {
  $script_path = "$ENV:USERPROFILE\appdata\local\script\initialize-command-history.sh"
  $unix_path = $script_path -replace '\\', '/' -replace '^([A-Z]):', '/$1'
  $unix_path = $unix_path.ToLower()
  $arg_string = $args -join ' '
  sh -c "$unix_path $arg_string"
}

function resize_dock {
  $script_path = "$ENV:USERPROFILE\appdata\local\script\resize-dock.sh"
  $unix_path = $script_path -replace '\\', '/' -replace '^([A-Z]):', '/$1'
  $unix_path = $unix_path.ToLower()
  $arg_string = $args -join ' '
  sh -c "$unix_path $arg_string"
}

function sort_command_history {
  $script_path = "$ENV:USERPROFILE\appdata\local\script\sort-command-history.sh"
  $unix_path = $script_path -replace '\\', '/' -replace '^([A-Z]):', '/$1'
  $unix_path = $unix_path.ToLower()
  $arg_string = $args -join ' '
  sh -c "$unix_path $arg_string"
}

function youtube_downloader {
  $script_path = "$ENV:USERPROFILE\appdata\local\script\youtube-downloader.sh"
  $unix_path = $script_path -replace '\\', '/' -replace '^([A-Z]):', '/$1'
  $unix_path = $unix_path.ToLower()
  $arg_string = $args -join ' '
  sh -c "$unix_path $arg_string"
}

function where ($command) {
  get-command -name $command -erroraction silentlycontinue | select-object -expandproperty definition -erroraction silentlycontinue
}