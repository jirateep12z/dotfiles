#!/usr/bin/env bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SYSTEM_OS_TYPE="$(uname -s)"
readonly FISH_HISTORY_PATH="${HOME}/.local/share/fish/fish_history"
readonly POWERSHELL_HISTORY_PATH="${HOME}/AppData/Roaming/Microsoft/Windows/PowerShell/PSReadLine/ConsoleHost_history.txt"
readonly OS_PATTERN_SUPPORTED="^(Darwin|Linux|MINGW*|MSYS*)"
readonly OS_PATTERN_UNIX="^(Darwin|Linux)"
readonly BACKUP_DIR="${HOME}/.history_backups"

source "$SCRIPT_DIR/utils/file.sh" 2>/dev/null || {
  echo "Error: Cannot load file.sh utility" >&2
  exit 1
}
source "$SCRIPT_DIR/utils/progress.sh" 2>/dev/null || {
  echo "Error: Cannot load progress.sh utility" >&2
  exit 1
}
source "$SCRIPT_DIR/utils/logger.sh" 2>/dev/null || {
  echo "Error: Cannot load logger.sh utility" >&2
  exit 1
}

declare DRY_RUN=true
declare BACKUP_ENABLED=false
declare BACKUP_LIST=false
declare BACKUP_DELETE=""
declare BACKUP_RESTORE=""
declare BACKUP_DELETE_ALL=false
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
wsl
brew
brew list
brew list --cask
brew install
brew install --cask
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
npm
npm init
npm list
npm list -g
npm install
npm install -g
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
ncu
ncu -g
ncu -i
ncu -i --format group
nest
nest new
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
git commit
git commit -m
git branch
git branch -a
git branch -d
git branch --merged
git branch --no-merged
git checkout
git checkout -b
git remote
git remote -v
git remote add origin
git remote remove origin
git remote set-url origin
git reset
git reset --soft
git reset --soft HEAD~
git merge
git merge --abort
git merge --continue
git rebase
git rebase --abort
git rebase --continue
git rebase --interactive --root
git rebase --interactive HEAD~
git push origin "$(git rev-parse --abbrev-ref HEAD)"
git push origin "$(git rev-parse --abbrev-ref HEAD)" -f
git push origin "$(git rev-parse --abbrev-ref HEAD)" --force-with-lease
git pull origin "$(git rev-parse --abbrev-ref HEAD)"
git pull origin "$(git rev-parse --abbrev-ref HEAD)" -r
git pull origin "$(git rev-parse --abbrev-ref HEAD)" -r --autostash
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
get_open_with_manager
ide
initialize_command_history
resize_dock
sort_command_history
youtube_downloader
npm i
npm i -g
g
g init
g clone
g clone git@github.com:
g clone https://github.com/
g ad
g rs
g st
g br
g ba
g bd
g bm
g bn
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
g reset
g reset --soft
g reset --soft HEAD~
g ps
g ps -f
g ps --force-with-lease
g pl
g pl -r
g pl -r --autostash
g cz
lg
'

trap 'OnScriptInterrupt' INT TERM EXIT

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
Usage: $(basename "$0") [OPTIONS]

Initialize command history for shell environments

OPTIONS:
  -h, --help              Show this help message
  -d, --dry-run           Dry run mode (default: true)
  -f, --force             Force mode (disable dry run)
  -b, --backup            Create backup before applying changes
  -q, --quiet             Suppress log output
  -lb, --list-backups     List all backup files
  -db, --delete-backup    Delete backup file (use with --backup-file)
  -dba, --delete-all      Delete all backup files
  -rb, --restore-backup   Restore from backup file (use with --backup-file)
  --backup-file FILE      Specify backup file to delete or restore

EXAMPLES:
  $(basename "$0")                           # Dry run (no backup)
  $(basename "$0") --force                   # Apply changes (no backup)
  $(basename "$0") --force --backup          # Apply with backup
  $(basename "$0") --list-backups            # Show all backups
  $(basename "$0") --restore-backup --backup-file FILE  # Restore from backup

EOF
}

ParseArguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h|--help)
      ShowUsage
      exit 0
      ;;
    -d|--dry-run)
      DRY_RUN=true
      shift
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
    -lb|--list-backups)
      BACKUP_LIST=true
      shift
      ;;
    -db|--delete-backup)
      BACKUP_DELETE="true"
      shift
      ;;
    -dba|--delete-all)
      BACKUP_DELETE_ALL=true
      shift
      ;;
    -rb|--restore-backup)
      BACKUP_RESTORE="true"
      shift
      ;;
    --backup-file)
      if [[ "$BACKUP_DELETE" == "true" ]]; then
        BACKUP_DELETE="$2"
      elif [[ "$BACKUP_RESTORE" == "true" ]]; then
        BACKUP_RESTORE="$2"
      fi
      shift 2
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

