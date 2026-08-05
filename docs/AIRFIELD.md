# Running the stack with airfield (first-time & new-car setup)

This workspace was migrated from the legacy `./container` + `make` flow to
[airfield](https://github.com/airfield/airfield). Airfield builds **one container
image per ROS 2 package** and launches a *plan* (a named set of packages) as a
multi-pane tmux session.

This document covers everything a first-time user — or someone bringing up a
**different Jetson Orin / different car** — needs. For day-to-day use see the
Quickstart in the [README](../README.md).

---

## 1. Mental model

```
roboracer_ws/                 PROJECT (airfield.yaml at root)
├── packages/<name>/          one buildable ROS 2 package -> one container image
│   └── airfield.yaml         deps, ros_distro, base_image, devices, group_add
├── dependencies/             dependency manifests (how to apt-install each dep)
│   ├── xplatform/            cross-platform manifests
│   └── arm64/ | x86_64/      target-specific manifests + the L4T base image
├── plans/<name>.yaml         a launch target (windows/panes -> tmux)
└── scripts/                  build / up / down wrappers (below)

~/workspace/{build,install,log}   SHARED colcon workspace, mounted into every
                                  container. Built ONCE by scripts/build; panes
                                  only source it and launch.
```

Key idea — **build once, launch many**: every package image mounts the same
`~/workspace`, so the ROS 2 code is compiled a single time into
`~/workspace/install`. Panes then only `source` that install (automatically, via
the container's `~/.profile`) and run `ros2 launch/run`. This is what keeps the
7.4 GB Jetson from OOMing (the old per-pane concurrent `colcon build` demanded
~19 GB — see [scripts/build](../scripts/build)).

---

## 2. One-time host setup

On a fresh machine you need **three** things that are NOT part of this repo, plus
the base image:

1. **The airfield CLI** — installed (e.g. via `pipx`) and on the branch that has
   the roboracer changes (device passthrough, peer-source mounts, `AIRFIELD_NO_PULL`).
   Verify with `airfield --help` and `airfield doctor`.
2. **The airfield `packages` repo** — checked out next to the airfield source. It
   provides the *global* dependency manifests (nav2_*, cv_bridge, sensor_msgs,
   tf2, qt5, …) that this project's builds resolve against.
   > ⚠️ **Reproducibility gotcha:** several of those global manifests may exist
   > only on the current machine and not yet be committed/pushed. On a truly fresh
   > clone, confirm `airfield package dependencies check <pkg>` resolves every
   > dependency before building; if a manifest is missing the build fails with an
   > unresolved-dependency error. Missing manifests must be added either to that
   > global repo or to this project's `dependencies/xplatform/`.
3. **The L4T-matched base image** (`roboracer/l4t-jazzy:r39.2`), built on the
   Jetson:
   ```bash
   dependencies/arm64/l4t-jazzy/build.sh
   ```
   This image is **local-only** (not in any registry), which is why the scripts
   export `AIRFIELD_NO_PULL=1` — otherwise `docker build --pull` fails trying to
   fetch it. See [§5](#5-cross-orin--different-car).
4. **The PlayStation-controller kernel module** — JetPack's kernel ships without
   `CONFIG_HID_PLAYSTATION`, so PS4-style pads (incl. the fleet's AceGamer
   clones) get wrong mappings, no battery, and won't Bluetooth-pair at all:
   ```bash
   scripts/install_ds4_driver.sh    # host OS, not in a container; DKMS-managed
   ```
   Then pair each controller — see [§4f](#4f-game-controller-ds4--acegamer-clones).

---

## 3. Build & launch

```bash
airfield project up <plan>    # launch; panes auto-build missing packages (cached)
airfield project down         # clean teardown (containers stop via SIGHUP handling)
```

- **Auto-build:** every ROS pane runs through the container's
  `/opt/airfield-entry.sh`, which checks whether the pane's package is already
  in the shared `~/workspace/install`; if not, it `colcon build
  --packages-up-to <pkg>`s it first (serialized across panes via `flock`, one
  build at a time, `-j2` capped — OOM-safe). Already-built and non-ROS
  (apt-only) packages skip straight to launch. Per-package build flags come
  from `colcon_args:` in the package's `airfield.yaml` (e.g. ut_automata's
  `-DCMAKE_BUILD_MODE=Hardware`).
- **Teardown:** `airfield project down [plan]` kills the plan's tmux session;
  each pane's airfield process traps the SIGHUP and stops its own container —
  no orphans. After a hard crash (power loss, SIGKILL), use
  `airfield project down --prune` to sweep leftover `airfield-run-*` containers.
- To regenerate the tmux config **without** launching: `airfield project up
  navstack --no-launch` (writes `.airfield/navstack.tmuxinator.yml`).
- Force a clean rebuild: `rm -rf ~/workspace/build ~/workspace/install`, then
  relaunch (panes rebuild on demand) or pre-build serially with
  `scripts/build [pkgs...]`.
- `scripts/up` / `scripts/down` still exist as belt-and-braces **crash
  recovery**: they additionally clear a stale `:9` display lock and restart
  `nvargus-daemon` (stuck CSI capture session) — host-side state airfield
  doesn't own. Normal operation doesn't need them.

The panes that run are defined in [plans/navstack.yaml](../plans/navstack.yaml):
camera (`orin_rp2_csi`), nav2 (`av_navigation`), lidar (`rplidar`/`hokuyo`, auto-selected), `vesc_driver`,
`joystick`, robot description, `foxglove_bridge`, `gui`, `vnc`, `rviz2`.

> **Hardware panes need the hardware.** `vesc_driver` needs the VESC on
> `/dev/ttyACM0`, the lidar pane needs a lidar online, the camera needs the CSI
> sensor. Missing hardware makes only that pane fail; the rest of the stack is
> unaffected. `foxglove_bridge` "schemaDefinition … not found" lines are harmless
> (see [note](#foxglove-schema-warnings)).

---

## 4. Per-car configuration checklist ⭐

**These values are specific to one physical car and MUST be reviewed when moving
to a different car.** They are the most common cause of "it built and launched but
drives wrong / can't find a device."

### 4a. VESC / drivetrain calibration — [`packages/ut_automata/config/vesc.lua`](../packages/ut_automata/config/vesc.lua)

| Key | This car | Depends on |
|-----|----------|-----------|
| `speed_to_erpm_gain` | `5356` | motor + pinion/spur gearing (here: Arrma 3800, 17T pinion, P48 T83 spur) |
| `speed_to_erpm_offset` | `180` | motor (typically 160–200) |
| `steering_angle_to_servo_gain` | `-0.9015` | steering servo + linkage |
| `steering_angle_to_servo_offset` | `0.5` | servo center (typically 0.4–0.6) |
| `servo_min` / `servo_max` | `0.05` / `0.95` | servo travel limits |
| `max_steering_angle` | `0.425` rad | steering geometry |
| `wheelbase` | `0.324` m | chassis |
| `serial_port` | `/dev/ttyACM0` | USB enumeration (may differ if other USB-serial devices are present) |
| `i2c_bus_number` | `7` | carrier-board I²C bus for the MPU6050 IMU (`/dev/i2c-7`) |
| `fuse_imu` | `false` | set `true` to fuse IMU via EKF (then IMU + `/dev/i2c-7` must work) |

Re-calibrating gain/offset per car is a physical procedure — see
`plans/car_calibration.yaml` and the UT-AV docs.

### 4b. Hardware access — [`packages/ut_automata/airfield.yaml`](../packages/ut_automata/airfield.yaml)

The container only sees devices/groups it's told to pass through:
```yaml
devices:  [/dev/ttyACM0, /dev/i2c-7, /dev/input, /dev/ttyUSB0]
group_add: ["20", "108", "996"]  # 20=dialout (VESC + RPLIDAR serial), 108=i2c (IMU), 996=input (joystick)
```
If `serial_port` or `i2c_bus_number` differs on a new car, update **both**
`vesc.lua` and this `devices:` list. A device that isn't present is skipped with a
warning (the container still starts).

### 4c. Lidar — [`packages/ut_automata/launch/lidar.launch.py`](../packages/ut_automata/launch/lidar.launch.py)

`lidar.launch.py` auto-selects the driver from what's plugged in (USB RPLIDAR
wins over Ethernet Hokuyo). Both publish `sensor_msgs/LaserScan` on `/scan` with
`frame_id: laser`, so nothing downstream changes.

- **Slamtec RPLIDAR C1** (USB): a `/dev/ttyUSB*` device present → `rplidar_ros`
  at `460800` baud on that port. `/dev/ttyUSB0` is passed through in `airfield.yaml`
  (skipped when absent, so the Hokuyo setup is unaffected).
- **Hokuyo UST-10LX** (Ethernet): otherwise → `urg_node` at `ip_address:
  192.168.0.10`, `ip_port: 10940`. The Jetson's lidar NIC then needs a matching
  **static IP** on the same subnet (current setup: `192.168.0.1/24`,
  NetworkManager connection named `lidar`). Without it nav2 aborts bringup (no
  `/scan`). This is **host** config, not in the repo — set it per Jetson.

### 4d. CSI camera

Wiring/port and the device-tree overlay (here: IMX219) are per-car. See
[docs/RP2_CSI_CAMERA.md](RP2_CSI_CAMERA.md). If capture fails with "invalid or
empty" frames, `sudo systemctl restart nvargus-daemon` (also done by `scripts/up`).

### 4e. Map — default `gdc_3n`

`scripts/up` launches nav2 with `map:=${MAP:-gdc_3n}`. Override per environment:
`MAP=<name> scripts/up` (maps live in `packages/av_navigation/.../maps/`).

### 4f. Game controller (DS4 / AceGamer clones)

The fleet's AceGamer pads enumerate as genuine DualShock 4s (`054c:09cc`).
Two-phase setup, both **on the car's host OS** (ssh in; not in a container):

1. **Once per car — install the driver** (also listed in [§2](#2-one-time-host-setup)):
   ```bash
   ~/roboracer_ws/scripts/install_ds4_driver.sh
   ```
   Builds [scripts/hid_playstation/](../scripts/hid_playstation/) via DKMS
   (survives reboots **and** kernel updates), loads it, and enables it at boot.
2. **Once per controller — pair it:**
   ```bash
   # plug the pad in via USB: the 'playstation' driver claims it and runs the
   # activation handshake the clones require before they will BT-pair.
   ls /sys/class/power_supply/        # -> ps-controller-battery-<MAC>  (note the MAC)
   # unplug USB, then hold SHARE + PS ~5 s until the lightbar flashes, then:
   bluetoothctl --timeout 30 scan on  # wait for the MAC to appear
   bluetoothctl pair <MAC> && bluetoothctl trust <MAC> && bluetoothctl connect <MAC>
   ```
   Once trusted, the **PS button alone reconnects** it from then on; it appears
   as `/dev/input/js*` for the joystick pane either way (wired or BT).

Gotchas that cost a debugging session once:
- **PS alone never enters pairing mode** — it blinks (searching for a known
  host) then powers off after a few seconds. That pattern is *normal* and says
  nothing about battery. Pairing mode is SHARE+PS held ~5 s.
- **The USB-activation step is mandatory for the clones** and silently does
  nothing under `hid-generic` — i.e. on a car that skipped step 1.
- Battery check (pad on USB or BT): `cat /sys/class/power_supply/ps-controller-battery-*/capacity`
- Manage/unpair later: `scripts/bluetooth_controller_manager.sh` (list/unpair/reset).

### 4g. Host mounts — `.air` (**not in git**)

`.air` is airfield's **per-machine local config**: host paths mounted into every
package's container. It is deliberately **gitignored**, because it names things
that differ per car (uids, host directories) — so a fresh clone has none and you
must create it.

Create `.air` at the **project root**:

```yaml
mounts:
  - ~/.bash_history
  - ~/.ssh/authorized_keys
  # Qt panes (ut_automata `gui`, `rviz2`) reaching the touchscreen (:0)
  # or the vnc pane's display (:9)
  - /tmp/.X11-unix
  - /run/user/$UID/gdm
```

> **The shared workspace is no longer listed here.** `~/workspace/{build,install,log}`
> used to need three `.air` lines, and a car that skipped them rebuilt every
> package in every pane *and* lost the build lock that keeps those rebuilds from
> running concurrently — the OOM reboot in §1. Airfield now mounts the workspace
> in core on every machine, so build-once works on a fresh clone with no `.air`
> at all. `$AIRFIELD_WORKSPACE` relocates it (or `none` disables it).

`$UID` expands to the login user's real numeric id, so this snippet is
copy-paste identical on every car — **don't hardcode `2002`**, or the mount
silently resolves to nothing on a car whose user has a different id (airfield
skips absent mounts with a `[WARN]`, and the touchscreen `gui` pane then fails
to draw on `:0` while VNC keeps working).

> **Why here and not in `packages/ut_automata/.air`?** `ut_automata` is upstream
> **ut-amrl course infrastructure** — cloned by students on lab machines and
> adapted for other robot platforms — so host-specific paths must not be
> committed into it. A project-level `.air` also survives
> `scripts/checkout.sh` re-cloning that package.

---

## 5. Cross-Orin / different-car

- **Base-image target: JetPack 7.2 = Jetson Linux / L4T R39.2.** Confirmed on the
  reference Orin: `nvidia-jetpack` = `7.2-b187`, `/etc/nv_tegra_release` = `R39
  (release), REVISION: 2.0`. The base image is pinned to `r39.2` to match that.
  The pin lives in **one** place — the project [airfield.yaml](../airfield.yaml)
  `base_image:` field, which every package inherits (a package may still override
  with its own `base_image:`).
  - **Same JetPack (7.2) on the new Orin** → the base already matches. You only
    need to *build* it locally (it's a local-only image — see §2); do **not** change
    the Dockerfile or tag.
  - **Different JetPack/L4T** → first check the new host's version
    (`cat /etc/nv_tegra_release`), then:
    1. edit the L4T apt repo version in
       [dependencies/arm64/l4t-jazzy/Dockerfile](../dependencies/arm64/l4t-jazzy/Dockerfile)
       and the tag in [build.sh](../dependencies/arm64/l4t-jazzy/build.sh) to match
       the host, then rebuild the base;
    2. update the single `base_image:` line in the project `airfield.yaml`.
- **Device paths** (`/dev/ttyACM0`, `/dev/i2c-7`) can differ per carrier board /
  USB layout — see [§4](#4-per-car-configuration-checklist-).
- The workspace **must** live at `~/roboracer_ws` (some source hardcodes it).

---

## 6. Notes & gotchas

<a id="foxglove-schema-warnings"></a>
- **foxglove schema warnings** — `foxglove_bridge` logs "Failed to load
  schemaDefinition … package 'nav2_msgs'/'map_msgs'/… not found". Non-fatal: those
  topics just won't be *visualizable in Foxglove Studio* because the bridge image
  doesn't have those message packages. Add them to
  [packages/foxglove_bridge/airfield.yaml](../packages/foxglove_bridge/airfield.yaml)
  `dependencies:` if you want costmaps/particle-cloud in Foxglove.
- **VNC / display :9** — `rviz2` and `gui` are Qt apps that render to the `vnc`
  pane's X display `:9`. An unclean teardown can leave a stale `:9`; `scripts/up`
  clears it. Always tear down with `scripts/down` (tmux's `kill-server` leaves
  airfield containers orphaned because they only clean up on SIGTERM/SIGINT).
- **`AIRFIELD_NO_PULL=1`** — set by the scripts and the navstack plan so builds use
  the local L4T base image instead of trying to pull it from a registry.
- **Editing airfield's own source** invalidates the `COPY airfield /opt/airfield`
  layer in every package image, so the next launch rebuilds images. After such an
  edit, pre-warm images (`AIRFIELD_NO_PULL=1 airfield package cmd <pkg> -- true`)
  before launching.
