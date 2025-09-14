# Setup

- Configure the camera interface:

```
sudo /opt/nvidia/jetson-io/jetson-io.py
```

  - Select `Configure Jetson 24pin CSI Connector`

  - Select `Configure for compatible hardware`

  - For the mono camera configuration (plugged into the `CAM0` port on the Orin nano carrier board):
    - Select `Camera IMX219-A`

  - For the stereo camera configuration:
    - Select `Camera IMX219 Dual`

  - Select `Save pin changes`

  - Select `Save and reboot to reconfigure pins`

The board will reboot, then you can test the stream.

- Test the stream (CAM0):

```
gst-launch-1.0 nvarguscamerasrc sensor-id=0 ! nvvidconv ! nveglglessink
```

- Test the stream (CAM1):

```
gst-launch-1.0 nvarguscamerasrc sensor-id=1 ! nvvidconv ! nveglglessink
```

In stereo mode, proceed to [camera calibration](./CAMERA_CALIBRATION.md) to calibrate the cameras.