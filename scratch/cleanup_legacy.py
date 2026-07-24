import shutil
from pathlib import Path

ws_dir = Path("/Users/ntsoi/roboracer_ws")
tmux_dir = ws_dir / "tmux"
migrate_script = ws_dir / "migrate_to_airfield.py"

if tmux_dir.exists():
    shutil.rmtree(tmux_dir)
    print("Deleted legacy tmux/ directory.")

if migrate_script.exists():
    migrate_script.unlink()
    print("Deleted migrate_to_airfield.py.")

print("Cleanup complete!")
