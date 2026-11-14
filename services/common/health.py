"""Minimal HTTP liveness and readiness probes for long-running services."""
from __future__ import annotations

from dataclasses import dataclass

from aiohttp import web


@dataclass
class HealthState:
	ready: bool = False


async def _live(_: web.Request) -> web.Response:
	return web.json_response({"status": "ok"})


async def _ready(request: web.Request) -> web.Response:
	state: HealthState = request.app["state"]
	status = 200 if state.ready else 503
	return web.json_response({"status": "ready" if state.ready else "not_ready"}, status=status)


async def start_health_server(host: str, port: int, state: HealthState) -> web.AppRunner:
	app = web.Application()
	app["state"] = state
	app.router.add_get("/health", _live)
	app.router.add_get("/ready", _ready)
	runner = web.AppRunner(app, access_log=None)
	await runner.setup()
	site = web.TCPSite(runner, host, port)
	await site.start()
	return runner
