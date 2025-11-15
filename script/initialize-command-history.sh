#!/usr/bin/env bash

if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Error: This script requires bash 4+ (detected: ${BASH_VERSION:-unknown}). On macOS: brew install bash" >&2
  exit 1
fi

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
if [[ ! -f "$UTILS_DIR/file.sh" || ! -f "$UTILS_DIR/logger.sh" || ! -f "$UTILS_DIR/progress.sh" ]]; then
  UTILS_DIR="$SCRIPT_DIR/../utils/shell"
fi
readonly UTILS_DIR
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SYSTEM_OS_TYPE="$(uname -s)"
readonly FISH_HISTORY_PATH="${HOME}/.local/share/fish/fish_history"
readonly POWERSHELL_HISTORY_PATH="${HOME}/AppData/Roaming/Microsoft/Windows/PowerShell/PSReadLine/ConsoleHost_history.txt"
readonly OS_PATTERN_SUPPORTED="^(Darwin|Linux|MINGW|MSYS|CYGWIN)"
readonly OS_PATTERN_UNIX="^(Darwin|Linux)"
readonly BACKUP_DIR="${HOME}/.history_backups"

source "$UTILS_DIR/file.sh" 2>/dev/null || {
  echo "Error: Cannot load file.sh utility" >&2
  exit 1
}
source "$UTILS_DIR/progress.sh" 2>/dev/null || {
  echo "Error: Cannot load progress.sh utility" >&2
  exit 1
}
source "$UTILS_DIR/logger.sh" 2>/dev/null || {
  echo "Error: Cannot load logger.sh utility" >&2
  exit 1
}

declare DRY_RUN=true
declare BACKUP_ENABLED=false
declare QUIET_MODE=false
declare command_prefix=""
declare history_file_path=""
declare backup_file_path=""

