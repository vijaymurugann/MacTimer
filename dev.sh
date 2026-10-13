#!/bin/bash
# ── MacTimer Live Dev ─────────────────────────────────────────────────────────
# Watches Sources/ for changes, rebuilds, and relaunches the app automatically.
# Usage: ./dev.sh

APP=".build/debug/MacTimer"
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

    # Fast incremental debug build
    if swift build; then
        echo -e "${GREEN}✅ Build complete — relaunching...${RESET}"
        kill_app
        sleep 0.1
        "$APP" &
        echo $! > "$PID_FILE"
        echo -e "${GREEN}🚀 Running (PID: $(cat $PID_FILE))${RESET}\n"
    else
        echo -e "${RED}❌ Build failed — fix errors and save again${RESET}\n"
    fi
}

# Cleanup on exit (Ctrl+C)
trap 'echo -e "\n${CYAN}Stopping dev mode...${RESET}"; kill_app; exit 0' INT TERM

# Initial debug build + launch
echo -e "${YELLOW}⚡ Initial build...${RESET}"
if swift build; then
    kill_app
    "$APP" &
    echo $! > "$PID_FILE"
    echo -e "${GREEN}🚀 Launched (PID: $(cat $PID_FILE))${RESET}\n"
else
    echo -e "${RED}❌ Initial build failed${RESET}\n"
fi

# Watch for changes (with 0.3s debouncing)
fswatch -o -l 0.3 Sources/ | while read -r _; do
    build_and_launch
done
