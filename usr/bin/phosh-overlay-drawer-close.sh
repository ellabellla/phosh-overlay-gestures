#!/bin/bash
# Unconditionally closes the drawer after an entry is activated (tapped, or
# via Enter). Unlike phosh-overlay-launcher-toggle.sh, this never checks
# current state - using the toggle script here raced with :unfocus-close
# (which can close the drawer itself, e.g. when focus switches to another
# window), and re-evaluating state right after could see "already closed"
# and incorrectly reopen it.

busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b false
eww -c /etc/phosh-overlay-gestures update drawer-open=false search-text=""
sleep 0.3
eww -c /etc/phosh-overlay-gestures close drawer
