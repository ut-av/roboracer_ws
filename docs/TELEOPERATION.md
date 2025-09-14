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



