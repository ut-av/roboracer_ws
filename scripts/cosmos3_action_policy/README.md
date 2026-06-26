# Cosmos3-Nano action policy clients

Two ROS2 clients for talking to a `cosmos-framework` websocket inference
server (`cosmos_framework.scripts.action_policy_server_roboracer`, see the
[DriveDCCosmos fork](https://github.com/tarunravisankar/DriveDCCosmos/tree/roboracer-action-policy))
running on a separate GPU machine. Both run inside the `orin_roboracer`
Docker container, where ROS2/rclpy and the camera topics live.

Neither script depends on anything beyond `rclpy`, `sensor_msgs`, `msgpack`,
and `websockets` (`pip install --user websockets` if missing — doesn't
survive a container recreation).

## `roboracer_dryrun_client.py`

The simpler of the two: throttled request/response, logs the predicted
`[curvature, velocity]` on every call. Never publishes anything. Good for a
first sanity check that the server is reachable and producing sane output.

```bash
python3 roboracer_dryrun_client.py --server-ip <robolang-vpn-ip> --server-port 18765
```

## `roboracer_chunk_buffered_client.py`

The actual deployment client. Decouples the model's inference rate
(~0.35-0.4s/call) from the car's required command rate (must publish within
0.5s or the car's own watchdog auto-stops) via two concurrent loops:

- a background loop that continuously re-runs inference on the latest camera
  frame and replaces the current 32-step predicted chunk as soon as a fresh
  one arrives (receding-horizon style — never executes a stale full chunk to
  completion since replanning is much faster than the chunk's ~2.1s span);
- a fixed ~15Hz ROS2 timer that pops the next step out of whatever the
  current chunk is and publishes/logs it, with a fail-safe SUC to
  `velocity=0, curvature=0` if the buffer is empty, exhausted, or older than
  `--max-buffer-age-s`.

**Safe by default** — `--dry-run` behavior (log only) unless `--live` is
passed. Even with `--live`, the car's own `vesc_driver.cpp` only acts on
`/ackermann_curvature_drive` if a human has toggled autonomous mode on the
joystick (confirmed by reading `ackermannCurvatureCallback`/`isAutonomous()`
in that file — on this car's controller, that's R1, hold-to-enable, instant
release-to-stop), and joystick input instantly overrides per-axis regardless.

```bash
# Dry run first - always do this before --live
python3 roboracer_chunk_buffered_client.py --server-ip <robolang-vpn-ip> --server-port 18765

# Only once dry-run output looks sane and a human is at the joystick:
python3 roboracer_chunk_buffered_client.py --server-ip <robolang-vpn-ip> --server-port 18765 --live
```

`--max-velocity` (default 1.0 m/s) and `--max-curvature` (default 3.0 1/m)
are hard clamps applied to every published command regardless of what the
model predicts, independent of the car's own safety logic above.
