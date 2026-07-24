# hid-playstation — out-of-tree module for JetPack

JetPack's L4T kernel (6.8.12-tegra, JetPack 7.2) is built with
`CONFIG_HID_PLAYSTATION` **disabled**, so PS4/PS5 controllers (and AceGamer-style
DualShock 4 clones, which enumerate as `054c:09cc`) fall back to `hid-generic`:
wrong button mapping, no battery reporting, and — critically for the clones —
no USB "activation" handshake, without which they refuse to enter Bluetooth
pairing mode entirely.

This directory vendors the driver source so every car builds the exact same
known-good code with no network dependency:

- `hid-playstation.c`, `hid-ids.h` — verbatim from
  [torvalds/linux **v6.8**](https://github.com/torvalds/linux/tree/v6.8/drivers/hid)
  (GPL-2.0-or-later, SPDX headers intact), matching the 6.8.12 L4T kernel.
- `Kbuild` + `Makefile` — kbuild rules and the make entry point (direct or DKMS).
- `dkms.conf` — DKMS packaging (`AUTOINSTALL=yes` → rebuilds on kernel updates).

Install with [`../install_ds4_driver.sh`](../install_ds4_driver.sh); pairing
procedure in [`docs/AIRFIELD.md`](../../docs/AIRFIELD.md).

If the fleet ever moves to a new kernel *series* (e.g. 6.8 → 6.11), refresh
these two sources from the matching `v<major.minor>` tag and bump
`PACKAGE_VERSION` in `dkms.conf` (keep `VER` in the install script in sync).
