#!/bin/bash

# WSL Copy-Paste Alias Installer
# Automatically detects shell and installs copy/paste aliases

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
CONFIG_FILE=""
SOURCE_CMD=""
CURRENT_SHELL=""

# Function to print header
print_header() {
    echo -e "${BLUE}WSL Copy-Paste Alias Installer${NC}"
    echo "======================================"
}

# Function to check if running in WSL
check_wsl_environment() {
    if ! grep -qi microsoft /proc/version 2>/dev/null; then
        echo -e "${RED}Warning: This script is designed for WSL (Windows Subsystem for Linux)${NC}"
        echo "It may not work correctly on other systems."
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r < /dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 1
        fi
    fi
}

# Function to detect shell and set config file
detect_shell() {
    CURRENT_SHELL=$(basename "$SHELL")
    echo -e "${BLUE}Detected shell: ${YELLOW}$CURRENT_SHELL${NC}"

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
}

# Function to create config file if it doesn't exist
ensure_config_file() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Config file $CONFIG_FILE does not exist. Creating it...${NC}"
        touch "$CONFIG_FILE"
    fi
}

# Function to check if aliases are already configured
check_existing_configuration() {
    if grep -q "# WSL Copy-Paste Aliases (wsl-copy-paste)" "$CONFIG_FILE"; then
        return 0  # Already configured
    else
        return 1  # Not configured
    fi
}

# Function to remove existing aliases
remove_existing_aliases() {
    echo -e "${BLUE}Removing existing aliases...${NC}"
    # Remove existing WSL copy-paste block
    sed -i '/# WSL Copy-Paste Aliases (wsl-copy-paste)/,/^$/d' "$CONFIG_FILE"
    # Clean up any remaining PowerShell commands
    sed -i '/powershell\.exe.*Set-Clipboard/d' "$CONFIG_FILE"
    sed -i '/powershell\.exe.*Get-Clipboard/d' "$CONFIG_FILE"
}

# Function to handle existing configuration
handle_existing_configuration() {
    echo -e "${GREEN}WSL copy-paste aliases are already configured!${NC}"
    echo ""
    echo -e "${BLUE}What would you like to do?${NC}"
    echo "1) Reconfigure aliases"
    echo "2) Remove existing aliases"
    echo "3) Exit"
    read -p "Please choose an option (1/2/3): " -n 1 -r OPTION < /dev/tty
    echo ""
    
    case "$OPTION" in
        "1")
            echo -e "${BLUE}Reconfiguring aliases...${NC}"
            remove_existing_aliases
            install_new_aliases
            ;;
        "2")
            remove_existing_aliases
            echo -e "${GREEN}✅ WSL copy-paste aliases removed successfully${NC}"
            echo -e "${BLUE}To apply changes, run: ${YELLOW}$SOURCE_CMD${NC}"
            exit 0
            ;;
        "3")
            echo "Exit selected. No changes made."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Exiting.${NC}"
            exit 1
            ;;
    esac
}

# Function to get alias names from user
get_alias_names() {
    echo ""
    echo -e "${BLUE}Choose alias names for copy and paste commands:${NC}"
    read -p "Enter alias name for copy command (default: copy): " COPY_ALIAS < /dev/tty
    read -p "Enter alias name for paste command (default: paste): " PASTE_ALIAS < /dev/tty

    # Set defaults if empty
    COPY_ALIAS=${COPY_ALIAS:-copy}
    PASTE_ALIAS=${PASTE_ALIAS:-paste}

    echo -e "${BLUE}Using aliases: ${YELLOW}$COPY_ALIAS${NC} and ${YELLOW}$PASTE_ALIAS${NC}"
}

# Function to add aliases to config file
add_aliases_to_config() {
    echo -e "${BLUE}Adding $COPY_ALIAS/$PASTE_ALIAS aliases to $CONFIG_FILE...${NC}"

    cat >> "$CONFIG_FILE" << EOF

# WSL Copy-Paste Aliases (wsl-copy-paste)
# Perfect clipboard integration between WSL and Windows
alias $COPY_ALIAS='powershell.exe -noprofile -command "\$stdin = [Console]::OpenStandardInput(); \$bytes = [System.IO.MemoryStream]::new(); \$stdin.CopyTo(\$bytes); \$text = [System.Text.Encoding]::UTF8.GetString(\$bytes.ToArray()); \$text = \$text -replace \"\`n\", \"\`r\`n\"; Set-Clipboard -Value \$text"'
alias $PASTE_ALIAS='powershell.exe -noprofile -command "\$text = Get-Clipboard -Raw; \$bytes = [System.Text.Encoding]::UTF8.GetBytes(\$text); [Console]::OpenStandardOutput().Write(\$bytes, 0, \$bytes.Length)" | tr -d "\r"'
EOF
}

# Function to show completion message
show_completion_message() {
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
}

# Function to install new aliases
install_new_aliases() {
    get_alias_names
    add_aliases_to_config
    show_completion_message
}

# Main function
main() {
    print_header
    check_wsl_environment
    detect_shell
    ensure_config_file
    
    if check_existing_configuration; then
        handle_existing_configuration
    else
        install_new_aliases
    fi
}

# Run main function
main