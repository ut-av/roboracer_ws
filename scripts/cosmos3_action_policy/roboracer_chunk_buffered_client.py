"""Chunk-buffered ROS2 client for the RoboRacer action policy.

Decouples the model's inference rate from the car's required command rate:
  - a fast publish loop runs at ~15Hz (matching conditioning_fps), popping the
    next step out of the current predicted chunk and either logging it
    (--dry-run, the default) or publishing it to /ackermann_curvature_drive;
  - a separate inference loop calls the server back-to-back with the latest
    camera frame and replaces the buffer with each fresh 32-step chunk as
    soon as it arrives (receding-horizon style: every new chunk supersedes
    whatever was left of the old one, so the car is always acting on the
    most recent prediction rather than a stale one).

Fail-safe: if the buffer is empty or older than --max-buffer-age-s (e.g. the
server is unreachable or a single inference call stalls), publishes a STOP
command (velocity=0, curvature=0) instead of continuing on stale data.

SAFETY (--dry-run is the default and must be deliberately disabled):
  - --dry-run (default): never constructs or sends an AckermannCurvatureDriveMsg,
    only logs what would have been sent.
  - --live: actually creates the publisher and calls publish(). Even then,
    the car's own vesc_driver.cpp ignores this topic entirely unless a human
    has put the car into autonomous mode via the joystick, and instantly
    overrides per-axis on any joystick input past a small deadzone (confirmed
    by reading vesc_driver.cpp's ackermannCurvatureCallback/isAutonomous()).
  - --max-velocity / --max-curvature: hard clamps applied to every published
    command regardless of what the model predicts, as a second safety net
    independent of the car's own override logic.

Run inside the orin_roboracer container:
    python3 roboracer_chunk_buffered_client.py --server-ip 10.0.0.212 --server-port 18765
    # add --live only when actually ready to test with a human at the joystick
"""

import argparse
import asyncio
import threading
import time

import msgpack
import numpy as np
import rclpy
import websockets
from rclpy.node import Node
from sensor_msgs.msg import Image

_CONDITIONING_FPS = 15.0
_PUBLISH_PERIOD_S = 1.0 / _CONDITIONING_FPS


