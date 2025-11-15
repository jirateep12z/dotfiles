# Dotfiles

Hey there 👋 These are the dotfiles I use every day to make my work life easier. I'm always tinkering with them and finding cool new tricks to speed things up. While these tools are my personal favorites, I thought I'd share them with you - who knows, you might find some hidden gems in here too. Feel free to poke around and borrow any ideas that catch your eye. And hey, if you've got any awesome tips of your own, I'd love to hear them.

> **⚠️ Warning**: Don't blindly use my settings unless you know what that entails. Use at your own risk!

![terminal-standby](./uploads/terminal-standby.png)

## 🚀 Quick Start

### macOS / Linux

```bash
# 1. Check if Git is installed
git --version

# 2. If Git is not installed, install Homebrew first
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3. Install Git
brew install git

# 4. Clone this repository
git clone https://github.com/jirateep12z/dotfiles.git $HOME/.dotfiles
cd $HOME/.dotfiles

# 5. Make scripts executable
chmod +x *.sh script/*.sh

# 6. Run the installation script (interactive menu)
./install.sh

# 7. (Optional) Install Fisher plugins for Fish shell
./fisher.sh
```

### Windows

```powershell
# 1. Open PowerShell as Administrator

# 2. Check if Git is installed
git --version

# 3. If Git is not installed, install Scoop first
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
$scoop_installer = "$env:TEMP\install-scoop.ps1"
Invoke-RestMethod -Uri https://get.scoop.sh -OutFile $scoop_installer
& $scoop_installer
Remove-Item $scoop_installer -Force

# 4. Install Git
scoop install git

# 5. Close and reopen PowerShell, then clone this repository
git clone https://github.com/jirateep12z/dotfiles.git $ENV:USERPROFILE\.dotfiles
cd $ENV:USERPROFILE\.dotfiles

# 6. Run the installation script (interactive menu)
.\install.ps1
```

## 📝 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions, issues and feature requests are welcome!

## ⭐ Show your support

Give a ⭐️ if this project helped you!

## 📝 Author

**Made with ❤️ by @jirateep12z**
