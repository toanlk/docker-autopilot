# -----------------------------------------------------------------------------
# Autopilot Dockerfile - Virtual Desktop Environment
# -----------------------------------------------------------------------------

# Multi-stage build for optimized image size and build time

# Stage 1: Build dependencies
FROM ubuntu:22.04 AS builder

# Set non-interactive installation
ARG DEBIAN_FRONTEND=noninteractive

# Install only the dependencies needed for building
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    libx11-dev \
    libxtst-dev \
    libxinerama-dev \
    libxi-dev \
    libxrandr-dev \
    git \
    build-essential \
    python3-dev \
    python3-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Python build dependencies
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel

# Stage 2: Final image
FROM ubuntu:22.04

# -----------------------------------------------------------------------------
# 1. Environment setup
# -----------------------------------------------------------------------------
# Set non-interactive installation
ARG DEBIAN_FRONTEND=noninteractive
# Configure display for X11 applications
ENV DISPLAY=:0

# -----------------------------------------------------------------------------
# 2. System dependencies installation
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # X11 / VNC
    xvfb x11vnc xauth x11-xserver-utils \
    x11-apps sudo software-properties-common \
    # Desktop environment 
    xfce4 xfce4-goodies dbus dbus-x11 \
    # Display manager with autologin capability
    lightdm \
    # Development tools
    python3 python3-pip curl wget git vim nano \
    # Utilities
    supervisor netcat-openbsd \
    # Applications
    xpdf gedit xpaint \
    # Screenshot tool
    gnome-screenshot \
    # Libraries
    python3-dev \
    python3-tk \
    # OCR engine
    tesseract-ocr \
    libtesseract-dev \
    xdotool \
    wmctrl \
    libxtst-dev \
    # Cleanup in the same layer to reduce image size
    && apt-get remove -y light-locker xfce4-screensaver xfce4-power-manager || true \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/dbus \
    && dbus-uuidgen --ensure=/etc/machine-id

# -----------------------------------------------------------------------------
# 3. Additional software installation
# -----------------------------------------------------------------------------
# Install Firefox and other software in a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Install necessary for adding PPA
    software-properties-common apt-transport-https wget gnupg \
    # Install Additional Graphics Libraries
    mesa-utils \
    libgl1-mesa-dri \
    libgl1-mesa-glx \
    # Install Sandbox Capabilities
    libcap2-bin \
    # Install Fonts
    fontconfig \
    fonts-dejavu \
    fonts-liberation \
    fonts-freefont-ttf \
    # Install autossh
    autossh \
    && add-apt-repository -y ppa:mozillateam/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends firefox-esr \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    # Set Firefox as default browser system-wide
    && update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/firefox-esr 200 \
    && update-alternatives --set x-www-browser /usr/bin/firefox-esr \
    # Configure default MIME handlers for web content
    && mkdir -p /etc/xdg/xfce4/helpers \
    && mkdir -p /etc/xdg/xfce4/helpers \
    && echo '[Desktop Entry]' > /etc/xdg/xfce4/helpers/firefox.desktop \
    && echo 'Version=1.0' >> /etc/xdg/xfce4/helpers/firefox.desktop \
    && echo 'Type=X-XFCE-Helper' >> /etc/xdg/xfce4/helpers/firefox.desktop \
    && echo 'Name=Firefox Web Browser' >> /etc/xdg/xfce4/helpers/firefox.desktop \
    && echo 'X-XFCE-Binaries=firefox-esr;firefox;' >> /etc/xdg/xfce4/helpers/firefox.desktop \
    && echo 'X-XFCE-Category=WebBrowser' >> /etc/xdg/xfce4/helpers/firefox.desktop \
    && echo 'X-XFCE-Commands=%B;%B' >> /etc/xdg/xfce4/helpers/firefox.desktop \
    && echo 'X-XFCE-CommandsWithParameter=%B %s;%B %s;' >> /etc/xdg/xfce4/helpers/firefox.desktop \
    && echo 'WebBrowser=firefox-esr' > /etc/xdg/xfce4/helpers.rc \
    && fc-cache -f -v

