#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

echo "Stopping any running gesture daemon..."
"$REPO_DIR"/usr/bin/phosh-overlay-shutdown.sh || true

echo "Removing installed files..."
sudo rm -rf /etc/phosh-overlay-gestures
sudo rm -f /etc/xdg/autostart/phosh-overlay-gestures.desktop
sudo rm -f /usr/bin/phosh-overlay-*.sh

echo "Done."