readonly DEFAULT_SHELL_COMMANDS='
pwd
cd
cd /
cd ~
cd ..
cd -
ls
ls -A
ls -l
ls -l -A
mkdir
mkdir -p
cat
tig
less
clear
rm
rm -rf
rm -rf "$(brew --cache)"
mv
mv -f
cp
cp -rf
touch
chmod
chmod +x
chmod -x
find
grep
ping
curl
ssh
ssh -T git@github.com
ssh -T git@gitlab.com
wsl
brew
brew list
brew list --cask
brew install
brew install --cas
brew uninstall
brew uninstall --cask
brew pin
brew unpin
brew upgrade
brew upgrade -g
brew cleanup
brew cleanup --prune all
scoop
scoop list
scoop install
scoop uninstall
scoop hold
scoop unhold
scoop update
scoop update -a
scoop cleanup
scoop cleanup -a
scoop cache rm
scoop cache rm -a
nvm
nvm list
nvm use
nvm install
nvm uninstall
npx
npx skills find
npx skills add
npx skills check
npx skills update
npm
npm init
npm list
npm list -g
npm install
npm install -g
npm install --force
npm install --legacy-peer-deps
npm update
npm update -g
npm uninstall
npm uninstall -g
npm cache clean
npm cache clean --force
npm run start
npm run dev
npm run build
npm run format
npm run lint
npm run lint:fix
bun
bun init
bun pm ls
bun install
bun add
bun update
bun remove
bun pm cache -reset
bun pm cache -reset --force
bun run start
bun run dev
bun run build
bun run format
bun run lint
bun run lint:fix
ncu
ncu -g
ncu -i
ncu -i --format group
ncu -i -g --format group
nest
nest new
nest generate
nest generate app
nest generate library
nest generate class
nest generate controller
nest generate decorator
nest generate filter
nest generate gateway
nest generate guard
nest generate interceptor
nest generate interface
nest generate middleware
nest generate module
nest generate pipe
nest generate provider
nest generate resolver
nest generate resource
nest generate service
nest start
nest build
ng
ng new
ng generate
ng generate application
ng generate library
ng generate class
ng generate component
ng generate directive
ng generate enum
ng generate guard
ng generate interceptor
ng generate interface
ng generate module
ng generate pipe
ng generate resolver
ng generate service
ng generate web-worker
ng serve
ng build
pip
pip list
pip install
pip install -r requirements.txt
pip uninstall
pip uninstall -r requirements.txt
pip install -U
pip install -U -r requirements.txt
pip freeze
pip freeze > requirements.txt
pip cache
pip cache purge
php
php artisan
php artisan make
php artisan make:controller
php artisan make:model
php artisan make:resource
php artisan make:middleware
php artisan make:seeder
php artisan make:request
php artisan make:migration
php artisan migrate
php artisan migrate:fresh
php artisan migrate:refresh
php artisan migrate:reset
php artisan migrate:rollback
php artisan migrate:status
php artisan db:seed
php artisan db:seed --class=
php artisan key:generate
php artisan storage:link
php artisan optimize
php artisan optimize:clear
php artisan serve
php artisan serve --port=
composer
composer install
composer update
composer require
composer remove
composer clear-cache
flutter
flutter doctor
flutter pub get
flutter pub upgrade
flutter clean
flutter run
flutter devices
flutter build apk
flutter build ios
flutter build web
dart
dart pub get
dart pub upgrade
docker
docker system
docker system df
docker system prune
docker system prune -a
docker system prune -a --volumes
docker compose
docker compose ps
docker compose ps -a
docker compose logs
docker compose logs -f
docker compose watch
docker compose up
docker compose up -d
docker compose up --build
docker compose up -d --build
docker compose down
docker compose down -v
docker compose down -v --remove-orphans
docker compose exec
git
git init
git clone
git clone git@github.com:
git clone https://github.com/
git status
git log
git diff
git show
git add
git reset
git reset --soft
git reset --soft HEAD~
git reset --mixed
git reset --mixed HEAD~
git reset --hard
git reset --hard HEAD~
git commit
git commit -m
git branch
git branch -a
git branch -d
git branch --merged
git branch --no-merged
git tag
git tag -l
git tag -a
git tag -d
git checkout
git checkout -b
git remote
git remote -v
git remote add origin
git remote remove origin
git remote set-url origin
git merge
git merge --abort
git merge --continue
git rebase
git rebase --abort
git rebase --continue
git rebase --interactive --root
git rebase --interactive HEAD~
git pull origin "$(git rev-parse --abbrev-ref HEAD)"
git pull origin "$(git rev-parse --abbrev-ref HEAD)" -r
git pull origin "$(git rev-parse --abbrev-ref HEAD)" --no-rebase
git push origin "$(git rev-parse --abbrev-ref HEAD)"
git push origin "$(git rev-parse --abbrev-ref HEAD)" -f
git push origin "$(git rev-parse --abbrev-ref HEAD)" --force-with-lease
git push origin --tags
git cz
lazygit
z
z -l
z -c
'

readonly CUSTOM_SHELL_COMMANDS='
ll
lla
cleanup_directories
cleanup_directories -f
get_open_with_manager
ide
reinstall_anydesk
reinstall_anydesk -f
reinstall_anydesk -f --native
reinstall_anydesk -f --no-reinstall
initialize_command_history
initialize_command_history -f
resize_dock
sort_command_history
sort_command_history -f
sort_command_history -s
ssh_key_manager
ssh_key_manager list
ssh_key_manager show
ssh_key_manager show github
ssh_key_manager show gitlab
ssh_key_manager copy github
ssh_key_manager copy gitlab
ssh_key_manager generate
ssh_key_manager generate -n github
ssh_key_manager generate -n gitlab
ssh_key_manager delete
ssh_key_manager fingerprint
ssh_key_manager fingerprint github
ssh_key_manager fingerprint gitlab
ssh_key_manager test git@github.com
ssh_key_manager test git@gitlab.com
ssh_key_manager add-agent github
ssh_key_manager add-agent gitlab
ssh_key_manager config-list
ssh_key_manager config-show
ssh_key_manager config-show github.com
ssh_key_manager config-show gitlab.com
ssh_key_manager config-add
ssh_key_manager config-add github.com
ssh_key_manager config-add gitlab.com
ssh_key_manager config-delete
video_transcription
youtube_downloader
codex
claude
npm i
npm i -g
npm i -f
npm i --legacy-peer-deps
bun i
bun i -g
g
g init
g clone
g clone git@github.com:
g clone https://github.com/
g ad
g rs
g rs --soft
g rs --soft HEAD~
g rs --mixed
g rs --mixed HEAD~
g rs --hard
g rs --hard HEAD~
g st
g br
g ba
g bd
g bm
g bn
g tag
g tag -l
g tag -a
g tag -d
g ci 
g cm
g co
g cb
g remote
g remote -v
g remote add origin
g remote remove origin
g remote set-url origin
g merge
g merge --abort
g merge --continue
g rebase
g rebase --abort
g rebase --continue
g rebase --interactive --root
g rebase --interactive HEAD~
g pl
g pl -r
g pl --no-rebase
g ps
g ps -f
g ps --force-with-lease
g push origin --tags
g cz
lg
'

