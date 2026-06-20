#!/bin/bash
# IPsec Lab - Screenshot Generator
# Converts HTML evidence files to PNG images
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVIDENCE_DIR="$SCRIPT_DIR/../evidence"
SCREENSHOTS_DIR="$EVIDENCE_DIR/screenshots"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }

mkdir -p "$SCREENSHOTS_DIR"

log "Generating PNG screenshots from HTML..."

for html_file in "$SCREENSHOTS_DIR"/*.html; do
  [ -f "$html_file" ] || continue
  basename=$(basename "$html_file" .html)
  png_file="$SCREENSHOTS_DIR/${basename}.png"
  
  log "Converting: $basename.html → $basename.png"
  
  # Try different screenshot methods
  if command -v chromium &>/dev/null; then
    chromium --headless --disable-gpu --screenshot="$png_file" --window-size=1200,800 "$html_file" 2>/dev/null
  elif command -v google-chrome &>/dev/null; then
    google-chrome --headless --disable-gpu --screenshot="$png_file" --window-size=1200,800 "$html_file" 2>/dev/null
  elif command -v /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome &>/dev/null; then
    /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --headless --disable-gpu --screenshot="$png_file" --window-size=1200,800 "file://$html_file" 2>/dev/null
  elif command -v safari &>/dev/null; then
    log "  Chrome not found, trying wkhtmltoimage..."
    if command -v wkhtmltoimage &>/dev/null; then
      wkhtmltoimage --width 1200 "$html_file" "$png_file" 2>/dev/null
    fi
  fi
  
  if [ -f "$png_file" ]; then
    log "  ✓ Generated: $png_file ($(du -h "$png_file" | cut -f1))"
  else
    log "  ⚠ Could not generate PNG for $basename (no browser/工具 available)"
    log "  → HTML files are available for manual screenshot"
  fi
done

log ""
log "Evidence files in: $EVIDENCE_DIR"
ls -la "$SCREENSHOTS_DIR"/*.png 2>/dev/null || log "No PNG files generated (HTML files available)"
ls -la "$SCREENSHOTS_DIR"/*.html 2>/dev/null
