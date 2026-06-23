set -e

APP_DIR="$HOME/.aims-notifs"
BIN_DIR="$HOME/.local/bin"
COMPLETIONS_DIR="$HOME/.local/share/bash-completion/completions"

echo "Installing IITH AIMS Grade Notification System..."

mkdir -p "$APP_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$COMPLETIONS_DIR"

# Copy application files
cp main.py "$APP_DIR/"
cp requirements.txt "$APP_DIR/"
cp setup.py "$APP_DIR/"

# Install CLI
cp aims-notifs "$BIN_DIR/"
chmod +x "$BIN_DIR/aims-notifs"

# Bash completion

cat > "$COMPLETIONS_DIR/aims-notifs" <<'EOF'
_aims_notifs_completion()
{
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local commands="setup start stop status run-now logs uninstall"

    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
}

complete -F _aims_notifs_completion aims-notifs
EOF

echo
echo "Installation complete."
echo

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "WARNING: $BIN_DIR is not on your PATH."
    echo "Add the following line to ~/.bashrc:"
    echo
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo
fi

echo "Next steps:"
echo "  Create an App Password (on the email ID to which you want to receive notifications)"
echo "    Refer to https://support.google.com/mail/answer/185833"
echo "  Switch on IITH VPN, and keep it on (if applicable)"
echo "    Refer to https://docs.google.com/document/u/0/d/e/2PACX-1vQxWGsv6dhwmvx4Efq17CPyCBTvMiKd9oTJecNDy51KXIPDfdjUQq822EpBExduoPtBTQbkvtNMudqh/pub"
echo "    Run sudo wg-quick up wg0"
echo "  Run aims-notifs setup"
