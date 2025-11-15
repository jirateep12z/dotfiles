#!/usr/bin/env bash

if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Error: This script requires bash 4+ (detected: ${BASH_VERSION:-unknown}). On macOS: brew install bash" >&2
  exit 1
fi

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
if [[ ! -f "$UTILS_DIR/logger.sh" ]]; then
  UTILS_DIR="$SCRIPT_DIR/../utils/shell"
fi
readonly UTILS_DIR
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SYSTEM_OS_TYPE="$(uname -s)"
readonly OS_PATTERN_SUPPORTED="^(Darwin|MINGW|MSYS|CYGWIN)"
readonly OS_PATTERN_WINDOWS="^(MINGW|MSYS|CYGWIN)"

source "$UTILS_DIR/logger.sh" 2>/dev/null || {
  echo "Error: Cannot load logger.sh utility" >&2
  exit 1
}

declare DRY_RUN=true
declare FORCE_NATIVE=false
declare SKIP_REINSTALL=false
declare SHOW_HELP=false
declare BACKUP_DIR="$HOME/.backup/anydesk"
declare -a DETECTED_METHODS=()
declare -a NATIVE_EXECUTABLE_PATHS=()
declare -a CONFIG_PATHS=()
declare -a EXTRA_PATHS=()
declare PLANNED_INSTALL_METHOD=""
declare OLD_ANYDESK_ID=""
declare WORK_DIR=""
declare ROSTER_FILE=""
declare BACKUP_FILE=""
declare NEW_ANYDESK_ID=""
declare -i RESTORED_ROSTER_COUNT=0

readonly ROSTER_LINE_PATTERN='^ad\.roster\.'
readonly ANYDESK_ID_KEY="ad.anynet.id"
readonly PROCESS_EXIT_WAIT_SECONDS=2
readonly ID_WAIT_TIMEOUT_SECONDS=60
readonly SCOOP_BUCKET="extras"
readonly SCOOP_PACKAGE="extras/anydesk"
readonly WINDOWS_DOWNLOAD_URL="https://download.anydesk.com/AnyDesk.exe"
readonly MACOS_DOWNLOAD_URL="https://download.anydesk.com/anydesk.dmg"
readonly WINDOWS_SIGNER_NAME="AnyDesk Software GmbH"
readonly MACOS_APP_PATH="/Applications/AnyDesk.app"
readonly -a MACOS_EXTRA_DIRS=(
  "$HOME/Library/Preferences"
  "$HOME/Library/Caches"
  "$HOME/Library/Application Support"
  "$HOME/Library/Saved Application State"
  "$HOME/Library/LaunchAgents"
  "/Library/LaunchAgents"
  "/Library/LaunchDaemons"
  "/Library/PrivilegedHelperTools"
)

IsWindows() {
  [[ "$SYSTEM_OS_TYPE" =~ $OS_PATTERN_WINDOWS ]]
}

ToUnixPath() {
  local source_path="$1"
  if [[ -n "$source_path" ]] && command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$source_path"
    return
  fi
  printf '%s\n' "$source_path"
}

ValidateSystemEnvironment() {
  if [[ ! "${SYSTEM_OS_TYPE}" =~ ${OS_PATTERN_SUPPORTED} ]]; then
    LogError "This script only supports Windows and macOS (detected: ${SYSTEM_OS_TYPE})"
    return 1
  fi
  return 0
}

GetWindowsAppDataDir() {
  ToUnixPath "$(printenv APPDATA)"
}

GetWindowsProgramDataDir() {
  local program_data_dir
  program_data_dir="$(printenv ProgramData)"
  ToUnixPath "${program_data_dir:-$(printenv ALLUSERSPROFILE)}"
}

GetWindowsProgramFilesDirs() {
  local program_files_dir
  for program_files_dir in "$(printenv 'ProgramFiles(x86)')" "$(printenv PROGRAMFILES)"; do
    [[ -n "$program_files_dir" ]] && ToUnixPath "$program_files_dir"
  done
}

