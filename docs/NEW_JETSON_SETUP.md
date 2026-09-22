# New Jetson setup: from a fresh flash to a running car

This guide takes a freshly flashed Jetson Orin to a working car. You install the
tools, install **airfield** the normal way (as someone who uses it, not someone
developing it), get the `roboracer_ws` code, build it, and launch it.
[Part 8](#part-8) covers **updating airfield once your airfield PR is merged**.

It assumes you're on your laptop and connected to the Jetson with VS Code's
Remote-SSH. Every command runs **on the Jetson, in a VS Code terminal**, unless
the step says otherwise.

> Last checked 2026-09-21 against airfield `jacob` (929bc73), airfield/packages
> `jacob` (ae29680) and roboracer_ws `jacob` (4b972d6).

**Contents:**
[Big picture](#big-picture) ·
[Part 0: Before you start](#part-0) ·
[Part 1: Connect](#part-1) ·
[Part 2: Prepare the system](#part-2) ·
[Part 3: Install airfield](#part-3) ·
[Part 4: Get the code](#part-4) ·
[Part 5: Build](#part-5) ·
[Part 6: Per-car hardware](#part-6) ·
[Part 7: Launch](#part-7) ·
[Part 8: Update airfield after your PR is merged](#part-8)

## How to read the steps

- **Run in:** says which folder the commands run in. Every code block also
  starts with a `cd` into that folder, so you can paste it into any terminal.
- `utavXX` stands for this car's account name, where `XX` is its two-digit
  number (`utav01`, `utav20`, ...). Swap in the real name wherever you see it.
- `~` is your home folder, `/home/utavXX`.
- Lines starting with `#` inside a code block are comments. It's fine to paste them.

<a id="big-picture"></a>
## The big picture

### Which branch of what

Until your PRs are merged, the car runs the `jacob` branch of everything.
Afterwards everything moves to `master` ([Part 8](#part-8)).

| Piece | Comes from | Until merged | After merged |
|---|---|---|---|
| airfield (the tool) | `github.com/airfield/airfield` | `jacob` | `master` |
| airfield's dependency recipes | `github.com/airfield/packages` | `jacob` | `master` |
| this workspace | `github.com/ut-av/roboracer_ws` | `jacob` | `master` |
| the ROS package repos | the 13 repos listed in `airfield.yaml` | mostly `jacob` ([Step 13](#step-13)) | whatever `airfield.yaml` lists |

### Where things end up

```
/home/utavXX/
├── roboracer_ws/                      this repo, in your home folder like on utav19
│   ├── airfield.yaml                  project settings: base image, list of package repos
│   ├── packages/                      the ROS code: 13 cloned repos + vnc, rviz2, foxglove_bridge
│   ├── plans/                         what to launch (navstack.yaml, teleop.yaml, ...)
│   ├── scripts/                       build / up / down helpers
│   ├── .air                           per-car settings you create in Step 14 (not in git)
│   └── .airfield/workspace/           compiled code, made by scripts/build (not in git)
├── .local/bin/airfield                the airfield command (installed by pipx)
├── .local/share/pipx/venvs/airfield/  airfield's private Python environment
└── .cache/airfield/packages/          airfield's dependency recipes (the airfield/packages repo)
```

Two unrelated things are called "packages": `~/roboracer_ws/packages/` is the
car's ROS code, and `~/.cache/airfield/packages/` is the recipe book airfield
uses to install system software (ROS libraries, OpenCV, ...) into containers.

utav19 differs from a new car in two ways:

- It predates the `utavXX` naming, so its account is still `orin` and its
  workspace is `/home/orin/roboracer_ws`. Relative to the home folder it's the
  same layout.
- It runs airfield as a *developer* install, straight from a source checkout in
  `~/src/airfield/`. This guide uses the normal user install instead. Nothing
  in `roboracer_ws` depends on where airfield lives.

<a id="part-0"></a>
## Part 0: Before you start

The freshly flashed Jetson should have:

- **JetPack 7.2.x** (Jetson Linux / L4T R39.2.x on Ubuntu 24.04), the same
  family as utav19.
- **A user named `utavXX`** with the password `orin`, where `XX` is the car's
  two-digit number (car 20 gets `utav20`). That's the convention for all new
  Jetsons. The home folder is then `/home/utavXX`.
- The workspace has to sit directly in that home folder, at
  `~/roboracer_ws` (`/home/utavXX/roboracer_ws`), because the plans refer to
  `$HOME/roboracer_ws`. Any account name works for that: airfield creates the
  same user inside each container, so `$HOME` matches in and out.
- **Network and SSH working**, so VS Code can connect, plus internet access. The
  builds download a lot.

Don't run `sudo apt upgrade` on the car on a whim. It can move the Jetson to a
newer JetPack point release, and the base image from [Step 15](#step-15) has to
match the Jetson's exact version. If you do upgrade, redo Step 15.

<a id="part-1"></a>
## Part 1: Connect (on your laptop)

1. In VS Code press `F1`, choose **Remote-SSH: Connect to Host...** and enter
   `utavXX@<jetson-ip>` (for example `utav20@<jetson-ip>`). The password is
   `orin`.
2. Once connected, open **Terminal → New Terminal**. That terminal runs on the Jetson.
3. Sanity check:

   ```bash
   cd ~
   whoami     # utavXX
   pwd        # /home/utavXX
   ```

<a id="part-2"></a>
## Part 2: Prepare the system (once per car)

### Step 1: Check the JetPack version

**Run in:** `~`

```bash
cd ~
cat /etc/nv_tegra_release
dpkg-query -W -f='${Version}\n' nvidia-l4t-core
```

The first should start with `R39 (release), REVISION: 2.` and the second with
`39.2.` (utav19 prints `39.2.0-...`).

### Step 2: Install the host tools

**Run in:** `~`

```bash
cd ~
sudo apt update
sudo apt install -y git curl pipx tmux tmuxinator nvidia-container
pipx ensurepath
```

- `pipx` installs Python command-line tools, like airfield, each in its own
  private folder so they can't clash with anything else.
- `tmux` and `tmuxinator` are what airfield uses to show all of the car's
  programs side by side in one terminal.
- `nvidia-container` lets containers use the Jetson's GPU and cameras. If the
  flash already included NVIDIA's SDK components, apt just says it's installed.
- `pipx ensurepath` puts `~/.local/bin`, where the `airfield` command will go,
  on your PATH. It takes effect after the reboot in Step 5.

If `apt update` complains about certificates or files that are "not valid
yet", check the date and time and adjust it on the jetson if needed. 

### Step 3: Install Docker

**Run in:** `~`

```bash
cd ~
docker --version    # if this prints a version, Docker is already there: skip the next line
curl -fsSL https://get.docker.com | sh
```

This is Docker's official install script. It installs the same Docker
(`docker-ce`) that utav19 runs.

### Step 4: Let Docker use the GPU, and use Docker without sudo

**Run in:** `~`

```bash
cd ~
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
sudo usermod -aG docker $USER
```

The first line tells Docker about NVIDIA's container runtime. airfield starts
every container on the car with it, so it can reach the GPU and cameras. The
last line adds you to the `docker` group.

### Step 5: Reboot, then reconnect

**Run in:** `~`

```bash
sudo reboot
```

The group change only applies to new logins, and VS Code keeps its old login
running in the background, so a new terminal isn't enough. When the Jetson is
back up, VS Code reconnects by itself or offers **Reload Window**.

### Step 6: Check Docker

**Run in:** `~`

```bash
cd ~
docker run --rm hello-world
docker info | grep -i runtimes
```

You should see `Hello from Docker!` with no permission error (and no `sudo`),
and `nvidia` in the `Runtimes:` line.

<a id="part-3"></a>
## Part 3: Install airfield (as a user)

### Step 7: Install airfield from the `jacob` branch

**Run in:** `~`

```bash
cd ~
pipx install git+https://github.com/airfield/airfield.git@jacob
```

The `@jacob` at the end matters. The install line in airfield's README has no
`@...`, which gets `master`, and `master` doesn't have your changes yet.

Check it:

```bash
cd ~
which airfield                                     # /home/utavXX/.local/bin/airfield
pipx runpip airfield freeze | grep airfield        # airfield @ git+https://github.com/airfield/airfield.git@<commit>
git ls-remote https://github.com/airfield/airfield.git jacob
```

The commit after the `@` in the second output should match the one
`git ls-remote` prints.

### Step 8: Point airfield's dependency recipes at `jacob` too

airfield installs each package's system software from small recipe files kept
in a separate repo, `airfield/packages`. A user install keeps its copy in
`~/.cache/airfield/packages`. If that folder doesn't exist, airfield quietly
downloads `master` into it the first time it needs a recipe. Create it yourself
from `jacob`, so this car uses the same recipes as utav19:

**Run in:** `~`

```bash
cd ~
git clone -b jacob https://github.com/airfield/packages.git ~/.cache/airfield/packages
```

If git says the folder `already exists`, airfield has already downloaded
`master`. Delete it with `rm -rf ~/.cache/airfield/packages` and run the clone
again.

### Step 9: Tab-completion

**Run in:** `~`

```bash
cd ~
airfield system install-completion bash
source ~/.bashrc
```

This gives you Tab-completion for airfield commands.

utav19's `~/.bashrc` has a few more airfield-related lines. The new car doesn't
need them:

- `export AIRFIELD_NO_PULL=1` stopped airfield from trying to download the
  car's base image, which exists only on the car (Step 15). roboracer_ws now
  says this once in its `airfield.yaml` (`pull_base_image: false`), which
  covers every airfield command on every car.
- `TORCH_INSTALL_TARGET` and `TORCH_GPU_WHL_TAG`: nothing in the navigation
  stack uses them.

### Step 10: Run the doctor

**Run in:** `~`

```bash
cd ~
airfield doctor
```

Every line should say `PASS`: Airfield update, Docker, Git, Plan runner,
Shell completion, GPU accelerator. `PyTorch: skipped` is fine.

<a id="part-4"></a>
## Part 4: Get the code

### Step 11: Clone roboracer_ws into your home folder

**Run in:** `~`

```bash
cd ~
git clone -b jacob https://github.com/ut-av/roboracer_ws.git
```

This creates `/home/utavXX/roboracer_ws`: directly in your home folder, like
on utav19.

Now open it in VS Code: **File → Open Folder...**, pick
`/home/utavXX/roboracer_ws` (VS Code fills in your home folder, so you only add
`roboracer_ws`), click **OK**. From now on new terminals open in `~/roboracer_ws`.

### Step 12: Download the ROS packages

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
mkdir -p packages/simulator    # optional: skips the 2 GB desktop simulator, which the car never uses
airfield subpackages checkout
```

`airfield.yaml` lists 13 separate git repos, and this clones each one into
`packages/`. It skips any folder that already exists, which is how the `mkdir`
line keeps the simulator out. It should end with `Checked out 12 Subpackages.`
(13 if you left the simulator in).

airfield's README calls this command `subprojects`. The actual name is `subpackages`.

<a id="step-13"></a>
### Step 13: Finish what the checkout doesn't do (yet)

The checkout gets each repo at the branch `airfield.yaml` names. For most
packages that branch doesn't have the package's airfield settings file yet.
Those live on a `jacob` branch in each repo, together with a few fixes for
ROS 2 Jazzy and Ubuntu 24.04. Without them airfield can't build the packages
at all.

**13a. ut_automata's shared library.** ut_automata includes a small library as
a git submodule, and the checkout doesn't download submodules.

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
git -C packages/ut_automata submodule update --init --recursive
```

**13b. Seven packages whose `jacob` branch is on GitHub.**

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
for p in av_description av_imitation av_navigation av_recorder av_sim leg_detector orin_rp2_csi; do
  git -C packages/$p switch jacob
done
```

Each one should print `branch 'jacob' set up to track 'origin/jacob'.`

**13c. Three packages whose `jacob` branch exists only on utav19.**
`amrl_maps` and `amrl_msgs` belong to ut-amrl, and `mpu6050driver` belongs to
nathantsoi. Nobody here can push to those repos, so their `jacob` branch was
never uploaded. Copy it straight from utav19. The new car has to be able to
reach utav19 over the network for this.

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
UTAV19=orin@10.1.0.119    # utav19 still uses the old 'orin' account; use the address you SSH to it with
for p in amrl_maps amrl_msgs mpu6050driver; do
  git -C packages/$p fetch "$UTAV19:roboracer_ws/packages/$p" jacob &&
  git -C packages/$p switch -c jacob FETCH_HEAD
done
```

It asks for utav19's password once per package. The first time, it also asks
you to type `yes` to trust utav19. Each one should end with
`Switched to a new branch 'jacob'`. The `mpu6050driver` fixes matter most:
without them ut_automata (motor controller, joystick, gui) doesn't compile.

**13d. Check.**

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
for p in amrl_maps amrl_msgs av_description av_navigation leg_detector mpu6050driver orin_rp2_csi ut_automata vnc rviz2 foxglove_bridge; do
  [ -f packages/$p/airfield.yaml ] && echo "ok       $p" || echo "MISSING  $p"
done
ls packages/ut_automata/src/shared | head -3
```

Every line should say `ok`, and the last command should list some files. The
package code on the new car now matches utav19's commit for commit.

### Step 14: Create the per-car settings file `.air`

`.air` lists folders on the car that get shared into every container. It
depends on the machine, so it isn't in git and every car needs its own.

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
cat > .air <<'EOF'
mounts:
  - ~/.bash_history
  - ~/.ssh/authorized_keys
  # let Qt windows (ut_automata gui, rviz2) reach the touchscreen (:0) or the VNC display (:9)
  - /tmp/.X11-unix
  - /run/user/$UID/gdm
EOF
```

Keep `$UID` exactly as written: airfield fills in your user id itself. Paths
that don't exist are skipped with a warning, so this is safe on a car without
a touchscreen. Details: [AIRFIELD.md §4g](AIRFIELD.md#4g-host-mounts--air-not-in-git).

<a id="part-5"></a>
## Part 5: Build

> **Tip:** Steps 15 and 16 take a long time, and a dropped VS Code connection
> can take a running build down with it. To be safe, run them inside tmux:
> `tmux new -s build`, run the step, and if you get disconnected, reconnect and
> run `tmux attach -t build`. Type `exit` to leave tmux before Part 7, which
> starts a tmux session of its own.

<a id="step-15"></a>
### Step 15: Build the base image

Every package container starts from this image. It holds the car's own camera
and GPU libraries at exactly the version the Jetson runs, which is why it has
to be built on the car and can't be downloaded.

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
dependencies/arm64/l4t-jazzy/build.sh
```

Then check that you built the image the project asks for:

```bash
cd ~/roboracer_ws
want=$(sed -n 's/^base_image:[[:space:]]*//p' airfield.yaml)
docker image inspect "$want" >/dev/null 2>&1 && echo "OK: $want is built" || echo "MISSING: $want"
```

If it prints `MISSING`, this car is on a different JetPack than the project
expects. [AIRFIELD.md §5](AIRFIELD.md#5-cross-orin--different-car) explains
what to do.

### Step 16: Build the ROS packages

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
scripts/build
```

This builds a container image for each package the navigation stack uses, then
compiles the code once into `.airfield/workspace/`. It goes one package at a
time with limited parallelism so the Jetson doesn't run out of memory. The first
run is slow, mostly downloading and installing software into the images. Later
runs reuse all of that and are quick.

It ends with a folder list that should include
`amrl_maps amrl_msgs av_description av_navigation orin_rp2_csi ut_automata`.

<a id="part-6"></a>
## Part 6: Per-car hardware

These depend on the physical car. The full details are in
[AIRFIELD.md §4](AIRFIELD.md#4-per-car-configuration-checklist-). Short version:

- **Hokuyo lidar (Ethernet).** The Jetson's Ethernet port needs a fixed address,
  or navigation won't start. **Run in:** `~`

  ```bash
  cd ~
  sudo nmcli con add type ethernet ifname enP8p1s0 con-name lidar \
    ipv4.method manual ipv4.addresses 192.168.0.1/24 ipv4.never-default yes \
    ipv6.method disabled connection.autoconnect-priority 100
  ```

  `enP8p1s0` is the Ethernet port on the Orin Nano dev kit; check yours with
  `ip -br link`. These are the same settings as utav19's `lidar` connection.
  A USB **RPLIDAR C1** needs none of this.
- **RPLIDAR C1 mounted like utav19's.** utav19 has an uncommitted change that
  turns the lidar frame around: `rpy="0 0 3.14159265"` on the `laser_connect`
  joint in `packages/av_description/urdf/roboracer.urdf.xml`. Copy it if your
  C1 is mounted the same way.
- **Game controller (PS4-style / AceGamer).** Install the driver, then pair each
  controller as described in
  [AIRFIELD.md §4f](AIRFIELD.md#4f-game-controller-ds4--acegamer-clones).
  **Run in:** `~/roboracer_ws`

  ```bash
  cd ~/roboracer_ws
  scripts/install_ds4_driver.sh
  ```

- **CSI camera.** Set up the camera connector with
  `sudo /opt/nvidia/jetson-io/jetson-io.py`; see [RP2_CSI_CAMERA.md](RP2_CSI_CAMERA.md).
- **Device group numbers.** Containers reach the motor controller, IMU and
  joystick through group numbers written in `packages/ut_automata/airfield.yaml`.
  **Run in:** `~`

  ```bash
  cd ~
  getent group dialout i2c input
  ```

  The third field should be `20`, `108` and `996`. If any differ on this car,
  change `group_add:` in `packages/ut_automata/airfield.yaml` to match, and
  don't commit that change.
- **Driving calibration** (motor gain, steering center, ...) lives in
  `packages/ut_automata/config/vesc.lua`; see
  [AIRFIELD.md §4a](AIRFIELD.md#4-per-car-configuration-checklist-).

<a id="part-7"></a>
## Part 7: Launch

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
scripts/up
```

This clears leftovers from earlier runs, builds anything that's missing, then
starts the navigation stack in tmux, with one pane per program (camera,
navigation, lidar, motor controller, joystick, ...).

- Move between panes: `Ctrl-b`, then an arrow key.
- Get your terminal back and leave everything running: `Ctrl-b`, then `d`.
  Return with `tmux attach -t navstack`.
- A pane for hardware that isn't plugged in shows errors. The other panes keep
  working.
- To watch from your laptop, point Foxglove Studio at `ws://<jetson-ip>:8765`,
  or a VNC viewer at `<jetson-ip>:5909` (rviz and the gui).

To stop everything, open another terminal (the `+` in VS Code's terminal panel):

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
scripts/down
```

Day to day, `airfield project up navstack` and `airfield project down` do the
same job; `scripts/up` and `scripts/down` also clean up after crashes. Other
plans live in `plans/`, and `scripts/up <plan>` launches any of them.

One leftover from the old `orin` account: the `run:` shortcuts in
`packages/orin_rp2_csi/airfield.yaml` start with `cd /home/orin/workspace`, so
`airfield package run orin_rp2_csi mono_processor` (and its `build` and
`stereo_processor` siblings) fails on a `utavXX` car. The plans don't use those
shortcuts, so launching isn't affected.

<a id="part-8"></a>
## Part 8: Updating airfield after your PR is merged

Wait until GitHub shows the airfield PR as **Merged**. Don't switch early:
`master` doesn't have your changes until then. Without them the car goes back to
rebuilding every package in every pane at the same time, which runs it out of
memory and reboots it, and it can build containers that are missing software.

### Step 1: Stop the car's programs

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
scripts/down
```

### Step 2: Reinstall airfield from `master`

**Run in:** `~`

```bash
cd ~
pipx install --force git+https://github.com/airfield/airfield.git
```

No `@jacob` this time, so pipx installs `master`, and later reinstalls follow
`master` too.

Why not `airfield system update`? It compares version numbers, and both branches
say `0.0.2`, so it prints `Airfield up-to-date (0.0.2).` and does nothing.
`airfield system update --force` does work, because it runs exactly the pipx
command above. `pipx upgrade airfield` does nothing either, for the same reason.

Check it:

**Run in:** `~`

```bash
cd ~
pipx runpip airfield freeze | grep airfield
git ls-remote https://github.com/airfield/airfield.git master
airfield doctor
```

The commit after the `@` in the first output should match the one
`git ls-remote` prints, and `airfield doctor` should be all `PASS` again.

### Step 3: Move the dependency recipes to `master`

Do this once the `airfield/packages` PR (its `jacob` into `master`) is merged
too, and always **after** Step 2.

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
rm -rf ~/.cache/airfield/packages
airfield package dependencies pull
git -C ~/.cache/airfield/packages log --oneline -1
```

With the folder gone, airfield downloads a fresh copy of `master`, its default.
The last line shows which commit you now have.

The order matters because the recipes on `jacob` use a newer format that only
the new airfield understands. An older airfield reads them without complaint
and installs nothing, so the images build fine and the programs fail later.

### Step 4: Move roboracer_ws to `master`

Once the roboracer_ws PR (`jacob` into `master`) is merged:

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
git status --short          # should print nothing; commit or stash anything that shows up
git fetch origin
git switch master
git pull --ff-only
```

`.air` and `.airfield/` aren't tracked by git, so they stay as they are.

### Step 5: Move the package repos back to their normal branches

Only do this once each package's `jacob` work has been merged into the branch
`airfield.yaml` lists for it (see [Making Step 13 unnecessary](#no-step-13)).

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
for pair in amrl_maps:ros2 amrl_msgs:master av_description:master av_imitation:master \
            av_navigation:master av_recorder:master av_sim:master leg_detector:main \
            mpu6050driver:main orin_rp2_csi:master; do
  p=${pair%%:*}; b=${pair#*:}
  git -C packages/$p fetch origin && git -C packages/$p switch $b && git -C packages/$p pull --ff-only
done
```

The branch after each `:` is the `version:` that `airfield.yaml` gives that
package. If `airfield.yaml` now points a package at a different repo (a fork,
say), delete that package's folder and re-run `airfield subpackages checkout`
instead. Afterwards re-run the check from Step 13d. Everything must still say `ok`.

### Step 6: Rebuild and relaunch

**Run in:** `~/roboracer_ws`

```bash
cd ~/roboracer_ws
scripts/build
scripts/up
```

The first build after an airfield update rebuilds every container image,
because airfield copies itself into each one. That's expected and happens once
per update. If something still acts strange, force a clean compile with
`rm -rf .airfield/workspace/build .airfield/workspace/install` and run
`scripts/build` again.

### Before the merge: picking up new `jacob` commits

If you push more commits to `jacob` and want them on the car before the merge,
`pipx reinstall airfield` reinstalls from the same place (`@jacob`) and gets the
newest commit. For the recipes, run `airfield package dependencies pull`.

### On utav19 (developer install)

utav19 runs airfield from a source checkout, so `airfield system update` refuses
to touch it. Update the checkouts instead; the `airfield` command follows them
automatically.

**Run in:** `~/src/airfield/airfield`, then `~/src/airfield/packages`

```bash
cd ~/src/airfield/airfield && git switch master && git pull --ff-only
cd ~/src/airfield/packages && git switch master && git pull --ff-only    # once the packages PR is merged
```

### For whoever merges the PRs

- Merge the **airfield** PR before the **packages** PR. Anyone still on the old
  airfield who pulls the new recipes gets containers with nothing installed,
  and no error.
- Consider bumping `__version__` in airfield's `src/airfield/__init__.py` and
  pushing a matching tag (for example `v0.0.3`; see the release notes in
  airfield's README). Then plain `airfield system update` sees a newer version
  and works without `--force`.

<a id="no-step-13"></a>
## Making Step 13 unnecessary

Step 13 exists because the package repos and `airfield.yaml` disagree about
branches. To get back to plain "clone, checkout, build":

1. In the seven ut-av repos (`av_description av_imitation av_navigation
   av_recorder av_sim leg_detector orin_rp2_csi`), merge `jacob` into the branch
   `airfield.yaml` lists. Then 13b goes away.
2. Get the `jacob` commits of `amrl_maps`, `amrl_msgs` (ut-amrl) and
   `mpu6050driver` (nathantsoi) onto GitHub, upstream or in forks you control
   (under ut-av, for example), and point those entries' `url:`/`version:` in
   `airfield.yaml` at them. Then 13c goes away, and new cars stop depending on
   utav19.
3. 13a could be fixed in airfield itself: `airfield subpackages checkout` could
   download submodules after cloning.
4. Once all the PRs are merged, simplify this guide: drop `@jacob` from Step 7,
   delete Step 8, and drop `-b jacob` from Step 11.

## Optional: pushing code from the car

Everything above clones over HTTPS, which is fine for pulling. To push from the car:

- Turn on SSH agent forwarding on your laptop (`ForwardAgent yes` under the
  car's entry in `~/.ssh/config`), reconnect, and check on the car with
  `ssh -T git@github.com`.
- Set your name and email on the car:
  `git config --global user.name "..."` and `git config --global user.email "..."`.
- Switch the repo you push to over to SSH, for example
  `git -C ~/roboracer_ws remote set-url origin git@github.com:ut-av/roboracer_ws.git`.
