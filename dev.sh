#!/bin/bash
# ── MacTimer Live Dev ─────────────────────────────────────────────────────────
# Watches Sources/ for changes, rebuilds, and relaunches the app automatically.
# Usage: ./dev.sh

APP=".build/release/MacTimer"
PID_FILE="/tmp/mactimer_dev.pid"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo -e "${CYAN}🔥 MacTimer Live Dev${RESET}"
echo -e "${CYAN}────────────────────────────────${RESET}"
echo -e "Watching ${YELLOW}Sources/${RESET} for changes..."
echo ""

kill_app() {
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            kill "$OLD_PID" 2>/dev/null
        fi
        rm -f "$PID_FILE"
    fi
    # Also kill any stray instances
    pkill -x MacTimer 2>/dev/null || true
}

build_and_launch() {
    echo -e "${YELLOW}⚡ Change detected — rebuilding...${RESET}"

    # Build
    if swift build -c release 2>&1 | grep -E "error:|Build complete|warning:"; then
        if swift build -c release > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Build complete — relaunching...${RESET}"
            kill_app
            sleep 0.3
            "$APP" &
            echo $! > "$PID_FILE"
            echo -e "${GREEN}🚀 Running (PID: $(cat $PID_FILE))${RESET}"
            echo ""
        else
            echo -e "${RED}❌ Build failed — fix errors and save again${RESET}"
            echo ""
        fi
    fi
}

# Initial build + launch
echo -e "${YELLOW}⚡ Initial build...${RESET}"
swift build -c release 2>&1 | tail -3
if [ -f "$APP" ]; then
    kill_app
    "$APP" &
    echo $! > "$PID_FILE"
    echo -e "${GREEN}🚀 Launched (PID: $(cat $PID_FILE))${RESET}"
    echo ""
fi

# Watch for changes
fswatch -o Sources/ | while read -r _; do
    build_and_launch
done

# Cleanup on exit (Ctrl+C)
trap 'echo -e "\n${CYAN}Stopping...${RESET}"; kill_app; exit 0' INT TERM