OnScriptInterrupt() {
  if [[ "$QUIET_MODE" != "true" ]]; then
    ClearProgress "true" "true"
  fi
  QuietLogWarning "Script interrupted by user"
  if [[ -n "$backup_file_path" && -f "$backup_file_path" && "$DRY_RUN" == "true" ]]; then
    QuietLogInfo "Backup file preserved: $backup_file_path"
  fi
  exit 130
}

ShowUsage() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Initialize Command History - Initialize command history for shell environments

OPTIONS:
  -h, --help              Show this help message
  -f, --force             Force mode (disable dry run)
  -b, --backup            Create backup before applying changes
  -q, --quiet             Suppress log output

RESTORE A BACKUP:
  --backup saves the history file to ~/.history_backups/<file>.YYYYMMDD_HHMMSS.bak.
  To restore it, copy the file back:
    fish        cp ~/.history_backups/fish_history.YYYYMMDD_HHMMSS.bak ~/.local/share/fish/fish_history
    PowerShell  cp ~/.history_backups/ConsoleHost_history.txt.YYYYMMDD_HHMMSS.bak ~/AppData/Roaming/Microsoft/Windows/PowerShell/PSReadLine/ConsoleHost_history.txt

EXAMPLES:
  $SCRIPT_NAME                           # Dry run (no backup)
  $SCRIPT_NAME --force                   # Apply changes (no backup)
  $SCRIPT_NAME --force --backup          # Apply with backup
EOF
}

ParseArguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h|--help)
      ShowUsage
      exit 0
      ;;
    -f|--force)
      DRY_RUN=false
      shift
      ;;
    -b|--backup)
      BACKUP_ENABLED=true
      shift
      ;;
    -q|--quiet)
      QUIET_MODE=true
      shift
      ;;
    *)
      LogError "Unknown option: $1"
      ShowUsage
      exit 1
      ;;
  esac
done
}

QuietLogInfo() {
  if [[ "$QUIET_MODE" != "true" ]]; then
    LogInfo "$@"
  fi
}

QuietLogWarning() {
  if [[ "$QUIET_MODE" != "true" ]]; then
    LogWarning "$@"
  fi
}

QuietLogSuccess() {
  if [[ "$QUIET_MODE" != "true" ]]; then
    LogSuccess "$@"
  fi
}

ValidateSystemEnvironment() {
  if [[ ! "${SYSTEM_OS_TYPE}" =~ ${OS_PATTERN_SUPPORTED} ]]; then
    LogError "Unsupported OS: ${SYSTEM_OS_TYPE}"
    exit 1
  fi
  QuietLogInfo "OS detected: ${SYSTEM_OS_TYPE}"
}

