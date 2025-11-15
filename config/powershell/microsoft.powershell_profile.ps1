[console]::inputencoding = [console]::outputencoding = new-object system.text.utf8encoding

if (test-path alias:where) {
  remove-item alias:where -force
}

$profile_omp = "$PSSCRIPTROOT/jirateep12_black.omp.json"
oh-my-posh init pwsh --config $profile_omp | invoke-expression

import-module command-history
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

function which ($command) {
  get-command -name $command -erroraction silentlycontinue | select-object -expandproperty definition -erroraction silentlycontinue
}
