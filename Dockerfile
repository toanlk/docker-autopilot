# -----------------------------------------------------------------------------
# Autopilot Dockerfile - Virtual Desktop Environment
# -----------------------------------------------------------------------------

# Base image
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
RUN apt-get update && apt-get install -y \
    # X11 / VNC
    xvfb x11vnc xauth x11-xserver-utils \
    x11-apps sudo software-properties-common \
    # Desktop environment 
    xfce4 xfce4-goodies dbus dbus-x11 \
    # Display manager with autologin capability
    lightdm \
    # Development tools
    python3 python3-pip curl wget git vim \
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
    libxtst-dev \
    # Remove unneeded dependencies
    && apt-get remove -y light-locker xfce4-screensaver xfce4-power-manager || true \
    # Clean up to reduce image size
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/dbus && \
    # Generate a machine-id so dbus-daemon doesn't complain
    dbus-uuidgen --ensure=/etc/machine-id

# -----------------------------------------------------------------------------
# 3. Additional software installation
# -----------------------------------------------------------------------------
# Install Firefox
RUN apt-get update && apt-get install -y \
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
    && add-apt-repository -y ppa:mozillateam/ppa \
    && apt-get update \
    && apt-get install -y firefox-esr \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    # Set Firefox as default browser system-wide
    && update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/firefox-esr 200 \
    && update-alternatives --set x-www-browser /usr/bin/firefox-esr \
    # Configure default MIME handlers for web content
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

# Install autossh
RUN apt-get update && \
    apt-get install -y autossh && \
    rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install --upgrade pip setuptools wheel Pillow

# -----------------------------------------------------------------------------
# 4. VNC and remote access setup
# -----------------------------------------------------------------------------
# Install noVNC and websockify
RUN git clone https://github.com/novnc/noVNC.git /opt/noVNC \
    && git clone https://github.com/novnc/websockify.git /opt/websockify \
    && cd /opt/websockify \
    && pip3 install --break-system-packages .

# -----------------------------------------------------------------------------
# 5. Application setup (autopilotd)
# -----------------------------------------------------------------------------
# Copy package files first to leverage Docker cache

# Install dependencies required to build libnut-core
RUN apt-get update && \
    apt-get install -y cmake libx11-dev libxtst-dev libxinerama-dev libxi-dev libxrandr-dev git build-essential && \
    rm -rf /var/lib/apt/lists/*

COPY ./packages/autopilotd/ /autopilotd/
WORKDIR /autopilotd
RUN pip3 install -r /autopilotd/requirements.txt

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

USER autopilot
WORKDIR /home/autopilot

# Create .Xauthority file for X11 authentication
RUN touch /home/autopilot/.Xauthority && \
    chown autopilot:autopilot /home/autopilot/.Xauthority && \
    chmod 600 /home/autopilot/.Xauthority

# -----------------------------------------------------------------------------
# 8. Port configuration and runtime
# -----------------------------------------------------------------------------
# - Port 9990: autopilotd
# - Port 5900: VNC display for the Ubuntu VM
# - Port 6080: noVNC client
# - Port 6081: noVNC HTTP proxy
EXPOSE 9990 5900 6080 6081

# Start supervisor to manage all services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf", "-n"]