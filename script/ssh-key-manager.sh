#!/usr/bin/env bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SYSTEM_OS_TYPE="$(uname -s)"
readonly OS_PATTERN_SUPPORTED="^(Darwin|Linux|MINGW|MSYS|CYGWIN)"

source "$SCRIPT_DIR/utils/logger.sh" 2>/dev/null || {
  echo "Error: Cannot load logger.sh utility" >&2
  exit 1
}

declare SSH_DIR="$HOME/.ssh"
declare KEY_TYPE="ed25519"
declare KEY_BITS=""
declare KEY_COMMENT=""
declare KEY_NAME=""
declare PASSPHRASE=""
declare NO_PASSPHRASE=false
declare ACTION=""
declare SHOW_HELP=false

ValidateSystemEnvironment() {
  if [[ ! "${SYSTEM_OS_TYPE}" =~ ${OS_PATTERN_SUPPORTED} ]]; then
    LogError "Unsupported OS: ${SYSTEM_OS_TYPE}"
    return 1
  fi
  return 0
}

ShowUsage() {
  cat << EOF
Usage: $SCRIPT_NAME <ACTION> [OPTIONS]

SSH Key Manager - Generate and manage SSH keys

ACTIONS:
  list                    List all SSH keys
  generate                Generate a new SSH key
  copy <key_name>         Copy public key to clipboard
  show <key_name>         Show public key content
  delete <key_name>       Delete SSH key pair
  test <host>             Test SSH connection to host
  add-agent <key_name>    Add key to SSH agent
  remove-agent <key_name> Remove key from SSH agent
  fingerprint <key_name>  Show key fingerprint
  config-list             List all host configurations
  config-show <host>      Show host configuration
  config-add <host>       Add host configuration to ~/.ssh/config
  config-delete <host>    Delete host configuration from ~/.ssh/config

OPTIONS:
  -h, --help              Show this help message
  -t, --type TYPE         Key type: ed25519, rsa, ecdsa (default: ed25519)
  -b, --bits BITS         Key bits for RSA (default: 4096)
  -c, --comment COMMENT   Key comment (default: user@hostname)
  -n, --name NAME         Key filename (default: id_<type>)
  -p, --passphrase PASS   Key passphrase
  --no-passphrase         Generate key without passphrase
  --ssh-dir DIR           SSH directory (default: ~/.ssh)

EXAMPLES:
  # List all SSH keys
  $SCRIPT_NAME list

  # Generate keys
  $SCRIPT_NAME generate -n github                    # Generate ed25519 key named 'github'
  $SCRIPT_NAME generate -n gitlab                    # Generate ed25519 key named 'gitlab'
  $SCRIPT_NAME generate -t rsa -b 4096 -n work       # Generate RSA 4096-bit key
  $SCRIPT_NAME generate -n deploy --no-passphrase   # Generate without passphrase
  $SCRIPT_NAME generate -c "email@example.com"       # Custom comment

  # Copy & Show
  $SCRIPT_NAME copy github                           # Copy github.pub to clipboard
  $SCRIPT_NAME show id_ed25519                       # Show public key content

  # Delete
  $SCRIPT_NAME delete github                         # Delete github key pair

  # Test connection
  $SCRIPT_NAME test git@github.com                   # Test GitHub SSH
  $SCRIPT_NAME test git@gitlab.com                   # Test GitLab SSH

  # SSH Agent
  $SCRIPT_NAME add-agent github                      # Add key to ssh-agent
  $SCRIPT_NAME remove-agent github                   # Remove key from ssh-agent

  # Fingerprint
  $SCRIPT_NAME fingerprint github                    # Show fingerprint with visual art

  # SSH Config
  $SCRIPT_NAME config-list                           # List all hosts in config
  $SCRIPT_NAME config-show github.com                # Show github.com config
  $SCRIPT_NAME config-add github.com                 # Add github.com to ~/.ssh/config
  $SCRIPT_NAME config-add gitlab.com                 # Add gitlab.com to ~/.ssh/config
  $SCRIPT_NAME config-delete github.com              # Delete github.com config
EOF
}