class ChunkBufferedPolicyClient(Node):
    def __init__(self, args: argparse.Namespace):
        super().__init__("roboracer_chunk_buffered_policy_client")
        self._server_uri = f"ws://{args.server_ip}:{args.server_port}"
        self._live = args.live
        self._max_velocity = args.max_velocity
        self._max_curvature = args.max_curvature
        self._max_buffer_age_s = args.max_buffer_age_s

        self._latest_image: np.ndarray | None = None
        self._image_lock = threading.Lock()

        # Buffer state: list of (curvature, velocity) steps + a cursor + the
        # wallclock time the chunk was produced (for staleness fail-safe).
        self._buffer: list[tuple[float, float]] = []
        self._buffer_idx = 0
        self._buffer_time = 0.0
        self._buffer_lock = threading.Lock()

        self._publisher = None
        if self._live:
            from amrl_msgs.msg import AckermannCurvatureDriveMsg  # local import: only needed in --live mode
            self._AckermannCurvatureDriveMsg = AckermannCurvatureDriveMsg
            self._publisher = self.create_publisher(AckermannCurvatureDriveMsg, "/ackermann_curvature_drive", 1)
            self.get_logger().warn(
                "[LIVE MODE] this node WILL publish to /ackermann_curvature_drive. "
                "The car's vesc_driver only acts on this if autonomous mode is toggled "
                "on the joystick, and joystick input instantly overrides per-axis."
            )
        else:
            self.get_logger().info("[DRY RUN] this node will NEVER publish to any control topic - log-only.")

        self.sub = self.create_subscription(Image, "/camera_0/image_raw", self._on_image, 1)

        self._loop = asyncio.new_event_loop()
        self._loop_thread = threading.Thread(target=self._loop.run_forever, daemon=True)
        self._loop_thread.start()
        asyncio.run_coroutine_threadsafe(self._inference_loop(), self._loop)

        # Publish/log tick runs on a regular rclpy timer (main thread), independent
        # of inference latency - this is what keeps us under the car's 0.5s timeout.
        self.create_timer(_PUBLISH_PERIOD_S, self._on_publish_tick)

        self.get_logger().info(
            f"roboracer chunk-buffered policy client started. Server: {self._server_uri}. "
            f"live={self._live} max_velocity={self._max_velocity} max_curvature={self._max_curvature}"
        )

    def _on_image(self, msg: Image) -> None:
        if msg.encoding != "bgr8":
            self.get_logger().warn(f"unexpected encoding {msg.encoding!r}, expected bgr8 - skipping frame")
            return
        bgr = np.frombuffer(msg.data, dtype=np.uint8).reshape(msg.height, msg.width, 3)
        rgb = bgr[:, :, ::-1].copy()
        with self._image_lock:
            self._latest_image = rgb

    async def _inference_loop(self) -> None:
        while True:
            with self._image_lock:
                image = self._latest_image
            if image is None:
                await asyncio.sleep(0.05)
                continue
            t0 = time.time()
            try:
                async with websockets.connect(self._server_uri, max_size=None) as ws:
                    await ws.recv()  # metadata handshake
                    await ws.send(msgpack.packb({"image": image.tobytes(), "shape": list(image.shape)}))
                    response_raw = await asyncio.wait_for(ws.recv(), timeout=10.0)
                response = msgpack.unpackb(response_raw, raw=False)
                if "error" in response:
                    self.get_logger().error(f"server error: {response['error']}")
                    continue
                curvature = response["curvature"]
                velocity = response["velocity"]
                new_buffer = list(zip(curvature, velocity))
                with self._buffer_lock:
                    self._buffer = new_buffer
                    self._buffer_idx = 0
                    self._buffer_time = time.time()
                self.get_logger().info(
                    f"new chunk ready: first-step curvature={curvature[0]:+.4f} velocity={velocity[0]:+.4f} "
                    f"(inference took {time.time() - t0:.2f}s, {len(new_buffer)} steps)"
                )
            except Exception as exc:  # noqa: BLE001 - keep replanning on any single failure
                self.get_logger().error(f"inference call failed: {exc}")
                await asyncio.sleep(0.5)

    def _on_publish_tick(self) -> None:
        now = time.time()
        with self._buffer_lock:
            buffer_age = now - self._buffer_time if self._buffer else None
            if (
                not self._buffer
                or self._buffer_idx >= len(self._buffer)
                or (buffer_age is not None and buffer_age > self._max_buffer_age_s)
            ):
                curvature, velocity = 0.0, 0.0
                reason = "buffer empty/exhausted/stale -> fail-safe STOP"
            else:
                curvature, velocity = self._buffer[self._buffer_idx]
                self._buffer_idx += 1
                reason = None

        velocity = float(np.clip(velocity, -self._max_velocity, self._max_velocity))
        curvature = float(np.clip(curvature, -self._max_curvature, self._max_curvature))

        if self._live:
            msg = self._AckermannCurvatureDriveMsg()
            msg.velocity = velocity
            msg.curvature = curvature
            self._publisher.publish(msg)
        if reason or self.get_logger().get_effective_level() <= 10:  # DEBUG, or always log fail-safe events
            if reason:
                self.get_logger().warn(f"{reason} (velocity=0, curvature=0)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server-ip", type=str, default="10.0.0.212")
    parser.add_argument("--server-port", type=int, default=18765)
    parser.add_argument("--live", action="store_true",
                         help="Actually publish to /ackermann_curvature_drive. Default is dry-run (log only).")
    parser.add_argument("--max-velocity", type=float, default=1.0, help="Hard clamp on |velocity| in m/s.")
    parser.add_argument("--max-curvature", type=float, default=3.0, help="Hard clamp on |curvature| in 1/m.")
    parser.add_argument("--max-buffer-age-s", type=float, default=3.0,
                         help="Fail-safe to STOP if the current chunk is older than this.")
    args = parser.parse_args()

    rclpy.init()
    node = ChunkBufferedPolicyClient(args)
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