HasWindowsService() {
  sc query AnyDesk >/dev/null 2>&1
}

IsScoopAnyDeskInstalled() {
  command -v scoop >/dev/null 2>&1 || return 1
  scoop list anydesk 2>/dev/null | tr -d '\r' | grep -Eiq '^anydesk[[:space:]]'
}

IsBrewAnyDeskInstalled() {
  command -v brew >/dev/null 2>&1 && brew list --cask anydesk >/dev/null 2>&1
}

CollectConfigPaths() {
  CONFIG_PATHS=()
  local config_path
  shopt -s nullglob nocaseglob
  if IsWindows; then
    local app_data_dir program_data_dir
    app_data_dir="$(GetWindowsAppDataDir)"
    program_data_dir="$(GetWindowsProgramDataDir)"
    [[ -n "$app_data_dir" ]] && for config_path in "$app_data_dir"/AnyDesk*; do CONFIG_PATHS+=("$config_path"); done
    [[ -n "$program_data_dir" ]] && for config_path in "$program_data_dir"/AnyDesk*; do CONFIG_PATHS+=("$config_path"); done
  else
    for config_path in "$HOME"/.anydesk* /etc/anydesk*; do CONFIG_PATHS+=("$config_path"); done
  fi
  shopt -u nullglob nocaseglob
}