ParseArguments() {
  if [[ $# -eq 0 ]]; then
    SHOW_HELP=true
    return
  fi
  ACTION="$1"
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        SHOW_HELP=true
        shift
        ;;
      -t|--type)
        KEY_TYPE="$2"
        shift 2
        ;;
      -b|--bits)
        KEY_BITS="$2"
        shift 2
        ;;
      -c|--comment)
        KEY_COMMENT="$2"
        shift 2
        ;;
      -n|--name)
        KEY_NAME="$2"
        shift 2
        ;;
      -p|--passphrase)
        PASSPHRASE="$2"
        shift 2
        ;;
      --no-passphrase)
        NO_PASSPHRASE=true
        shift
        ;;
      --ssh-dir)
        SSH_DIR="$2"
        shift 2
        ;;
      -*)
        LogError "Unknown option: $1"
        ShowUsage
        exit 1
        ;;
      *)
        if [[ -z "$KEY_NAME" ]]; then
          KEY_NAME="$1"
        fi
        shift
        ;;
    esac
  done
}

ValidateSSHDirectory() {
  if [[ ! -d "$SSH_DIR" ]]; then
    LogInfo "Creating SSH directory: $SSH_DIR"
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
  fi
}

ListKeys() {
  LogInfo "SSH Keys in $SSH_DIR:"
  local found_keys=false
  while IFS= read -r pub_file; do
    if [[ -f "$pub_file" ]]; then
      found_keys=true
      local key_name=$(basename "$pub_file" .pub)
      local private_key="${pub_file%.pub}"
      local key_type=""
      local key_comment=""
      local key_fingerprint=""
      if [[ -f "$pub_file" ]]; then
        key_type=$(awk '{print $1}' "$pub_file" | sed 's/ssh-//')
        key_comment=$(awk '{print $3}' "$pub_file")
        key_fingerprint=$(ssh-keygen -lf "$pub_file" 2>/dev/null | awk '{print $2}')
      fi
      local has_private="No"
      if [[ -f "$private_key" ]]; then
        has_private="Yes"
      fi
      printf "  %-20s | %-10s | %-30s | Private: %s\n" "$key_name" "$key_type" "${key_comment:0:30}" "$has_private"
    fi
  done < <(find "$SSH_DIR" -name "*.pub" -type f 2>/dev/null | sort)
  if [[ "$found_keys" == "false" ]]; then
    LogWarning "No SSH keys found"
  fi
}

GenerateKey() {
  ValidateSSHDirectory
  if [[ -z "$KEY_NAME" ]]; then
    KEY_NAME="id_${KEY_TYPE}"
  fi
  local key_path="$SSH_DIR/$KEY_NAME"
  if [[ -f "$key_path" ]]; then
    LogWarning "Key already exists: $key_path"
    read -r -p "Overwrite? (y/N): " confirm
    if [[ "${confirm,,}" != "y" ]]; then
      LogInfo "Cancelled"
      return 1
    fi
  fi
  if [[ -z "$KEY_COMMENT" ]]; then
    local default_comment="$(whoami)@$(hostname)"
    read -r -p "Enter email or comment (default: $default_comment): " user_comment
    KEY_COMMENT="${user_comment:-$default_comment}"
  fi
  LogInfo "Generating SSH key..."
  LogKeyValue "Type" "$KEY_TYPE"
  LogKeyValue "Name" "$KEY_NAME"
  LogKeyValue "Comment" "$KEY_COMMENT"
  LogKeyValue "Path" "$key_path"
  local keygen_args=()
  keygen_args+=("-t" "$KEY_TYPE")
  keygen_args+=("-C" "$KEY_COMMENT")
  keygen_args+=("-f" "$key_path")
  if [[ "$KEY_TYPE" == "rsa" ]]; then
    local bits="${KEY_BITS:-4096}"
    keygen_args+=("-b" "$bits")
    LogKeyValue "Bits" "$bits"
  fi
  if [[ "$NO_PASSPHRASE" == "true" ]]; then
    keygen_args+=("-N" "")
    LogWarning "Generating key without passphrase"
  elif [[ -n "$PASSPHRASE" ]]; then
    keygen_args+=("-N" "$PASSPHRASE")
  fi
  if ssh-keygen "${keygen_args[@]}"; then
    chmod 600 "$key_path"
    chmod 644 "${key_path}.pub"
    LogSuccess "SSH key generated successfully!"
    LogInfo "Public key:"
    cat "${key_path}.pub"
    LogInfo "Fingerprint:"
    ssh-keygen -lf "${key_path}.pub"
  else
    LogError "Failed to generate SSH key"
    return 1
  fi
}

