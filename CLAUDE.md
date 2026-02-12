# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker Autopilot is a Docker container that provides a virtual desktop environment (Ubuntu 22.04 with XFCE4) designed for computer use agents. It exposes a REST API (`autopilotd`) that allows programmatic control of mouse, keyboard, screen capture, OCR, and other desktop interactions.

## Architecture

### Container Stack (Managed by Supervisor)

The container runs multiple services orchestrated by supervisord in this startup order:

1. **dbus** - System message bus (priority 1)
2. **xvfb** - Virtual framebuffer X server on display :0 at 1280x720x24 (priority 10)
3. **xfce4** - Desktop environment (priority 20, depends on xvfb)
4. **x11vnc** - VNC server on port 5900 (priority 30, depends on xfce4)
5. **websockify** - WebSocket proxy on port 6080 (priority 40, depends on x11vnc)
6. **novnc-http** - HTTP server on port 6081 serving noVNC client (priority 50)
7. **autopilotd** - FastAPI service on port 9990 (priority 60, main API)

### Autopilotd API Service

Located in `packages/autopilotd/main.py`, this FastAPI application provides a single endpoint `/computer-use` that accepts POST requests with various actions:

**Mouse Actions:**
- `move_mouse` - Move cursor using xdotool
- `mouse_move` - Move cursor using pyautogui with duration
- `click_mouse` - Click using xdotool
- `mouse_click` - Click using pyautogui
- `drag_mouse` - Drag along a path
- `trace_mouse` - Move along path while holding keys
- `cursor_position` - Get current cursor position

**Keyboard Actions:**
- `type_text` - Type text with delay using xdotool
- `press_keys` - Press keys with optional modifiers
- `hotkey` - Press key combination
- `type_keys` - Type individual keys with delay

**Screen Actions:**
- `screenshot` - Capture screen to base64 using gnome-screenshot
- `locate_text` - OCR text detection using EasyOCR, returns bounding boxes
- `scroll` - Scroll up/down by amount

**System Actions:**
- `execute_command` - Run shell commands, returns stdout/stderr/return_code
- `clipboard` - Get clipboard content
- `call_api` - Make HTTP requests
- `upload_files` - Write files to container filesystem

## Development Commands

### Building the Image

```bash
# Build locally
./build.sh

# Or manually
docker build -t docker-autopilot .
```

The `build.sh` script detects architecture (x86_64/aarch64) and optionally pushes to Docker Hub on macOS.

### Running Containers

**Using docker-compose (recommended for multiple instances):**
```bash
./composer.sh
```

This runs 3 instances:
- autopilot-1: ports 9990, 6080, 6081
- autopilot-2: ports 9991, 6082, 6083
- autopilot-3: ports 9992, 6084, 6085

**Using run.sh (5 instances):**
```bash
./run.sh
```

Runs 5 instances on ports 9990-9994 (autopilotd), 6080-6089 (noVNC/HTTP).

**Manual run:**
```bash
docker run --privileged -d \
  -p 9990:9990 -p 5900:5900 -p 6080:6080 -p 6081:6081 \
  --name docker-autopilot docker-autopilot
```

Note: `--privileged` flag is required for full desktop functionality.

### Accessing the Environment

- **API**: `http://localhost:9990/computer-use`
- **noVNC Web Client**: `http://localhost:6080/vnc.html`
- **VNC Direct**: `localhost:5900`

### Testing API

Example from `command.sh`:
```bash
# Type text
curl -X POST http://localhost:9990/computer-use \
  -H "Content-Type: application/json" \
  -d '{"action": "type_text", "text": "https://www.google.com", "delay": 30}'

# Press Enter
curl -X POST http://localhost:9990/computer-use \
  -H "Content-Type: application/json" \
  -d '{"action": "press_keys", "keys": ["enter"]}'
```

## Key Configuration Files

- **Dockerfile**: Multi-stage build with builder stage for dependencies, final stage with full desktop environment
- **supervisord.conf**: Service orchestration with dependency management and priority ordering
- **docker-compose.yml**: Multi-instance deployment configuration
- **xfce4/**: Desktop environment customization (background, terminal settings, helpers)
- **static/background.jpg**: Custom desktop wallpaper

## Important Details

### User Setup
- Non-root user: `autopilot` (has sudo NOPASSWD)
- Autologin configured via lightdm
- Home directory: `/home/autopilot`
- Poetry installed for Python package management

### Firefox Configuration
- Firefox ESR installed and set as default browser
- Policies configured in `/etc/firefox/policies/policies.json`
- Password manager disabled, no onboarding, minimal UI distractions

### Security Considerations
- Container runs with `--privileged` flag for full desktop access
- Shell command execution enabled via `execute_command` action
- File upload capability allows writing to container filesystem
- No authentication on API endpoints

### Python Dependencies
Key packages in `packages/autopilotd/requirements.txt`:
- fastapi, uvicorn - Web framework
- pyautogui - GUI automation
- opencv-python, easyocr - OCR and image processing
- pyperclip - Clipboard access
- requests - HTTP client

### Display Configuration
- DISPLAY=:0 (configurable via docker-compose environment)
- Resolution: 1280x720x24
- X11 authentication via .Xauthority files