RUN install -m 0755 -d /etc/firefox/policies && \
    cat > /etc/firefox/policies/policies.json <<'EOF'
{
  "policies": {
    "FirefoxHome": {
      "Search": true, "TopSites": false, "SponsoredTopSites": false,
      "Highlights": false, "Pocket": false, "SponsoredPocket": false,
      "Snippets": false, "Locked": true
    },
    "PDFjs": { "Enabled": true, "EnablePermissions": true },
    "Notifications": { "BlockNewRequests": true, "Locked": true },
    "UserMessaging": {
      "ExtensionRecommendations": false, "FeatureRecommendations": false,
      "UrlbarInterventions": false, "SkipOnboarding": true,
      "MoreFromMozilla": false, "FirefoxLabs": false
    },
    "PasswordManager": {
      "Enabled": false,
      "Locked": true,
      "AskToSaveLogins": false,
      "AutomaticUpdates": false,
      "AllowPasswordStorage": false,
      "BlockMasterPasswordCreation": true
    },
    "Browser": {
      "RestoreSessionEnabled": false,
      "RestoreSessionOnStartup": false,
      "RememberPasswords": false,
      "ClearOnShutdown": {
        "Passwords": true
      }
    },
    "Preferences": {
      "signon.rememberSignons": false,
      "signon.autofillForms": false,
      "signon.generation.enabled": false
    }
  }
}
EOF

# Install Python packages
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel Pillow

# -----------------------------------------------------------------------------
# 4. VNC and remote access setup
# -----------------------------------------------------------------------------
# Install noVNC and websockify - use specific versions for better caching
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/noVNC \
    && git clone --depth 1 https://github.com/novnc/websockify.git /opt/websockify \
    && cd /opt/websockify \
    && pip3 install --no-cache-dir --break-system-packages .

# -----------------------------------------------------------------------------
# 5. Application setup (autopilotd)
# -----------------------------------------------------------------------------
# Copy only requirements.txt first to leverage Docker cache
COPY ./packages/autopilotd/requirements.txt /autopilotd/requirements.txt
WORKDIR /autopilotd

# Install Python dependencies
RUN pip3 install --no-cache-dir -r /autopilotd/requirements.txt

# Now copy the rest of the application code
COPY ./packages/autopilotd/ /autopilotd/

# -----------------------------------------------------------------------------
# 6. System configuration
# -----------------------------------------------------------------------------
# Add Supervisor Configuration for service management
COPY ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set restrictive permissions on supervisord configuration
RUN chmod 644 /etc/supervisor/conf.d/supervisord.conf && \
    chown root:root /etc/supervisor/conf.d/supervisord.conf

# Set restrictive permissions on autopilotd directory
RUN chown -R root:root /autopilotd && \
    chmod -R 755 /autopilotd

# -----------------------------------------------------------------------------
# 7. User setup and autologin configuration
# -----------------------------------------------------------------------------
# Create non-root user
RUN useradd -ms /bin/bash autopilot && echo "autopilot ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN chmod 755 /var/run/dbus && \
    chown autopilot:autopilot /var/run/dbus

RUN mkdir -p /tmp/autopilot-screenshots && \
    chown -R autopilot:autopilot /tmp/autopilot-screenshots

# Configure autologin for the autopilot user
RUN mkdir -p /etc/lightdm/lightdm.conf.d && \
    echo '[Seat:*]' > /etc/lightdm/lightdm.conf.d/50-autologin.conf && \
    echo 'autologin-user=autopilot' >> /etc/lightdm/lightdm.conf.d/50-autologin.conf && \
    echo 'autologin-user-timeout=0' >> /etc/lightdm/lightdm.conf.d/50-autologin.conf && \
    echo 'autologin-session=xfce' >> /etc/lightdm/lightdm.conf.d/50-autologin.conf

# Make sure the lightdm configuration has proper permissions
RUN chmod 644 /etc/lightdm/lightdm.conf.d/50-autologin.conf && \
    chown root:root /etc/lightdm/lightdm.conf.d/50-autologin.conf

# Set custom desktop background
# Create backgrounds directory
RUN mkdir -p /usr/share/backgrounds/autopilot

# Copy background.jpg from the build context
COPY ./static/background.jpg /usr/share/backgrounds/autopilot/ 
RUN chmod 644 /usr/share/backgrounds/autopilot/background.jpg

# Add XFCE configuration files
COPY ./xfce4/ /tmp/xfce4/

