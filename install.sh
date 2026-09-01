#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

echo "Stopping any running gesture daemon..."
"$REPO_DIR"/usr/bin/phosh-overlay-shutdown.sh || true

echo "Installing files..."
sudo mkdir -p /etc/phosh-overlay-gestures /etc/xdg/autostart
sudo rm -f /etc/phosh-overlay-gestures/wofi-config /etc/phosh-overlay-gestures/wofi-style.css
sudo cp -r "$REPO_DIR"/etc/phosh-overlay-gestures/. /etc/phosh-overlay-gestures/
sudo cp "$REPO_DIR"/etc/xdg/autostart/*.desktop /etc/xdg/autostart/
sudo cp "$REPO_DIR"/usr/bin/*.sh /usr/bin/
sudo chmod +x /usr/bin/phosh-overlay-*.sh

echo "Warming up drawer icon/app cache..."
/usr/bin/phosh-overlay-drawer-list.sh > /dev/null || true

echo "Done. Run phosh-overlay-launch.sh to start it."
