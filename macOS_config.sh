#!/bin/bash

# .:: Logging Setup ::.
LOG_FILE="installation_log.log"
touch "$LOG_FILE"
echo "--- Installation Log Started: $(date) ---" > "$LOG_FILE"
exec > >(tee -i -a "$LOG_FILE") 2>&1

# .:: Configuration & Colors ::.
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$XDG_CONFIG_HOME"

# .:: Helper Functions ::.
print_header() {
    echo -e "\n${BLUE}==================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}==================================================${NC}\n"
}

print_step() {
    echo -e "${YELLOW}➜ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✔ $1${NC}"
}

print_error() {
    echo -e "${RED}✖ $1${NC}"
}

# .:: 0. Pre-Flight Check ::.
if [[ "$TERM_PROGRAM" != "Apple_Terminal" ]]; then
    clear
    print_error "Wrong Terminal Detected!"
    echo -e "Please run this script from the default ${YELLOW}Apple Terminal${NC} app."
    exit 1
fi

# .:: 1. Clear & Banner ::.
clear
echo -e "${BLUE}"
echo "   .:: Macbook Installation and Configuration ::."
echo "       Host: $(scutil --get ComputerName) | User: $(whoami)"
echo -e "${NC}"

print_step "Requesting sudo access..."
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# .:: 2. Create Directories ::.
print_header "Creating Directory Structure"
if [ ! -d "$HOME/Developer" ]; then
    print_step "Creating ~/Developer folder..."
    mkdir -p "$HOME/Developer"
    print_success "Created $HOME/Developer"
else
    echo "~/Developer already exists."
fi

# .:: 3. System Updates ::.
print_header "System Updates"
print_step "Updating macOS..."
sudo softwareupdate -i -a --agree-to-license

# .:: 4. Uninstall Bloatware ::.
print_header "Removing Default Apps"
APPS_TO_REMOVE=(
    "/Applications/GarageBand.app"
    "/Applications/iMovie.app"
    "/Applications/Keynote.app"
    "/Applications/Pages.app"
    "/Applications/Numbers.app"
)

for app in "${APPS_TO_REMOVE[@]}"; do
    if [ -d "$app" ]; then
        print_step "Removing $app..."
        sudo rm -rf "$app"
        print_success "Removed $app"
    else
        echo "  - $app not found"
    fi
done

# .:: 5. Install Homebrew ::.
print_header "Installing Homebrew"
if ! command -v brew &> /dev/null; then
    print_step "Downloading Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    print_success "Homebrew is already installed"
fi
brew update

# .:: 6. Git Configuration ::.
print_header "Git Configuration (XDG Compliant)"
mkdir -p "$XDG_CONFIG_HOME/git"
export GIT_CONFIG_GLOBAL="$XDG_CONFIG_HOME/git/config"

if [ -z "$(git config --global user.name)" ]; then
    echo -e "${CYAN}Let's configure Git.${NC}"
    echo -ne "Enter your Git Name: "
    read GIT_NAME < /dev/tty
    echo -ne "Enter your Git Email: "
    read GIT_EMAIL < /dev/tty

    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    git config --global credential.helper osxkeychain
    git config --global init.defaultBranch main
fi
print_success "Git configured at $XDG_CONFIG_HOME/git/config"

# .:: 7. Install Tools & Apps ::.
print_header "Installing Applications"

# Note: Added 'zoxide' to the list as it is used in the new zshrc
FORMULAE=(git mas tree wget starship macchina htop btop neovim zsh-autosuggestions zsh-syntax-highlighting fzf zoxide)
CASKS=(ghostty appcleaner itsycal spotify whatsapp visual-studio-code microsoft-teams alt-tab google-chrome onedrive)
FONTS=(font-hack-nerd-font font-jetbrains-mono-nerd-font font-fira-code-nerd-font font-meslo-lg-nerd-font font-sauce-code-pro-nerd-font)

print_step "Installing Command Line Tools..."
for tool in "${FORMULAE[@]}"; do brew install "$tool"; done

print_step "Installing GUI Applications..."
for app in "${CASKS[@]}"; do brew install "$app"; done

print_step "Installing Nerd Fonts..."
for font in "${FONTS[@]}"; do brew install "$font"; done

# .:: 8. Configuration Generation ::.
print_header "Generating Config Files"

