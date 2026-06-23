set -e

APP_DIR="$HOME/.aims-notifs"
BIN_DIR="$HOME/.local/bin"

echo "Installing IITH AIMS Grade Notification System..."

mkdir -p "$APP_DIR"
mkdir -p "$BIN_DIR"

# Copy application files
cp main.py "$APP_DIR/"
cp requirements.txt "$APP_DIR/"
cp setup.py "$APP_DIR/"

# Install CLI
cp aims-notifs "$BIN_DIR/"
chmod +x "$BIN_DIR/aims-notifs"

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

echo "Next step:"
echo "Run aims-notifs setup"
