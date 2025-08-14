.PHONY: build clean

all: build

clean:
	rm -rf build install log

build:
	@if ! command -v colcon >/dev/null 2>&1; then \
		echo "Error: A ROS2 installation including the 'colcon' build tool is required"; \
		echo "Please install ROS2 and the colcon build tool before proceeding"; \
		exit 1; \
	fi
	colcon build || exit 1