# -> Ghostty Config
mkdir -p "$XDG_CONFIG_HOME/ghostty"
GHOSTTY_CONFIG="$XDG_CONFIG_HOME/ghostty/config"

if [ ! -f "$GHOSTTY_CONFIG" ]; then
    print_step "Creating Ghostty config..."
    cat <<EOF > "$GHOSTTY_CONFIG"
# Ghostty Config
### My GhosTTY Custom Configuration ###

font-family = "JetBrains Mono"
font-size = 12
cursor-style = block
theme = Catppuccin Frappe
shell-integration = detect
shell-integration-features = no-cursor,sudo,title
window-padding-balance = true
window-save-state = never
macos-titlebar-style = transparent
window-colorspace = "display-p3"
window-height = 35
window-width = 135
window-decoration = client
EOF
fi

# -> Starship Config
mkdir -p "$XDG_CONFIG_HOME/starship"
STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/starship.toml"
if [ ! -f "$STARSHIP_CONFIG" ]; then
    print_step "Creating Starship config..."
    cat <<EOF > "$STARSHIP_CONFIG"
[character]
success_symbol = "[➜](bold green)"
error_symbol = "[✗](bold red)"
[package]
disabled = true
EOF
fi

# -> VS Code XDG enforcement
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
XDG_VSCODE_DIR="$XDG_CONFIG_HOME/Code/User"

if [ -d "$HOME/Library/Application Support/Code" ]; then
    print_step "Relocating VS Code config..."
    pkill -f "Visual Studio Code"
    mkdir -p "$XDG_VSCODE_DIR"
    if [ -f "$VSCODE_USER_DIR/settings.json" ]; then
        mv "$VSCODE_USER_DIR/settings.json" "$XDG_VSCODE_DIR/"
    fi
    rm -rf "$VSCODE_USER_DIR"
    ln -s "$XDG_VSCODE_DIR" "$VSCODE_USER_DIR"
    print_success "VS Code linked to ~/.config/Code/User"
fi

# -> ZSH Configuration
print_step "Configuring Zsh Structure..."
ZSH_CONFIG_DIR="$XDG_CONFIG_HOME/zsh"
mkdir -p "$ZSH_CONFIG_DIR"

# 1. Create .zsh_alias (Required for zshrc sourcing)
ALIAS_FILE="$ZSH_CONFIG_DIR/.zsh_alias"
if [ ! -f "$ALIAS_FILE" ]; then
    print_step "Creating .zsh_alias..."
    cat <<EOF > "$ALIAS_FILE"
# Aliases
alias cls="clear"
alias ll="ls -lgha"
alias update="brew update && brew upgrade && mas upgrade"
alias g="git"
alias ..="cd .."
alias ...="cd ../.."
alias dev="cd \$HOME/Developer"
EOF
fi

# 2. Create .zprofile in config dir
ZPROFILE="$ZSH_CONFIG_DIR/.zprofile"
print_step "Creating .zprofile..."
cat <<EOF > "$ZPROFILE"
### My custom zsh profile ### 
  
# XDG Paths 
export XDG_CONFIG_HOME="\$HOME/.config"
export XDG_CACHE_HOME="\$HOME/.cache"
export XDG_DATA_HOME="\$HOME/.local/share"

# Path Configuration
eval "\$(/opt/homebrew/bin/brew shellenv)"
export PATH="\$HOME/.local/bin:\$PATH"
export DEV="\$HOME/Developer"
 
# zsh config directory 
export ZDOTDIR=\$HOME/.config/zsh

### End of File ### 
EOF

# 3. Link .zprofile to Home
print_step "Linking .zprofile to ~/"
rm -f "$HOME/.zprofile"
ln -s "$ZPROFILE" "$HOME/.zprofile"

# 4. Create .zshrc in config dir
ZSHRC="$ZSH_CONFIG_DIR/.zshrc"
print_step "Creating .zshrc..."
# Back up existing ~/.zshrc if it exists (and isn't the new one)
if [ -f "$HOME/.zshrc" ]; then 
    mv "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%s)"
    print_step "Backed up old ~/.zshrc"
fi

cat <<EOF > "$ZSHRC"
### My custom zshrc ### 
# macchina 
macchina  

# CLI Editor
export EDITOR="nvim"  

# Git Config
export GIT_CONFIG_GLOBAL="\$XDG_CONFIG_HOME/git/config"  