InitializeHistoryFilePath() {
  if [[ "${SYSTEM_OS_TYPE}" =~ ${OS_PATTERN_UNIX} ]]; then
    command_prefix="- cmd:"
    history_file_path="${FISH_HISTORY_PATH}"
  else
    command_prefix=""
    history_file_path="${POWERSHELL_HISTORY_PATH}"
  fi
  if ! _ValidateFile "${history_file_path}" >/dev/null 2>&1; then
    LogError "History file validation failed: ${history_file_path}"
    exit 1
  fi
  local file_size=$(GetFileSize "${history_file_path}" "true")
  local file_age=$(GetFileAge "${history_file_path}" "days")
  QuietLogInfo "History file: ${history_file_path}"
  QuietLogInfo "File size: ${file_size}, Age: ${file_age} days"
  if [[ ! -r "${history_file_path}" ]]; then
    LogError "No read permission: ${history_file_path}"
    exit 1
  fi
  if [[ ! -w "${history_file_path}" ]]; then
    LogError "No write permission: ${history_file_path}"
    exit 1
  fi
  QuietLogInfo "History file: ${history_file_path}"
}

CreateBackup() {
  if [[ "$BACKUP_ENABLED" != "true" ]]; then
    return 0
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    LogDebug "DRY RUN: Backup skipped (no changes made)"
    return 0
  fi
  mkdir -p "$BACKUP_DIR"
  local timestamp=$(date "+%Y%m%d_%H%M%S")
  local filename=$(basename "$history_file_path")
  backup_file_path="${BACKUP_DIR}/${filename}.${timestamp}.bak"
  if cp "$history_file_path" "$backup_file_path" 2>/dev/null; then
    QuietLogSuccess "Backup created: $backup_file_path"
    return 0
  else
    LogError "Failed to create backup"
    return 1
  fi
}

ResetHistoryFile() {
  if [[ "$DRY_RUN" == "true" ]]; then
    QuietLogWarning "DRY RUN: Would reset history file"
    return 0
  fi
  if rm "$history_file_path" 2>/dev/null && touch "$history_file_path" 2>/dev/null; then
    QuietLogSuccess "History file reset"
    return 0
  else
    LogError "Failed to reset history file"
    return 1
  fi
}

WriteCommandToHistory() {
  local command="$1"
  local command_count=0
  local total_commands=0
  if [[ -z "$command" ]]; then
    LogError "No commands to write"
    return 1
  fi
  while IFS= read -r line; do
    if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*$ ]]; then
      ((total_commands++))
    fi
  done <<< "$command"
  while IFS= read -r line; do
    if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*$ ]]; then
      ((command_count++))
      if [[ "$DRY_RUN" == "true" ]]; then
        LogDebug "Would write: $line"
      else
        if [[ -n "$command_prefix" ]]; then
          echo "$command_prefix $line" >> "$history_file_path"
        else
          echo "$line" >> "$history_file_path"
        fi
      fi
      if [[ "$QUIET_MODE" != "true" && $((command_count % 10)) -eq 0 ]]; then
        ShowProgress "$command_count" "$total_commands" "Writing" "true" 50 "detailed"
      fi
    fi
  done <<< "$command"
  if [[ "$QUIET_MODE" != "true" ]]; then
    ClearProgress "true" "true"
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    QuietLogWarning "DRY RUN: Would write $command_count commands"
  else
    QuietLogSuccess "Wrote $command_count commands"
  fi
  return 0
}

Main() {
  ParseArguments "$@"
  ValidateSystemEnvironment
  InitializeHistoryFilePath
  if ! CreateBackup; then
    exit 1
  fi
  if ! ResetHistoryFile; then
    exit 1
  fi
  QuietLogInfo "Writing default commands..."
  WriteCommandToHistory "$DEFAULT_SHELL_COMMANDS"
  QuietLogInfo "Writing custom commands..."
  WriteCommandToHistory "$CUSTOM_SHELL_COMMANDS"
  if [[ "$DRY_RUN" == "true" ]]; then
    QuietLogWarning "This was a dry run. Use --force to apply changes"
  else
    QuietLogSuccess "Command history initialized successfully!"
  fi
  exit 0
}

Main "$@"
