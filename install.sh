#!/bin/bash

# WSL Copy-Paste Alias Installer
# Automatically detects shell and installs copy/paste aliases

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}WSL Copy-Paste Alias Installer${NC}"
echo "======================================"

# Check if running in WSL
if ! grep -qi microsoft /proc/version 2>/dev/null; then
    echo -e "${RED}Warning: This script is designed for WSL (Windows Subsystem for Linux)${NC}"
    echo "It may not work correctly on other systems."
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 1
    fi
fi

# Detect current shell
CURRENT_SHELL=$(basename "$SHELL")
echo -e "${BLUE}Detected shell: ${YELLOW}$CURRENT_SHELL${NC}"

# Determine config file based on shell
case "$CURRENT_SHELL" in
    "bash")
        CONFIG_FILE="$HOME/.bashrc"
        SOURCE_CMD="source ~/.bashrc"
        ;;
    "zsh")
        CONFIG_FILE="$HOME/.zshrc"
        SOURCE_CMD="source ~/.zshrc"
        ;;
    *)
        echo -e "${YELLOW}Unsupported shell: $CURRENT_SHELL${NC}"
        echo "Supported shells: bash, zsh"
        echo "Please manually add the aliases to your shell configuration file."
        exit 1
        ;;
esac

echo -e "${BLUE}Configuration file: ${YELLOW}$CONFIG_FILE${NC}"

# Get alias names from user
echo ""
echo -e "${BLUE}Choose alias names for copy and paste commands:${NC}"
read -p "Enter alias name for copy command (default: copy): " COPY_ALIAS
read -p "Enter alias name for paste command (default: paste): " PASTE_ALIAS

# Set defaults if empty
COPY_ALIAS=${COPY_ALIAS:-copy}
PASTE_ALIAS=${PASTE_ALIAS:-paste}

echo -e "${BLUE}Using aliases: ${YELLOW}$COPY_ALIAS${NC} and ${YELLOW}$PASTE_ALIAS${NC}"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Config file $CONFIG_FILE does not exist. Creating it...${NC}"
    touch "$CONFIG_FILE"
fi

# Check if aliases already exist
if grep -q "alias $COPY_ALIAS=" "$CONFIG_FILE" || grep -q "alias $PASTE_ALIAS=" "$CONFIG_FILE"; then
    echo -e "${YELLOW}Aliases '$COPY_ALIAS' or '$PASTE_ALIAS' already exist in $CONFIG_FILE${NC}"
    read -p "Do you want to replace them? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 1
    fi
    
    # Remove existing aliases
    echo -e "${BLUE}Removing existing aliases...${NC}"
    sed -i "/^alias $COPY_ALIAS=/d" "$CONFIG_FILE"
    sed -i "/^alias $PASTE_ALIAS=/d" "$CONFIG_FILE"
    # Also remove any lines that contain the PowerShell commands (in case they're split)
    sed -i '/powershell\.exe.*Set-Clipboard/d' "$CONFIG_FILE"
    sed -i '/powershell\.exe.*Get-Clipboard/d' "$CONFIG_FILE"
fi

# Add aliases to config file
echo -e "${BLUE}Adding $COPY_ALIAS/$PASTE_ALIAS aliases to $CONFIG_FILE...${NC}"

cat >> "$CONFIG_FILE" << EOF

# WSL Copy-Paste Aliases (wsl-copy-paste)
# Perfect clipboard integration between WSL and Windows
alias $COPY_ALIAS='sed "s/$/\r/" | powershell.exe -noprofile -command "\$stdin = [Console]::OpenStandardInput(); \$bytes = [System.IO.MemoryStream]::new(); \$stdin.CopyTo(\$bytes); \$text = [System.Text.Encoding]::UTF8.GetString(\$bytes.ToArray()); Set-Clipboard -Value \$text"'
alias $PASTE_ALIAS='powershell.exe -noprofile -command "\$text = Get-Clipboard -Raw; \$bytes = [System.Text.Encoding]::UTF8.GetBytes(\$text); [Console]::OpenStandardOutput().Write(\$bytes, 0, \$bytes.Length)" | sed "s/\r$//"'
EOF

echo -e "${GREEN}✅ Aliases successfully added to $CONFIG_FILE${NC}"
echo ""
echo -e "${BLUE}To activate the aliases in your current session, run:${NC}"
echo -e "${YELLOW}$SOURCE_CMD${NC}"
echo ""
echo -e "${BLUE}Or simply open a new terminal.${NC}"
echo ""
echo -e "${BLUE}Usage examples:${NC}"
echo -e "  ${YELLOW}echo 'Hello World' | $COPY_ALIAS${NC}    # Copy text to Windows clipboard"
echo -e "  ${YELLOW}$PASTE_ALIAS${NC}                        # Paste from Windows clipboard"
echo -e "  ${YELLOW}cat file.txt | $COPY_ALIAS${NC}          # Copy file contents to clipboard"
echo ""
echo -e "${GREEN}Installation complete! 🎉${NC}"
