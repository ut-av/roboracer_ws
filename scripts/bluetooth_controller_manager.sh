#!/bin/bash
# Bluetooth Controller Management Script
# Helper script for managing joystick controller bindings

SAVED_MAC_FILE="$HOME/roboracer_ws/car/joystick_controller_mac.txt"

show_help() {
    cat << EOF
Bluetooth Controller Management Script

Usage: $0 [command]

Commands:
    show        Show the currently saved controller MAC address
    clear       Remove the saved controller binding
    list        List all paired Bluetooth devices
    connected   Show currently connected Bluetooth devices
    unpair      Remove all paired controllers
    reset       Full reset (clear saved MAC and unpair all controllers)
    help        Show this help message

Examples:
    $0 show         # See which controller is saved
    $0 clear        # Forget current controller
    $0 reset        # Start fresh with new pairing

After clearing or resetting, restart the joystick driver to pair a new controller.
EOF
}

show_saved() {
    if [ -f "$SAVED_MAC_FILE" ]; then
        MAC=$(cat "$SAVED_MAC_FILE")
        echo "Saved controller MAC: $MAC"
        
        # Try to get the device name
        NAME=$(bluetoothctl info "$MAC" 2>/dev/null | grep "Name:" | cut -d' ' -f2-)
        if [ -n "$NAME" ]; then
            echo "Device name: $NAME"
        fi
        
        # Check if it's currently connected
        if bluetoothctl info "$MAC" 2>/dev/null | grep -q "Connected: yes"; then
            echo "Status: CONNECTED ✓"
        else
            echo "Status: Not connected"
        fi
    else
        echo "No saved controller found."
        echo "Run the joystick driver to pair a controller."
    fi
}

clear_saved() {
    if [ -f "$SAVED_MAC_FILE" ]; then
        MAC=$(cat "$SAVED_MAC_FILE")
        rm "$SAVED_MAC_FILE"
        echo "Cleared saved controller: $MAC"
        echo "Restart the joystick driver to pair a new controller."
    else
        echo "No saved controller to clear."
    fi
}

list_paired() {
    echo "Paired Bluetooth devices:"
    bluetoothctl devices Paired 2>/dev/null | while read -r line; do
        MAC=$(echo "$line" | awk '{print $2}')
        NAME=$(echo "$line" | cut -d' ' -f3-)
        
        if bluetoothctl info "$MAC" 2>/dev/null | grep -q "Connected: yes"; then
            echo "  [CONNECTED] $MAC - $NAME"
        else
            echo "  [paired]    $MAC - $NAME"
        fi
    done
}

show_connected() {
    echo "Connected Bluetooth devices:"
    bluetoothctl devices Connected 2>/dev/null | while read -r line; do
        MAC=$(echo "$line" | awk '{print $2}')
        NAME=$(echo "$line" | cut -d' ' -f3-)
        echo "  $MAC - $NAME"
    done
}

unpair_all() {
    echo "Removing all paired controllers..."
    bluetoothctl devices Paired 2>/dev/null | grep -i -E '(controller|gamepad|joystick|xbox|playstation|dualshock|dualsense|joy-con|nintendo|wireless controller)' | while read -r line; do
        MAC=$(echo "$line" | awk '{print $2}')
        NAME=$(echo "$line" | cut -d' ' -f3-)
        echo "  Removing: $MAC - $NAME"
        bluetoothctl remove "$MAC" 2>/dev/null
    done
    echo "Done."
}

reset_all() {
    echo "=== Full Reset ==="
    clear_saved
    unpair_all
    echo ""
    echo "Reset complete. Restart the joystick driver to pair a new controller."
}

# Main command handling
case "${1:-help}" in
    show)
        show_saved
        ;;
    clear)
        clear_saved
        ;;
    list)
        list_paired
        ;;
    connected)
        show_connected
        ;;
    unpair)
        unpair_all
        ;;
    reset)
        reset_all
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