CopyPublicKey() {
  local key_name="$1"
  if [[ -z "$key_name" ]]; then
    LogError "Key name is required"
    return 1
  fi
  local pub_file="$SSH_DIR/${key_name}.pub"
  if [[ ! -f "$pub_file" ]]; then
    pub_file="$SSH_DIR/${key_name}"
    if [[ ! -f "$pub_file" ]]; then
      LogError "Public key not found: $key_name"
      return 1
    fi
  fi
  local pub_content=$(cat "$pub_file")
  case "$SYSTEM_OS_TYPE" in
    Darwin)
      echo -n "$pub_content" | pbcopy
      ;;
    Linux)
      if command -v xclip &>/dev/null; then
        echo -n "$pub_content" | xclip -selection clipboard
      elif command -v xsel &>/dev/null; then
        echo -n "$pub_content" | xsel --clipboard --input
      else
        LogWarning "No clipboard utility found"
        LogInfo "Public key content:"
        echo "$pub_content"
        return 1
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      echo -n "$pub_content" | clip
      ;;
  esac
  LogSuccess "Public key copied to clipboard!"
  LogKeyValue "Key" "$key_name"
}

ShowPublicKey() {
  local key_name="$1"
  if [[ -z "$key_name" ]]; then
    LogError "Key name is required"
    return 1
  fi
  local pub_file="$SSH_DIR/${key_name}.pub"
  if [[ ! -f "$pub_file" ]]; then
    pub_file="$SSH_DIR/${key_name}"
    if [[ ! -f "$pub_file" ]]; then
      LogError "Public key not found: $key_name"
      return 1
    fi
  fi
  LogInfo "Public key: $key_name"
  cat "$pub_file"
  LogInfo "Fingerprint:"
  ssh-keygen -lf "$pub_file" 2>/dev/null
}

DeleteKey() {
  local key_name="$1"
  if [[ -z "$key_name" ]]; then
    LogError "Key name is required"
    return 1
  fi
  local private_key="$SSH_DIR/$key_name"
  local public_key="$SSH_DIR/${key_name}.pub"
  if [[ ! -f "$private_key" && ! -f "$public_key" ]]; then
    LogError "Key not found: $key_name"
    return 1
  fi
  LogWarning "About to delete:"
  [[ -f "$private_key" ]] && LogIndent 1 "Private: $private_key"
  [[ -f "$public_key" ]] && LogIndent 1 "Public: $public_key"
  read -r -p "Are you sure? (y/N): " confirm
  if [[ "${confirm,,}" != "y" ]]; then
    LogInfo "Cancelled"
    return 1
  fi
  local deleted=0
  if [[ -f "$private_key" ]]; then
    rm "$private_key" && ((deleted++))
  fi
  if [[ -f "$public_key" ]]; then
    rm "$public_key" && ((deleted++))
  fi
  LogSuccess "Deleted $deleted file(s)"
}

