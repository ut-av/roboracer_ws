# Teleoperation

Drive the car using the joystick.

## Bind the PS4 Controller

To connect a PS4 controller to Ubuntu 22.04, put the controller into pairing mode by holding the Share button and the PlayStation button until the light bar flashes rapidly. Then, go to your system's Bluetooth settings, ensure Bluetooth is on, and click to add a new device. Select the "Wireless Controller" when it appears on the screen to pair and connect it. 

## Start the Car

- Then run the tmuxinator config (outside the container):

```
cd ~/roboracer_ws/tmux/teleop
tmuxinator
```

## Troubleshooting

- If the VESC driver crashes, ensure you have a `car.lua` config file:

```
cp $(ros2 pkg prefix ut_automata)/share/ut_automata/config/car.lua.example $(ros2 pkg prefix ut_automata)/share/ut_automata/config/car.lua
```

- The Joystick config is in ut_automata/config/joystick.lua if the wrong joystick is selected, try changing `joystick_port="/dev/input/js0"` to `joystick_port="/dev/input/js1"`

## Joystick Control Modes

The joystick node supports different stick control modes, configured in `ut_automata/config/joystick.lua` via the `joystick_mode` parameter:

- **`"both"` (default)**: Use both sticks - left stick horizontal for steering, right stick vertical for drive/throttle
- **`"left"`**: Use left stick only - horizontal for steering, vertical for drive/throttle  
- **`"right"`**: Use right stick only - horizontal for steering, vertical for drive/throttle

To change the mode, edit the `joystick_mode` setting in `joystick.lua`:
```lua
joystick_mode = "left";  -- or "right" or "both"
```

Alternatively, you can copy one of the example configuration files:
```bash
# For left stick only mode:
cp config/joystick_left_stick_only.lua config/joystick.lua

# For right stick only mode:
cp config/joystick_right_stick_only.lua config/joystick.lua

# For both sticks mode (default):
cp config/joystick_both_sticks.lua config/joystick.lua
```

### Controls Summary
- **Both mode**: Left stick for steering, Right stick for speed
- **Left mode**: Left stick for steering, Left stick for speed  
- **Right mode**: Right stick for steering, Right stick for speed
- **Manual mode**: L1 - enables joystick control
- **Turbo mode**: L2 - enables higher max speed
- **Autonomous mode**: Left bumper (LB/L1) - enables autonomous driving



