#!/usr/bin/env fish

set SCRIPT_DIR (dirname (status -f))
set SCRIPT_NAME (basename (status -f))

source "$SCRIPT_DIR/utils/shell/logger.sh" 2>/dev/null
if test $status -ne 0
  echo "Error: Cannot load logger.sh utility" >&2
  exit 1
end

function CheckInstallCompatibility
  set os_name (string lower (uname))
  if test "$os_name" = "darwin"
    LogInfo "macOS system detected: "(uname)
    return 0
  else if test "$os_name" = "linux"
    LogInfo "Linux system detected: "(uname)
    return 0
  else
    LogError "This install script only supports macOS and Linux"
    LogError "Detected OS: "(uname)
    return 1
  end
end

function CheckFishShell
  if test -z "$FISH_VERSION"
    LogError "Please run this script inside Fish shell"
    return 1
  end
  LogInfo "Fish shell detected: $FISH_VERSION"
  return 0
end

function InstallFisher
  if not type -q fisher
    LogWarning "Fisher is not installed. Installing..."
    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
    and fisher install jorgebucaran/fisher
    if test $status -eq 0
      LogSuccess "Fisher installed successfully"
    else
      LogError "Failed to install Fisher"
      return 1
    end
  else
    LogInfo "Fisher is already installed"
  end
  return 0
end

function InstallFisherPlugins
  if not test -f "$SCRIPT_DIR/requirement/fisher.txt"
    LogWarning "Fisher plugin list not found: $SCRIPT_DIR/requirement/fisher.txt"
    return 1
  end
  LogInfo "Installing Fisher plugins"
  set plugins (cat "$SCRIPT_DIR/requirement/fisher.txt" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$')
  set total (count $plugins)
  set current 0
  for plugin in $plugins
    set current (math $current + 1)
    LogInfo "[$current/$total] Installing: $plugin"
    fisher install $plugin
  end
  LogSuccess "Completed installing Fisher plugins"
end

function UninstallFisherPlugins
  if not test -f "$SCRIPT_DIR/requirement/fisher.txt"
    LogWarning "Fisher plugin list not found: $SCRIPT_DIR/requirement/fisher.txt"
    return 1
  end
  LogInfo "Uninstalling Fisher plugins"
  set plugins (cat "$SCRIPT_DIR/requirement/fisher.txt" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$')
  set total (count $plugins)
  set current 0
  for plugin in $plugins
    set current (math $current + 1)
    LogInfo "[$current/$total] Uninstalling: $plugin"
    fisher remove $plugin
  end
  LogSuccess "Completed uninstalling Fisher plugins"
end

function InstallNodeJS
  if not type -q nvm
    LogWarning "NVM is not installed. Installing Fisher plugins first..."
    InstallFisherPlugins
  end
  LogInfo "Installing Node.js LTS version"
  nvm install lts
  if test $status -ne 0
    LogError "Failed to install Node.js LTS"
    return 1
  end
  LogInfo "Using Node.js LTS version"
  nvm use lts
  LogInfo "Setting default Node.js version to LTS"
  set --universal nvm_default_version lts
  LogSuccess "Node.js LTS installed and configured successfully"
end

function UninstallNodeJS
  if not type -q nvm
    LogWarning "NVM is not installed"
    return 1
  end
  LogInfo "Uninstalling Node.js LTS version"
  nvm uninstall lts
  if test $status -eq 0
    LogSuccess "Node.js LTS uninstalled successfully"
  else
    LogError "Failed to uninstall Node.js LTS"
    return 1
  end
end

function InstallNPMPackages
  if not type -q npm
    LogWarning "Node.js is not installed. Installing..."
    InstallNodeJS
  end
  if not test -f "$SCRIPT_DIR/requirement/npm.txt"
    LogWarning "NPM package list not found: $SCRIPT_DIR/requirement/npm.txt"
    return 1
  end
  LogInfo "Installing NPM packages"
  set packages (cat "$SCRIPT_DIR/requirement/npm.txt" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$')
  set total (count $packages)
  set current 0
  for package in $packages
    set current (math $current + 1)
    LogInfo "[$current/$total] Installing: $package"
    npm install -g $package
  end
  LogSuccess "Completed installing NPM packages"
end

function UninstallNPMPackages
  if not type -q npm
    LogWarning "Node.js is not installed"
    return 1
  end
  if not test -f "$SCRIPT_DIR/requirement/npm.txt"
    LogWarning "NPM package list not found: $SCRIPT_DIR/requirement/npm.txt"
    return 1
  end
  LogInfo "Uninstalling NPM packages"
  set packages (cat "$SCRIPT_DIR/requirement/npm.txt" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$')
  set total (count $packages)
  set current 0
  for package in $packages
    set current (math $current + 1)
    LogInfo "[$current/$total] Uninstalling: $package"
    npm uninstall -g $package
  end
  LogSuccess "Completed uninstalling NPM packages"
end

function ShowMenu
  echo ""
  echo "INSTALL:"
  echo "  1. Install Fisher"
  echo "  2. Install Fisher plugins"
  echo "  3. Install Node.js LTS"
  echo "  4. Install NPM packages"
  echo "  5. Install all"
  echo ""
  echo "UNINSTALL:"
  echo "  6. Uninstall Fisher plugins"
  echo "  7. Uninstall Node.js LTS"
  echo "  8. Uninstall NPM packages"
  echo "  9. Uninstall all"
  echo ""
  echo "  q. Quit"
  echo ""
end

function InstallAll
  InstallFisher
  InstallFisherPlugins
  InstallNodeJS
  InstallNPMPackages
  LogSuccess "All packages installed successfully"
end

function UninstallAll
  UninstallNPMPackages
  UninstallNodeJS
  UninstallFisherPlugins
  LogSuccess "All packages uninstalled successfully"
end

function Main
  if not CheckInstallCompatibility
    exit 1
  end
  if not CheckFishShell
    exit 1
  end
  while true
    ShowMenu
    read -P "Enter your choice: " choice
    switch $choice
      case 1
        InstallFisher
      case 2
        InstallFisherPlugins
      case 3
        InstallNodeJS
      case 4
        InstallNPMPackages
      case 5
        InstallAll
      case 6
        UninstallFisherPlugins
      case 7
        UninstallNodeJS
      case 8
        UninstallNPMPackages
      case 9
        UninstallAll
      case q
        break
      case '*'
        LogWarning "Invalid choice. Please try again."
    end
  end
end

Main