# Homebrew modifications 
export HOMEBREW_NO_ENV_HINTS=1  

# set Startship config location 
export STARSHIP_CONFIG=~/.config/starship/starship.toml  

# Alias Files 
source \$ZDOTDIR/.zsh_alias  

# zsh Auto Suggestions 
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh  

# zsh Syntax Highlighting 
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh  

# Startship 
eval "\$(starship init zsh)"  

# zoxide 
eval "\$(zoxide init zsh)" 

# fzf 
eval "\$(fzf --zsh)"  

# History
HISTFILE="\$XDG_DATA_HOME/zsh/history"  
mkdir -p "\$(dirname "\$HISTFILE")"  
HISTSIZE=10000  
SAVEHIST=10000  
setopt SHARE_HISTORY APPEND_HISTORY INC_APPEND_HISTORY HIST_IGNORE_DUPS  

### End of File ### 
EOF
print_success "Zsh configuration complete!"

# .:: 9. System Configurations ::.
print_header "Configuring System Preferences"

# Privacy: Disable Analytics & Ads
print_step "Disabling Analytics & Personalized Ads..."
sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory AutoSubmit -bool false
sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory ThirdPartyDataSubmit -bool false
defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false
defaults write com.apple.AdLib allowIdentifierForAdvertising -bool false
defaults write com.apple.AdLib personalizedAdsMigrated -bool false

# UI & Behavior: General
print_step "Configuring General UI Behavior..."
# Scroll Bars
defaults write NSGlobalDomain AppleScrollerPagingBehavior -bool true
defaults write NSGlobalDomain AppleShowScrollBars -string "Always"
# Sidebar Icon Size (Global)
defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 1
# Document Behavior: Prefer Tabs "Always"
defaults write NSGlobalDomain AppleWindowTabbingMode -string "always"
# Document Behavior: Ask to keep changes when closing
defaults write NSGlobalDomain NSCloseAlwaysConfirmsChanges -bool true

# Desktop & Stage Manager
print_step "Configuring Desktop & Stage Manager..."
# Hide icons on the standard desktop
defaults write com.apple.finder CreateDesktop -bool false
# Stage Manager: Hide Widgets
defaults write com.apple.WindowManager StandardHideWidgets -bool true
# Stage Manager: Hide "Recent Apps" strip (left side)
defaults write com.apple.WindowManager AutoHide -bool true
# Stage Manager: Hide Desktop Items
defaults write com.apple.WindowManager StandardHideDesktopIcons -bool true
defaults write com.apple.WindowManager HideDesktop -bool true
# Stage Manager: Group windows from an application "All at Once"
defaults write com.apple.WindowManager AppWindowGroupingBehavior -int 1

# Trackpad
print_step "Configuring Trackpad..."
# Tap to Click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
# Disable Natural Scrolling
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
# Dragging (No Drag Lock)
defaults write com.apple.AppleMultitouchTrackpad Dragging -bool true
defaults write com.apple.AppleMultitouchTrackpad DragLock -bool false
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Dragging -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad DragLock -bool false

# Gestures & Mission Control
print_step "Configuring Gestures & Mission Control..."
# 3-Finger Swipes (Mission Control & Expose)
defaults write com.apple.dock showMissionControlGestureEnabled -bool true
defaults write com.apple.dock showAppExposeGestureEnabled -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture -int 2
# Mission Control: Group windows by application
defaults write com.apple.dock expose-group-by-app -bool true

# Window Manager Actions
print_step "Configuring Window Manager..."
# Double-click Title Bar to Fill (Zoom)
defaults write NSGlobalDomain AppleActionOnDoubleClick -string "Maximize"

# Dock Settings
print_step "Configuring Dock..."
defaults write com.apple.dock orientation -string "left"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 30
defaults write com.apple.dock minimize-to-application -bool true
# Animation: Scale (not Genie)
defaults write com.apple.dock mineffect -string "scale"

# Restart services to apply changes
print_step "Restarting System Services..."
killall cfprefsd
killall Dock
killall Finder

# .:: 10. Final Cleanup ::.
print_header "Cleanup"
mas upgrade
brew cleanup
echo "--- Installation Log Ended: $(date) ---" >> "$LOG_FILE"

print_header "Installation Complete!"
echo -e "${GREEN}All tasks finished.${NC}"