ListBackups() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    QuietLogWarning "No backup directory found"
    return 0
  fi
  local backup_count=0
  QuietLogInfo "Available backups:"
  while IFS= read -r backup_file; do
    ((backup_count++))
    local file_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null || echo "0")
    printf "  %2d. %s (%s)\n" "$backup_count" "$(basename "$backup_file")" "$(FormatBytes "$file_size" 2)"
  done < <(find "$BACKUP_DIR" -type f -name "*.bak" 2>/dev/null | sort -r)
  if [[ $backup_count -eq 0 ]]; then
    QuietLogWarning "No backup files found"
  fi
}

DeleteBackup() {
  local backup_file="$1"
  if [[ -z "$backup_file" || "$backup_file" == "true" ]]; then
    LogError "Backup file not specified"
    return 1
  fi
  if [[ ! -f "$backup_file" ]]; then
    backup_file="$BACKUP_DIR/$backup_file"
  fi
  if [[ ! -f "$backup_file" ]]; then
    LogError "Backup file not found: $backup_file"
    return 1
  fi
  if rm "$backup_file" 2>/dev/null; then
    QuietLogSuccess "Backup deleted: $(basename "$backup_file")"
    return 0
  else
    LogError "Failed to delete backup: $backup_file"
    return 1
  fi
}

DeleteAllBackups() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    QuietLogWarning "No backup directory found"
    return 0
  fi
  local backup_count=0
  local deleted_count=0
  while IFS= read -r backup_file; do
    ((backup_count++))
  done < <(find "$BACKUP_DIR" -type f -name "*.bak" 2>/dev/null)
  if [[ $backup_count -eq 0 ]]; then
    QuietLogWarning "No backup files found"
    return 0
  fi
  QuietLogWarning "Found $backup_count backup files to delete"
  read -p "Are you sure you want to delete all $backup_count backups? (Y/N): " -r confirm_delete
  if [[ "${confirm_delete^^}" != "Y" ]]; then
    QuietLogInfo "Operation cancelled"
    return 1
  fi
  local current=0
  while IFS= read -r backup_file; do
    ((current++))
    if rm "$backup_file" 2>/dev/null; then
      ((deleted_count++))
    else
      LogError "Failed to delete: $(basename "$backup_file")"
    fi
    if [[ "$QUIET_MODE" != "true" ]]; then
      ShowProgress "$current" "$backup_count" "Deleting" "true" 50 "detailed"
    fi
  done < <(find "$BACKUP_DIR" -type f -name "*.bak" 2>/dev/null)
  if [[ "$QUIET_MODE" != "true" ]]; then
    ClearProgress "true" "true"
  fi
  QuietLogSuccess "Deleted $deleted_count/$backup_count backups"
  return 0
}

RestoreBackup() {
  local backup_file="$1"
  if [[ -z "$backup_file" || "$backup_file" == "true" ]]; then
    LogError "Backup file not specified"
    return 1
  fi
  if [[ ! -f "$backup_file" ]]; then
    backup_file="$BACKUP_DIR/$backup_file"
  fi
  if [[ ! -f "$backup_file" ]]; then
    LogError "Backup file not found: $backup_file"
    return 1
  fi
  if [[ ! -f "$history_file_path" ]]; then
    LogError "History file not found: $history_file_path"
    return 1
  fi
  if cp "$backup_file" "$history_file_path" 2>/dev/null; then
    QuietLogSuccess "History restored from: $(basename "$backup_file")"
    return 0
  else
    LogError "Failed to restore backup: $backup_file"
    return 1
  fi
}

Main() {
  ParseArguments "$@"
  if [[ "$BACKUP_LIST" == "true" ]]; then
    ListBackups
    exit 0
  fi
  if [[ "$BACKUP_DELETE_ALL" == "true" ]]; then
    DeleteAllBackups
    exit $?
  fi
  if [[ "$BACKUP_DELETE" != "" && "$BACKUP_DELETE" != "false" ]]; then
    DeleteBackup "$BACKUP_DELETE"
    exit $?
  fi
  if [[ "$BACKUP_RESTORE" != "" && "$BACKUP_RESTORE" != "false" ]]; then
    ValidateSystemEnvironment
    InitializeHistoryFilePath
    RestoreBackup "$BACKUP_RESTORE"
    exit $?
  fi
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