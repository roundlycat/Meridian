"""
Meridian V2 — Relational Autonomy Core Service Daemon

Runs the 5-layer relational autonomy loop as an asynchronous daemon.
Subscribes to sensor ecology + wearer MQTT streams and broadcasts
stigmergic deposits (haptic for wrist-puck, spatial overlays for AR).

Topics Subscribed:
  • garden/ecology/+/telemetry
  • wearer/ecology/+/telemetry
  • meridian/device/health
  • meridian/protocols/land

Topics Published:
  • meridian/autonomy/deposits/haptic
  • meridian/autonomy/deposits/ar
  • meridian/autonomy/state

Run:
  python -m services.autonomy
"""

from __future__ import annotations

import asyncio
import json
import logging
import signal
import sys
from typing import Any, Dict

from services.autonomy.core import RelationalAutonomyCore

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("autonomy.daemon")


def serialize_deposit_payload(obj: Any) -> Any:
    """Helper to convert dataclasses and enums to JSON-serializable dictionaries."""
    if hasattr(obj, "__dataclass_fields__"):
        res = {}
        for k in obj.__dataclass_fields__:
            val = getattr(obj, k)
            if hasattr(val, "value"):
                res[k] = val.value
            elif isinstance(val, (set, list)):
                res[k] = [v.value if hasattr(v, "value") else v for v in val]
            elif hasattr(val, "__dataclass_fields__"):
                res[k] = serialize_deposit_payload(val)
            else:
                res[k] = val
        return res
    if hasattr(obj, "value"):
        return obj.value
    return str(obj)


class AutonomyService:
    def __init__(self, host: str = "localhost", port: int = 1883) -> None:
        self.host = host
        self.port = port
        self.core = RelationalAutonomyCore()
        self._running = False

    def handle_incoming_message(self, topic: str, payload_str: str) -> None:
        try:
            data = json.loads(payload_str)
        except Exception as e:
            log.warning("Failed to decode JSON from %s: %s", topic, e)
            return

        # garden/ecology/<slug>/telemetry
        if topic.startswith("garden/ecology/") and topic.endswith("/telemetry"):
            slug = topic.split("/")[2]
            metrics = data.get("metrics", data)
            self.core.ingest_ecology_telemetry(slug, metrics)

        # wearer/ecology/<slug>/telemetry
        elif topic.startswith("wearer/ecology/"):
            metrics = data.get("metrics", data)
            self.core.ingest_wearer_telemetry(metrics)

        # meridian/device/health
        elif topic == "meridian/device/health":
            self.core.ingest_device_health(
                battery_voltage=data.get("battery_voltage"),
                charging_in_firebag=data.get("charging_in_firebag"),
                bus_errors=data.get("bus_errors"),
                moisture_detected=data.get("moisture_detected"),
            )

        # meridian/protocols/land
        elif topic == "meridian/protocols/land":
            active = data.get("active", False)
            name = data.get("protocol_name", "")
            self.core.set_land_protocol(active=active, protocol_name=name)

    async def run(self) -> None:
        self._running = True
        log.info("Starting Meridian Relational Autonomy Core...")
        log.info("Connecting to MQTT broker at %s:%d", self.host, self.port)

        try:
            import aiomqtt
            has_aiomqtt = True
        except ImportError:
            has_aiomqtt = False
            log.warning("aiomqtt not found; running in standalone local test mode")

        if not has_aiomqtt:
            await self._run_offline_loop()
            return

        backoff = 2
        while self._running:
            try:
                async with aiomqtt.Client(self.host, self.port) as client:
                    log.info("Connected to MQTT broker successfully.")
                    backoff = 2

                    await client.subscribe("garden/ecology/+/telemetry")
                    await client.subscribe("wearer/ecology/+/telemetry")
                    await client.subscribe("meridian/device/health")
                    await client.subscribe("meridian/protocols/land")

                    async def mqtt_listener():
                        async for message in client.messages:
                            payload = message.payload.decode("utf-8")
                            self.handle_incoming_message(str(message.topic), payload)

                    async def autonomy_publisher():
                        while self._running:
                            deposits = self.core.tick()

                            # 1. Haptic Deposit
                            haptic_json = json.dumps(
                                serialize_deposit_payload(deposits.haptic),
                                indent=2,
                            )
                            await client.publish(
                                "meridian/autonomy/deposits/haptic",
                                haptic_json,
                                qos=0,
                            )

                            # 2. AR Deposit
                            ar_json = json.dumps(
                                serialize_deposit_payload(deposits.ar),
                                indent=2,
                            )
                            await client.publish(
                                "meridian/autonomy/deposits/ar",
                                ar_json,
                                qos=0,
                            )

                            # 3. Overall State
                            state_summary = {
                                "timestamp": deposits.timestamp,
                                "regime": deposits.regime.value,
                                "refusal_summary": self.core.constraints.evaluate(
                                    deposits.timestamp, {}
                                ).summary,
                                "coherence": deposits.system_coherence,
                            }
                            await client.publish(
                                "meridian/autonomy/state",
                                json.dumps(state_summary, indent=2),
                                qos=0,
                            )

                            await asyncio.sleep(4.0)

                    listener_task = asyncio.create_task(mqtt_listener())
                    publisher_task = asyncio.create_task(autonomy_publisher())

                    done, pending = await asyncio.wait(
                        [listener_task, publisher_task],
                        return_when=asyncio.FIRST_EXCEPTION,
                    )
                    for task in pending:
                        task.cancel()

            except Exception as e:
                log.warning("Broker connection dropped (%s). Retrying in %ds...", e, backoff)
                await asyncio.sleep(backoff)
                backoff = min(30, backoff * 2)

    async def _run_offline_loop(self) -> None:
        """Fallback local loop when running standalone without live MQTT broker."""
        log.info("Running local in-memory autonomy loop...")
        while self._running:
            deposits = self.core.tick()
            log.info(
                "[AUTONOMY TICK] Regime: %s | Haptic: %s (LRA: %d, Servo: %.2f) | AR Luminance: %.2f",
                deposits.regime.value,
                deposits.haptic.state.value,
                deposits.haptic.lra_intensity,
                deposits.haptic.servo_target_position,
                deposits.ar.luminance,
            )
            await asyncio.sleep(5.0)

    def stop(self) -> None:
        self._running = False


async def main() -> None:
    # Try loading from common config if available, else default localhost
    try:
        from services.common import load_config
        cfg = load_config()
        host = cfg.mqtt_host
        port = cfg.mqtt_port
    except Exception:
        host = "localhost"
        port = 1883

    service = AutonomyService(host=host, port=port)

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, service.stop)
        except NotImplementedError:
            pass  # Windows event loop limitation

    await service.run()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        log.info("Autonomy service stopped by user.")
