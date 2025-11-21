#!/bin/bash

# Set default password if not provided
VNC_PASSWORD=${VNC_PASSWORD:-password}

# Create .vnc directory
mkdir -p $HOME/.vnc

# Set VNC password
echo "$VNC_PASSWORD" | /opt/TurboVNC/bin/vncpasswd -f > $HOME/.vnc/passwd
chmod 600 $HOME/.vnc/passwd

# Create xstartup if not exists
if [ ! -f $HOME/.vnc/xstartup.turbovnc ]; then
  echo "#!/bin/bash" > $HOME/.vnc/xstartup.turbovnc
  echo "unset SESSION_MANAGER" >> $HOME/.vnc/xstartup.turbovnc
  echo "unset DBUS_SESSION_BUS_ADDRESS" >> $HOME/.vnc/xstartup.turbovnc
  echo "startxfce4 &" >> $HOME/.vnc/xstartup.turbovnc
  chmod +x $HOME/.vnc/xstartup.turbovnc
fi

# Kill any existing VNC server on :9
/opt/TurboVNC/bin/vncserver -kill :9 > /dev/null 2>&1 || true

# Remove stale lock files if they exist
rm -f /tmp/.X11-unix/X9
rm -f /tmp/.X9-lock

# Start VNC server
# -geometry can be overridden by VNC_RESOLUTION env var
RESOLUTION=${VNC_RESOLUTION:-1920x1080}

echo "Starting TurboVNC server on :9 with resolution $RESOLUTION..."
/opt/TurboVNC/bin/vncserver :9 -geometry $RESOLUTION -depth 24 -securitytypes VNC

echo "VNC Server started. Connect to localhost:5909"