# Set up XFCE configuration
RUN mkdir -p /home/autopilot/.config/xfce4/ && \
    mkdir -p /home/bytebot/Desktop && \
    # Copy the XFCE configuration files
    cp -r /tmp/xfce4/* /home/autopilot/.config/xfce4/ && \
    # Create .xsessionrc file for the user to ensure XFCE starts properly
    mkdir -p /home/autopilot/.config && \
    echo "exec startxfce4" > /home/autopilot/.xsessionrc && \
    # Create Desktop directory for autopilot user
    mkdir -p /home/autopilot/Desktop && \
    # Ensure all settings are owned by the user
    chown -R autopilot:autopilot /home/autopilot/.config /home/autopilot/Desktop /home/autopilot/.xsessionrc

# Replace default Web Browser shortcut with Firefox
RUN mkdir -p /etc/skel/.config/xfce4/panel/launcher-* && \
    mkdir -p /usr/share/applications/ && \
    echo '[Desktop Entry]' > /usr/share/applications/firefox.desktop && \
    echo 'Version=1.0' >> /usr/share/applications/firefox.desktop && \
    echo 'Type=Application' >> /usr/share/applications/firefox.desktop && \
    echo 'Name=Firefox Web Browser' >> /usr/share/applications/firefox.desktop && \
    echo 'Comment=Browse the web with Firefox' >> /usr/share/applications/firefox.desktop && \
    echo 'Exec=/usr/bin/firefox-esr %U' >> /usr/share/applications/firefox.desktop && \
    echo 'Icon=firefox-esr' >> /usr/share/applications/firefox.desktop && \
    echo 'Path=' >> /usr/share/applications/firefox.desktop && \
    echo 'Terminal=false' >> /usr/share/applications/firefox.desktop && \
    echo 'StartupNotify=true' >> /usr/share/applications/firefox.desktop && \
    echo 'Categories=Network;WebBrowser;' >> /usr/share/applications/firefox.desktop && \
    chmod +x /usr/share/applications/firefox.desktop && \
    # Copy Firefox desktop file to panel configuration
    mkdir -p /home/autopilot/.config/xfce4/panel && \
    cp -f /usr/share/applications/firefox.desktop /home/autopilot/.config/xfce4/panel/ && \
    # Create a backup of the default XFCE panel configuration
    mkdir -p /etc/xdg/xfce4/panel/backup && \
    # Also add Firefox to desktop
    mkdir -p /home/autopilot/Desktop && \
    cp -f /usr/share/applications/firefox.desktop /home/autopilot/Desktop/ && \
    chown -R autopilot:autopilot /home/autopilot/.config/xfce4/panel /home/autopilot/Desktop

# Add a desktop shortcut for the Terminal
RUN echo '[Desktop Entry]' > /usr/share/applications/terminal.desktop && \
    echo 'Version=1.0' >> /usr/share/applications/terminal.desktop && \
    echo 'Type=Application' >> /usr/share/applications/terminal.desktop && \
    echo 'Name=Terminal Emulator' >> /usr/share/applications/terminal.desktop && \
    echo 'Comment=Open a terminal' >> /usr/share/applications/terminal.desktop && \
    echo 'Exec=exo-open --launch TerminalEmulator' >> /usr/share/applications/terminal.desktop && \
    echo 'Icon=org.xfce.terminalemulator' >> /usr/share/applications/terminal.desktop && \
    echo 'Path=' >> /usr/share/applications/terminal.desktop && \
    echo 'Terminal=false' >> /usr/share/applications/terminal.desktop && \
    echo 'StartupNotify=true' >> /usr/share/applications/terminal.desktop && \
    echo 'Categories=Utility;TerminalEmulator;' >> /usr/share/applications/terminal.desktop && \
    chmod +x /usr/share/applications/terminal.desktop && \
    mkdir -p /home/autopilot/Desktop && \
    cp -f /usr/share/applications/terminal.desktop /home/autopilot/Desktop/ && \
    chown -R autopilot:autopilot /home/autopilot/Desktop

# Create .Xauthority file for X11 authentication
RUN touch /home/autopilot/.Xauthority && \
    chown autopilot:autopilot /home/autopilot/.Xauthority && \
    chmod 600 /home/autopilot/.Xauthority

RUN touch /root/.Xauthority

# Switch to non-root user at the end to avoid permission issues with subsequent layers
USER autopilot
WORKDIR /home/autopilot

# -----------------------------------------------------------------------------
# 8. Port configuration and runtime
# -----------------------------------------------------------------------------
# - Port 9990: autopilotd
# - Port 5900: VNC display for the Ubuntu VM
# - Port 6080: noVNC client
# - Port 6081: noVNC HTTP proxy
EXPOSE 9990 5900 6080 6081

# Health check to verify the container is running properly
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:9990/ || exit 1

# Start supervisor to manage all services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf", "-n"]