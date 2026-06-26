"""DRY-RUN ROS2 client for the RoboRacer action policy.

Subscribes to /camera_0/image_raw, calls the inference server running on
robolang over websockets, and LOGS the predicted [curvature, velocity] for
the next 32 steps. Never constructs or publishes an AckermannCurvatureDriveMsg
or any other control message — there is no publisher in this script at all,
by design, so it cannot affect the car regardless of what the model predicts.

Run inside the orin_roboracer container (ROS2 Humble, rclpy available):
    python3 roboracer_dryrun_client.py --server-ip 10.0.0.212 --server-port 8765
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


class DryRunPolicyClient(Node):
    def __init__(self, server_uri: str, min_interval_s: float):
        super().__init__("roboracer_dryrun_policy_client")
        self._server_uri = server_uri
        self._min_interval_s = min_interval_s
        self._last_call_time = 0.0
        self._busy = False
        self._loop = asyncio.new_event_loop()
        self._loop_thread = threading.Thread(target=self._loop.run_forever, daemon=True)
        self._loop_thread.start()
        self.sub = self.create_subscription(Image, "/camera_0/image_raw", self._on_image, 1)
        self.get_logger().info(
            f"[DRY RUN] roboracer policy client started. Server: {server_uri}. "
            "This node NEVER publishes to any control topic - log-only."
        )

    def _on_image(self, msg: Image) -> None:
        now = time.time()
        if self._busy or (now - self._last_call_time) < self._min_interval_s:
            return
        if msg.encoding != "bgr8":
            self.get_logger().warn(f"unexpected encoding {msg.encoding!r}, expected bgr8 - skipping frame")
            return
        bgr = np.frombuffer(msg.data, dtype=np.uint8).reshape(msg.height, msg.width, 3)
        rgb = bgr[:, :, ::-1].copy()  # BGR -> RGB
        self._busy = True
        self._last_call_time = now
        asyncio.run_coroutine_threadsafe(self._predict_and_log(rgb), self._loop)

    async def _predict_and_log(self, rgb_image: np.ndarray) -> None:
        t0 = time.time()
        try:
            async with websockets.connect(self._server_uri, max_size=None) as ws:
                await ws.recv()  # metadata handshake
                await ws.send(msgpack.packb({"image": rgb_image.tobytes(), "shape": list(rgb_image.shape)}))
                response_raw = await asyncio.wait_for(ws.recv(), timeout=10.0)
            response = msgpack.unpackb(response_raw, raw=False)
            if "error" in response:
                self.get_logger().error(f"[DRY RUN] server error: {response['error']}")
            else:
                curvature = response["curvature"]
                velocity = response["velocity"]
                dt = time.time() - t0
                self.get_logger().info(
                    f"[DRY RUN] predicted (NOT published) first-step: "
                    f"curvature={curvature[0]:+.4f} 1/m, velocity={velocity[0]:+.4f} m/s "
                    f"(round-trip {dt:.2f}s, chunk={len(curvature)} steps)"
                )
        except Exception as exc:  # noqa: BLE001 - keep the node alive on any per-request failure
            self.get_logger().error(f"[DRY RUN] inference call failed: {exc}")
        finally:
            self._busy = False


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server-ip", type=str, default="10.0.0.212")
    parser.add_argument("--server-port", type=int, default=8765)
    parser.add_argument("--min-interval-s", type=float, default=2.0,
                         help="Minimum seconds between inference calls (camera publishes much faster than the model can run).")
    args = parser.parse_args()

    rclpy.init()
    node = DryRunPolicyClient(f"ws://{args.server_ip}:{args.server_port}", args.min_interval_s)
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
