import re
from pathlib import Path

packages_dir = Path("/Users/ntsoi/roboracer_ws/packages")
shared_packages_root = Path("/Users/ntsoi/src/airfield/packages")

# 1. Collect all dependency names using simple string parsing
dependencies = set()
for pkg_yaml_path in packages_dir.glob("**/airfield.yaml"):
    try:
        content = pkg_yaml_path.read_text(encoding="utf-8")
        in_deps = False
        for line in content.splitlines():
            stripped = line.strip()
            if stripped.startswith("dependencies:"):
                in_deps = True
                continue
            if in_deps:
                if stripped.startswith("-"):
                    # Extract dependency name (ignoring version constraints or trailing comments)
                    dep_name = stripped.lstrip("-").strip().split()[0]
                    dependencies.add(dep_name)
                elif stripped and not line.startswith(" ") and not line.startswith("\t"):
                    # Ended dependencies block
                    in_deps = False
    except Exception as e:
        print(f"Error reading {pkg_yaml_path}: {e}")

print(f"Found {len(dependencies)} total dependencies across packages:")
print(sorted(list(dependencies)))

# 2. Generate empty manifests for any missing dependencies in x86_64 and arm64
for arch in ["x86_64", "arm64"]:
    arch_dir = shared_packages_root / arch
    arch_dir.mkdir(parents=True, exist_ok=True)
    
    for dep in sorted(list(dependencies)):
        # Skip local package wrappers
        local_pkg_path = packages_dir / dep
        if local_pkg_path.exists():
            print(f"[{arch}] Skipping local package '{dep}'")
            continue
            
        dep_yaml_path = arch_dir / f"{dep}.yaml"
        if not dep_yaml_path.exists():
            content = f"name: {dep}\nversion: 1.0.0\nsystem: []\nuser: []\n"
            dep_yaml_path.write_text(content, encoding="utf-8")
            print(f"[{arch}] Created manifest for: {dep}")
        else:
            print(f"[{arch}] Manifest already exists for: {dep}")

print("Manifest generation complete!")