CollectExtraPaths() {
  EXTRA_PATHS=()
  IsWindows && return 0
  local extra_dir extra_path
  shopt -s nullglob nocaseglob
  for extra_dir in "${MACOS_EXTRA_DIRS[@]}"; do
    for extra_path in "$extra_dir"/*anydesk*; do EXTRA_PATHS+=("$extra_path"); done
  done
  shopt -u nullglob nocaseglob
}

DetectInstallation() {
  DETECTED_METHODS=()
  NATIVE_EXECUTABLE_PATHS=()
  if IsWindows; then
    IsScoopAnyDeskInstalled && DETECTED_METHODS+=("SCOOP")
    local program_files_dir executable_path
    shopt -s nullglob
    while IFS= read -r program_files_dir; do
      for executable_path in "$program_files_dir"/AnyDesk*/AnyDesk.exe; do
        NATIVE_EXECUTABLE_PATHS+=("$executable_path")
      done
    done < <(GetWindowsProgramFilesDirs)
    shopt -u nullglob
    if [[ ${#NATIVE_EXECUTABLE_PATHS[@]} -gt 0 ]] || HasWindowsService; then
      DETECTED_METHODS+=("NATIVE_WINDOWS")
    fi
  else
    if IsBrewAnyDeskInstalled; then
      DETECTED_METHODS+=("BREW")
    elif [[ -d "$MACOS_APP_PATH" ]]; then
      DETECTED_METHODS+=("NATIVE_MACOS")
    fi
  fi
  CollectConfigPaths
  CollectExtraPaths
}

FindConfigFile() {
  local config_file_name="$1"
  local config_path
  for config_path in "${CONFIG_PATHS[@]}"; do
    if [[ -f "$config_path/$config_file_name" ]]; then
      printf '%s\n' "$config_path/$config_file_name"
      return 0
    fi
  done
  return 1
}

ReadConfigValue() {
  local config_file_name="$1"
  local config_key="$2"
  local config_file
  config_file="$(FindConfigFile "$config_file_name")" || return 1
  grep -m 1 "^${config_key//./\\.}=" "$config_file" | cut -d '=' -f 2- | tr -d '\r'
}

CountRosterLines() {
  local user_config_file
  user_config_file="$(FindConfigFile "user.conf")" || { echo 0; return 0; }
  grep -c "$ROSTER_LINE_PATTERN" "$user_config_file" || true
}

ResolveInstallMethod() {
  if [[ "$FORCE_NATIVE" == "true" ]]; then
    IsWindows && PLANNED_INSTALL_METHOD="NATIVE_WINDOWS" || PLANNED_INSTALL_METHOD="NATIVE_MACOS"
    return 0
  fi
  if IsWindows; then
    command -v scoop >/dev/null 2>&1 && PLANNED_INSTALL_METHOD="SCOOP" || PLANNED_INSTALL_METHOD="NATIVE_WINDOWS"
  else
    command -v brew >/dev/null 2>&1 && PLANNED_INSTALL_METHOD="BREW" || PLANNED_INSTALL_METHOD="NATIVE_MACOS"
  fi
}

ToAbsolutePath() {
  local source_path="$1"
  [[ "$source_path" == /* ]] && printf '%s\n' "$source_path" || printf '%s\n' "$PWD/$source_path"
}

ValidateBackupDir() {
  BACKUP_DIR="$(ToAbsolutePath "$(ToUnixPath "$BACKUP_DIR")")"
  BACKUP_DIR="${BACKUP_DIR%/}"
  local config_path
  for config_path in "${CONFIG_PATHS[@]}"; do
    if [[ "${BACKUP_DIR,,}" == "${config_path,,}" || "${BACKUP_DIR,,}" == "${config_path,,}"/* ]]; then
      LogError "Backup directory must not be inside an AnyDesk configuration path: $config_path"
      return 1
    fi
  done
  return 0
}

IsWindowsAdmin() {
  net session >/dev/null 2>&1
}

CheckPrivileges() {
  IsWindows || return 0
  local needs_admin=false
  local program_data_dir config_path
  program_data_dir="$(GetWindowsProgramDataDir)"
  [[ " ${DETECTED_METHODS[*]} " == *" NATIVE_WINDOWS "* ]] && needs_admin=true
  [[ "$SKIP_REINSTALL" == "false" && "$PLANNED_INSTALL_METHOD" == "NATIVE_WINDOWS" ]] && needs_admin=true
  for config_path in "${CONFIG_PATHS[@]}"; do
    [[ -n "$program_data_dir" && "$config_path" == "$program_data_dir"/* ]] && needs_admin=true
  done
  if [[ "$needs_admin" == "true" ]] && ! IsWindowsAdmin; then
    LogError "Administrator rights are required for the native installation or %ProgramData%\\AnyDesk"
    LogError "Reopen the terminal with 'Run as administrator' and run this script again"
    return 1
  fi
  return 0
}

ShowSummary() {
  local item
  LogKeyValue "Detected methods" "${DETECTED_METHODS[*]:-none}"
  for item in "${NATIVE_EXECUTABLE_PATHS[@]}"; do LogKeyValue "Native executable" "$item"; done
  for item in "${CONFIG_PATHS[@]}" "${EXTRA_PATHS[@]}"; do LogKeyValue "Path to remove" "$item"; done
  LogKeyValue "Current AnyDesk ID" "${OLD_ANYDESK_ID:-unknown}"
  LogInfo "Roster lines to keep: $(CountRosterLines)"
  if [[ "$SKIP_REINSTALL" == "true" ]]; then
    LogInfo "Reinstall method: skipped (--no-reinstall)"
  else
    LogInfo "Reinstall method: $PLANNED_INSTALL_METHOD"
  fi
  LogKeyValue "Backup directory" "$BACKUP_DIR"
}

CleanupWorkDir() {
  [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
}

PauseSeconds() {
  [[ -n "${ANYDESK_TEST_NO_SLEEP:-}" ]] && return 0
  sleep "$1"
}

StopAnyDesk() {
  LogInfo "Stopping AnyDesk"
  if IsWindows; then
    HasWindowsService && sc stop AnyDesk >/dev/null 2>&1
    taskkill //F //IM AnyDesk.exe >/dev/null 2>&1
  else
    pkill -x AnyDesk >/dev/null 2>&1
  fi
  PauseSeconds "$PROCESS_EXIT_WAIT_SECONDS"
  return 0
}

CreateBackup() {
  if [[ ${#CONFIG_PATHS[@]} -eq 0 ]]; then
    LogInfo "No configuration found; skipping backup"
    return 0
  fi
  if ! (umask 077 && mkdir -p "$BACKUP_DIR"); then
    LogError "Cannot create backup directory: $BACKUP_DIR"
    return 1
  fi
  chmod 700 "$BACKUP_DIR" 2>/dev/null
  BACKUP_FILE="$BACKUP_DIR/anydesk-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
  local tar_command=(tar -czPf "$BACKUP_FILE" "${CONFIG_PATHS[@]}")
  [[ "${CONFIG_PATHS[*]}" == *"/etc/"* ]] && tar_command=(sudo "${tar_command[@]}")
  if ! (umask 077 && "${tar_command[@]}" 2>/dev/null); then
    LogError "Backup failed: $BACKUP_FILE"
    return 1
  fi
  [[ "${tar_command[0]}" == "sudo" ]] && sudo chown "$(id -u):$(id -g)" "$BACKUP_FILE"
  chmod 600 "$BACKUP_FILE" 2>/dev/null
  LogSuccess "Backup created: $BACKUP_FILE"
  return 0
}

ExtractRoster() {
  ROSTER_FILE="$WORK_DIR/roster.conf"
  : > "$ROSTER_FILE"
  local user_config_file
  user_config_file="$(FindConfigFile "user.conf")" || return 0
  grep "$ROSTER_LINE_PATTERN" "$user_config_file" | tr -d '\r' > "$ROSTER_FILE" || true
  return 0
}

AssertSafeRemovalPath() {
  local target_path="${1%/}"
  local target_name
  target_name="$(basename "$target_path")"
  if [[ -z "$target_path" || "$target_path" == "/" || "$target_path" == "${HOME%/}" || "$target_path" =~ ^/[A-Za-z]$ ]]; then
    LogError "Refusing to remove unsafe path: '$1'"
    return 1
  fi
  if [[ "${target_name,,}" != *anydesk* ]]; then
    LogError "Refusing to remove path without 'anydesk' in its name: $target_path"
    return 1
  fi
  return 0
}

RemovePath() {
  local target_path="$1"
  [[ -e "$target_path" || -L "$target_path" ]] || return 0
  AssertSafeRemovalPath "$target_path" || return 1
  if [[ -w "$(dirname "$target_path")" ]]; then
    rm -rf -- "$target_path"
  elif IsWindows; then
    LogError "No permission to remove: $target_path"
    return 1
  else
    sudo rm -rf -- "$target_path"
  fi
}

UninstallAnyDesk() {
  local detected_method executable_path
  for detected_method in "${DETECTED_METHODS[@]}"; do
    LogInfo "Uninstalling AnyDesk ($detected_method)"
    case "$detected_method" in
      SCOOP)
        scoop uninstall anydesk --purge || return 1
        ;;
      NATIVE_WINDOWS)
        for executable_path in "${NATIVE_EXECUTABLE_PATHS[@]}"; do
          "$executable_path" --silent --remove
          PauseSeconds "$PROCESS_EXIT_WAIT_SECONDS"
          RemovePath "$(dirname "$executable_path")" || return 1
        done
        ;;
      BREW)
        brew uninstall --cask --zap anydesk || return 1
        ;;
      NATIVE_MACOS)
        local extra_path
        for extra_path in "${EXTRA_PATHS[@]}"; do
          if [[ "$extra_path" == *.plist && "$extra_path" == */Launch* ]]; then
            if [[ "$extra_path" == /Library/* ]]; then
              sudo launchctl unload "$extra_path" 2>/dev/null
            else
              launchctl unload "$extra_path" 2>/dev/null
            fi
          fi
        done
        RemovePath "$MACOS_APP_PATH" || return 1
        ;;
    esac
  done
  return 0
}

WipeRemainingPaths() {
  CollectConfigPaths
  CollectExtraPaths
  local target_path
  for target_path in "${CONFIG_PATHS[@]}" "${EXTRA_PATHS[@]}"; do
    LogInfo "Removing: $target_path"
    RemovePath "$target_path" || return 1
  done
  return 0
}

VerifyRemoval() {
  DetectInstallation
  local remaining_item
  local -a remaining_items=("${DETECTED_METHODS[@]}" "${NATIVE_EXECUTABLE_PATHS[@]}" "${CONFIG_PATHS[@]}" "${EXTRA_PATHS[@]}")
  if [[ ${#remaining_items[@]} -eq 0 ]]; then
    LogSuccess "AnyDesk removed completely"
    return 0
  fi
  LogError "AnyDesk removal is incomplete; not reinstalling"
  for remaining_item in "${remaining_items[@]}"; do LogKeyValue "Remaining" "$remaining_item"; done
  return 1
}

ShowBackupNotice() {
  [[ -z "$BACKUP_FILE" ]] && return 0
  LogKeyValue "Backup" "$BACKUP_FILE"
  LogWarning "The backup contains the old AnyDesk ID and device keys. Store it safely or delete it when no longer needed."
  LogInfo "Restore with: tar -xzPf \"$BACKUP_FILE\""
}

ShowReport() {
  LogKeyValue "Old AnyDesk ID" "${OLD_ANYDESK_ID:-unknown}"
  [[ "$SKIP_REINSTALL" == "false" ]] && LogKeyValue "New AnyDesk ID" "${NEW_ANYDESK_ID:-unknown}"
  [[ "$SKIP_REINSTALL" == "false" ]] && LogInfo "Restored roster lines: $RESTORED_ROSTER_COUNT"
  if [[ -n "$OLD_ANYDESK_ID" && "$OLD_ANYDESK_ID" == "$NEW_ANYDESK_ID" ]]; then
    LogWarning "The AnyDesk ID did not change. Devices bound to a license or my.anydesk account may keep their ID."
  fi
  ShowBackupNotice
}

InstallWithScoop() {
  if ! scoop bucket list 2>/dev/null | tr -d '\r' | grep -Eq "^${SCOOP_BUCKET}[[:space:]]"; then
    scoop bucket add "$SCOOP_BUCKET" || return 1
  fi
  scoop install "$SCOOP_PACKAGE"
}

InstallWithBrew() {
  brew install --cask anydesk
}

DownloadInstaller() {
  local download_url="$1"
  local destination_file="$2"
  LogInfo "Downloading: $download_url"
  curl -fsSL --proto '=https' -o "$destination_file" "$download_url"
}

VerifyWindowsSignature() {
  local windows_file_path
  windows_file_path="$(cygpath -w "$1")"
  powershell.exe -NoProfile -NonInteractive -Command \
    "\$signature = Get-AuthenticodeSignature -LiteralPath '$windows_file_path'; if (\$signature.Status -eq 'Valid' -and \$signature.SignerCertificate.Subject -like '*$WINDOWS_SIGNER_NAME*') { exit 0 } else { exit 1 }"
}

InstallNativeWindows() {
  local installer_file="$WORK_DIR/AnyDesk.exe"
  DownloadInstaller "$WINDOWS_DOWNLOAD_URL" "$installer_file" || return 1
  if ! VerifyWindowsSignature "$installer_file"; then
    LogError "Installer signature verification failed"
    return 1
  fi
  local program_files_dir
  program_files_dir="$(printenv 'ProgramFiles(x86)')"
  program_files_dir="${program_files_dir:-$(printenv PROGRAMFILES)}"
  "$installer_file" --install "$program_files_dir\\AnyDesk" --start-with-win --silent --create-shortcuts --create-desktop-icon
}

InstallNativeMacos() {
  local disk_image_file="$WORK_DIR/anydesk.dmg"
  local mount_dir="$WORK_DIR/mount"
  DownloadInstaller "$MACOS_DOWNLOAD_URL" "$disk_image_file" || return 1
  mkdir -p "$mount_dir" || return 1
  hdiutil attach -nobrowse -quiet -mountpoint "$mount_dir" "$disk_image_file" || return 1
  local install_status=0
  local mounted_app="$mount_dir/AnyDesk.app"
  if ! codesign --verify --deep --strict "$mounted_app" || ! spctl --assess --type execute "$mounted_app"; then
    LogError "Application signature verification failed"
    install_status=1
  elif [[ -w "$(dirname "$MACOS_APP_PATH")" ]]; then
    cp -R "$mounted_app" "$(dirname "$MACOS_APP_PATH")/" || install_status=1
  else
    sudo cp -R "$mounted_app" "$(dirname "$MACOS_APP_PATH")/" || install_status=1
  fi
  hdiutil detach -quiet "$mount_dir"
  return $install_status
}

InstallAnyDesk() {
  LogInfo "Installing AnyDesk ($PLANNED_INSTALL_METHOD)"
  case "$PLANNED_INSTALL_METHOD" in
    SCOOP) InstallWithScoop ;;
    BREW) InstallWithBrew ;;
    NATIVE_WINDOWS) InstallNativeWindows ;;
    NATIVE_MACOS) InstallNativeMacos ;;
    *) return 1 ;;
  esac
}

StartAnyDesk() {
  case "$PLANNED_INSTALL_METHOD" in
    SCOOP)
      local scoop_app_dir
      scoop_app_dir="$(ToUnixPath "$(scoop prefix anydesk | tr -d '\r')")"
      nohup "$scoop_app_dir/AnyDesk.exe" >/dev/null 2>&1 &
      ;;
    NATIVE_WINDOWS)
      sc start AnyDesk >/dev/null 2>&1
      ;;
    BREW|NATIVE_MACOS)
      open -a AnyDesk
      ;;
  esac
  return 0
}

WaitForAnyDeskId() {
  local -i elapsed_seconds=0
  StartAnyDesk
  while [[ $elapsed_seconds -lt $ID_WAIT_TIMEOUT_SECONDS ]]; do
    CollectConfigPaths
    NEW_ANYDESK_ID="$(ReadConfigValue "system.conf" "$ANYDESK_ID_KEY")"
    [[ -n "$NEW_ANYDESK_ID" ]] && return 0
    if [[ -n "${ANYDESK_TEST_NO_SLEEP:-}" ]]; then
      wait
    else
      sleep 1
    fi
    elapsed_seconds+=1
  done
  return 1
}

GetDefaultUserConfigFile() {
  if IsWindows; then
    printf '%s\n' "$(GetWindowsAppDataDir)/AnyDesk/user.conf"
  else
    printf '%s\n' "$HOME/.anydesk/user.conf"
  fi
}

RestoreRoster() {
  local -i saved_roster_count
  saved_roster_count="$(grep -c "$ROSTER_LINE_PATTERN" "$ROSTER_FILE" 2>/dev/null || true)"
  [[ $saved_roster_count -eq 0 ]] && return 0
  StopAnyDesk
  CollectConfigPaths
  local user_config_file
  user_config_file="$(FindConfigFile "user.conf")" || user_config_file="$(GetDefaultUserConfigFile)"
  mkdir -p "$(dirname "$user_config_file")" || return 1
  local merged_config_file="$WORK_DIR/user.conf.merged"
  if [[ -f "$user_config_file" ]]; then
    grep -v "$ROSTER_LINE_PATTERN" "$user_config_file" > "$merged_config_file" || true
  else
    : > "$merged_config_file"
  fi
  [[ -s "$merged_config_file" && -n "$(tail -c 1 "$merged_config_file")" ]] && printf '\n' >> "$merged_config_file"
  cat "$ROSTER_FILE" >> "$merged_config_file"
  cp "$merged_config_file" "$user_config_file" || return 1
  RESTORED_ROSTER_COUNT=$saved_roster_count
  StartAnyDesk
  return 0
}

ShowUsage() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Reinstall AnyDesk - Remove every AnyDesk installation (Native, Scoop, Homebrew),
wipe all configuration to get a new AnyDesk ID, reinstall, and keep the
remote address list (ad.roster.* in user.conf)

OPTIONS:
  -h, --help              Show this help message
  -f, --force             Remove and reinstall AnyDesk (default: dry run)
  --native               Force the native installer even if Scoop or Homebrew exists
  --no-reinstall          Uninstall and wipe only
  --backup-dir DIR        Backup location (default: ~/.backup/anydesk)

REQUIREMENTS:
  Windows                 Git Bash, MSYS, or Cygwin; run as administrator for
                          native installs or %ProgramData%\\AnyDesk
  macOS                   sudo may be requested for /etc/anydesk and /Library paths

RESTORE A BACKUP:
  The backup contains the old AnyDesk ID and device keys. To restore it,
  remove the current AnyDesk configuration, then run:
    tar -xzPf ~/.backup/anydesk/anydesk-backup-YYYYMMDD-HHMMSS.tar.gz

EXAMPLES:
  $SCRIPT_NAME                           # Preview without changes
  $SCRIPT_NAME --force                   # Reinstall AnyDesk
  $SCRIPT_NAME --force --native          # Force native installer
  $SCRIPT_NAME --force --no-reinstall    # Remove AnyDesk completely
EOF
}

ParseArguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        SHOW_HELP=true
        shift
        ;;
      -f|--force)
        DRY_RUN=false
        shift
        ;;
      --native)
        FORCE_NATIVE=true
        shift
        ;;
      --no-reinstall)
        SKIP_REINSTALL=true
        shift
        ;;
      --backup-dir)
        if [[ $# -lt 2 || -z "$2" ]]; then
          LogError "--backup-dir requires a value"
          return 1
        fi
        BACKUP_DIR="$2"
        shift 2
        ;;
      *)
        LogError "Unknown option: $1"
        ShowUsage
        return 1
        ;;
    esac
  done
  return 0
}

Main() {
  if ! ParseArguments "$@"; then
    exit 1
  fi
  if [[ "$SHOW_HELP" == "true" ]]; then
    ShowUsage
    exit 0
  fi
  if ! ValidateSystemEnvironment; then
    exit 1
  fi
  DetectInstallation
  OLD_ANYDESK_ID="$(ReadConfigValue "system.conf" "$ANYDESK_ID_KEY")"
  ResolveInstallMethod
  if ! ValidateBackupDir || ! CheckPrivileges; then
    exit 1
  fi
  ShowSummary
  if [[ "$DRY_RUN" == "true" ]]; then
    LogInfo "Dry run: no changes made"
    LogInfo "Use --force to apply changes"
    exit 0
  fi
  LogWarning "This removes AnyDesk and its configuration. The current AnyDesk ID will be replaced."
  WORK_DIR="$(mktemp -d)" || exit 1
  trap CleanupWorkDir EXIT
  StopAnyDesk
  CreateBackup || exit 1
  ExtractRoster
  if ! UninstallAnyDesk || ! WipeRemainingPaths || ! VerifyRemoval; then
    ShowBackupNotice
    exit 1
  fi
  if [[ "$SKIP_REINSTALL" == "true" ]]; then
    ShowReport
    LogSuccess "Done!"
    exit 0
  fi
  if ! InstallAnyDesk; then
    LogError "AnyDesk installation failed. If a Scoop hash mismatch occurred, run again with --native"
    ShowBackupNotice
    exit 1
  fi
  if ! WaitForAnyDeskId; then
    LogWarning "AnyDesk did not create a new ID within ${ID_WAIT_TIMEOUT_SECONDS}s; roster not restored"
    LogWarning "Copy the ad.roster.* lines from user.conf in the backup into the new user.conf manually"
    ShowReport
    exit 0
  fi
  if ! RestoreRoster; then
    LogWarning "Roster restore failed; copy the ad.roster.* lines from the backup manually"
  fi
  ShowReport
  LogSuccess "Done!"
}

Main "$@"