TestConnection() {
  local host="$1"
  if [[ -z "$host" ]]; then
    LogError "Host is required"
    return 1
  fi
  LogInfo "Testing SSH connection to: $host"
  ssh -T -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$host" 2>&1
  local exit_code=$?
  if [[ $exit_code -eq 0 || $exit_code -eq 1 ]]; then
    LogSuccess "Connection successful!"
  else
    LogError "Connection failed (exit code: $exit_code)"
  fi
}

AddToAgent() {
  local key_name="$1"
  if [[ -z "$key_name" ]]; then
    LogError "Key name is required"
    return 1
  fi
  local private_key="$SSH_DIR/$key_name"
  if [[ ! -f "$private_key" ]]; then
    LogError "Private key not found: $key_name"
    return 1
  fi
  if ! pgrep -x ssh-agent &>/dev/null; then
    LogWarning "ssh-agent not running, starting..."
    eval "$(ssh-agent -s)" &>/dev/null
  fi
  LogInfo "Adding key to ssh-agent: $key_name"
  if ssh-add "$private_key" 2>/dev/null; then
    LogSuccess "Key added to ssh-agent"
  else
    LogError "Failed to add key to ssh-agent"
    return 1
  fi
}

RemoveFromAgent() {
  local key_name="$1"
  if [[ -z "$key_name" ]]; then
    LogError "Key name is required"
    return 1
  fi
  local private_key="$SSH_DIR/$key_name"
  if [[ ! -f "$private_key" ]]; then
    LogError "Private key not found: $key_name"
    return 1
  fi
  LogInfo "Removing key from ssh-agent: $key_name"
  if ssh-add -d "$private_key" 2>/dev/null; then
    LogSuccess "Key removed from ssh-agent"
  else
    LogError "Failed to remove key from ssh-agent"
    return 1
  fi
}

ShowFingerprint() {
  local key_name="$1"
  if [[ -z "$key_name" ]]; then
    LogError "Key name is required"
    return 1
  fi
  local pub_file="$SSH_DIR/${key_name}.pub"
  if [[ ! -f "$pub_file" ]]; then
    pub_file="$SSH_DIR/${key_name}"
    if [[ ! -f "$pub_file" ]]; then
      LogError "Public key not found: $key_name"
      return 1
    fi
  fi
  LogInfo "Fingerprint for: $key_name"
  ssh-keygen -lf "$pub_file" 2>/dev/null
  LogInfo "Visual fingerprint:"
  ssh-keygen -lvf "$pub_file" 2>/dev/null
}

ConfigListHosts() {
  local config_file="$SSH_DIR/config"
  if [[ ! -f "$config_file" ]]; then
    LogWarning "SSH config file not found: $config_file"
    return
  fi
  LogInfo "SSH Hosts in $config_file:"
  grep -E "^Host " "$config_file" | sed 's/^Host /  - /'
}

ConfigShowHost() {
  local host="$1"
  if [[ -z "$host" ]]; then
    LogError "Host name is required"
    return 1
  fi
  local config_file="$SSH_DIR/config"
  if [[ ! -f "$config_file" ]]; then
    LogError "SSH config file not found: $config_file"
    return 1
  fi
  LogInfo "Configuration for: $host"
  awk "/^Host $host\$/{flag=1; next} /^Host /{flag=0} flag" "$config_file"
  if [[ $? -ne 0 ]]; then
    LogWarning "Host not found: $host"
    return 1
  fi
}

