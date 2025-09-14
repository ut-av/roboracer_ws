# Visualization

## Simple Web-based Visualization

- Open `src/ut_automata/web_rviz.html` on your local computer, if you don't have a copy of the repository locally, you can download and open this file in your browser with the terminal command:

```
wget https://raw.githubusercontent.com/ut-amrl/ut_automata/refs/heads/ros2/web_rviz.html
open web_rviz.html 
```
## Foxglove Visualization

[rviz2](https://github.com/ros2/rviz) is a visualization tool for ROS, but it is difficult to install and run in cross-platform setups.

An alternative visualization tool is [Foxglove](https://foxglove.dev/download), which can be downloaded and run on your local computer, regardless of the type of operating system you have. It works on MacOS, Windows, and Linux.

To use Foxglove, ensure you have the foxglove bridge running on the car, by starting the bridge in the ROS container:

```
ros2 launch foxglove_bridge foxglove_bridge_launch.xml port:=8765
```

Then, connect your computer to the car using the url `ws://orinXX:8765` where `XX is the id number of your car. For example, for car 3, you would use the url: `ws://orin03:8765` 