ConfigAddHost() {
  local host="$1"
  if [[ -z "$host" ]]; then
    LogError "Host name is required"
    return 1
  fi
  local config_file="$SSH_DIR/config"
  ValidateSSHDirectory
  if [[ ! -f "$config_file" ]]; then
    LogInfo "Creating SSH config file: $config_file"
    touch "$config_file"
    chmod 600 "$config_file"
  fi
  if grep -q "^Host $host\$" "$config_file"; then
    LogWarning "Host already exists: $host"
    read -r -p "Update? (y/N): " confirm
    if [[ "${confirm,,}" != "y" ]]; then
      LogInfo "Cancelled"
      return 1
    fi
    sed -i "/^Host $host\$/,/^Host /{ /^Host /!d; }; /^Host $host\$/d" "$config_file"
  fi
  local hostname port user key_name
  echo "Select port:"
  echo "  1) 22  - Standard SSH (default)"
  echo "  2) 443 - SSH over HTTPS (firewall bypass)"
  read -r -p "Port [1-2] (default: 1): " port_choice
  case "$port_choice" in
    2|443)
      port="443"
      case "$host" in
        github.com|github)
          hostname="ssh.github.com"
          LogInfo "Using GitHub alternate SSH: ssh.github.com:443"
          ;;
        gitlab.com|gitlab)
          hostname="altssh.gitlab.com"
          LogInfo "Using GitLab alternate SSH: altssh.gitlab.com:443"
          ;;
        *)
          read -r -p "Hostname (default: $host): " hostname
          hostname="${hostname:-$host}"
          ;;
      esac
      ;;
    *)
      port="22"
      read -r -p "Hostname (default: $host): " hostname
      hostname="${hostname:-$host}"
      ;;
  esac
  read -r -p "User (default: git): " user
  user="${user:-git}"
  local default_key_name="${host%.com}"
  default_key_name="${default_key_name%.org}"
  default_key_name="${default_key_name%.net}"
  read -r -p "IdentityFile name (default: ~/.ssh/$default_key_name): " key_name
  key_name="${key_name:-~/.ssh/$default_key_name}"
  cat >> "$config_file" << EOF
Host $host
    Hostname $hostname
    Port $port
    User $user
    IdentityFile $key_name
EOF
  LogSuccess "Host configuration added: $host"
  LogKeyValue "Hostname" "$hostname"
  LogKeyValue "Port" "$port"
  LogKeyValue "User" "$user"
  LogKeyValue "IdentityFile" "$key_name"
}

ConfigDeleteHost() {
  local host="$1"
  if [[ -z "$host" ]]; then
    LogError "Host name is required"
    return 1
  fi
  local config_file="$SSH_DIR/config"
  if [[ ! -f "$config_file" ]]; then
    LogError "SSH config file not found: $config_file"
    return 1
  fi
  if ! grep -q "^Host $host\$" "$config_file"; then
    LogError "Host not found: $host"
    return 1
  fi
  LogWarning "About to delete host configuration: $host"
  read -r -p "Are you sure? (y/N): " confirm
  if [[ "${confirm,,}" != "y" ]]; then
    LogInfo "Cancelled"
    return 1
  fi
  sed -i "/^Host $host\$/,/^Host /{ /^Host /!d; }; /^Host $host\$/d" "$config_file"
  LogSuccess "Host configuration deleted: $host"
}

Main() {
  ParseArguments "$@"
  if [[ "$SHOW_HELP" == "true" ]]; then
    ShowUsage
    exit 0
  fi
  if ! ValidateSystemEnvironment; then
    exit 1
  fi
  case "$ACTION" in
    list)
      ListKeys
      ;;
    generate)
      GenerateKey
      ;;
    copy)
      CopyPublicKey "$KEY_NAME"
      ;;
    show)
      ShowPublicKey "$KEY_NAME"
      ;;
    delete)
      DeleteKey "$KEY_NAME"
      ;;
    test)
      TestConnection "$KEY_NAME"
      ;;
    add-agent)
      AddToAgent "$KEY_NAME"
      ;;
    remove-agent)
      RemoveFromAgent "$KEY_NAME"
      ;;
    fingerprint)
      ShowFingerprint "$KEY_NAME"
      ;;
    config-list)
      ConfigListHosts
      ;;
    config-show)
      ConfigShowHost "$KEY_NAME"
      ;;
    config-add)
      ConfigAddHost "$KEY_NAME"
      ;;
    config-delete)
      ConfigDeleteHost "$KEY_NAME"
      ;;
    *)
      LogError "Unknown action: $ACTION"
      ShowUsage
      exit 1
      ;;
  esac
  LogSuccess "Done!"
}

Main "$@"
