#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Build /etc/sing-box/config.json from the Sub-Store subscription.

Restored from the NixOS setup (sing-box.nix + gen-singbox-base.mjs):

    🚀 节点选择    selector  [🚀 Cloudflare, ♻️ 自动选择, <每个节点>]  默认 🚀 Cloudflare
    🚀 Cloudflare  urltest   全部节点 (cp.cloudflare.com 测速)
    ♻️ 自动选择    urltest   全部节点 (gstatic 测速)
    direct / block

dae decides direct vs proxy; these groups only pick a node. The config is
staged in a temp dir and validated with `sing-box check` before it replaces the
live one, so a Sub-Store that is not up yet can never truncate a working config.

    uv run --no-project update.py [--no-restart]
"""

import grp
import json
import logging
import os
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path
from typing import Any

SUB_URL = "http://10.10.10.1:3001/qwerhyy123/download/collection/singbox?target=sing-box"
HEALTH_URL = "http://10.10.10.1:3001/qwerhyy123/api/utils/env"
CONFIG_FILE = Path("/etc/sing-box/config.json")
TEMPLATE = Path(__file__).resolve().parent / "base.json"
SING_BOX, SYSTEMCTL, GROUP = "/usr/bin/sing-box", "/usr/bin/systemctl", "sing-box"

PROXY_TAG, CF_TAG, AUTO_TAG = "🚀 节点选择", "🚀 Cloudflare", "♻️ 自动选择"
GROUP_TYPES = {"selector", "urltest", "direct", "block", "dns"}
JUNK = ("剩余", "到期")

log = logging.getLogger("sing-box-update")


class RefreshError(Exception):
    """Refresh failed; the message is short and printed as-is."""


def get(url: str, timeout: float, attempts: int = 1) -> bytes:
    """GET url, retrying a few times before giving up."""
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(url, timeout=timeout) as response:  # noqa: S310
                body: bytes = response.read()
                return body
        except OSError as error:
            if attempt == attempts - 1:
                msg = "网络请求失败"
                raise RefreshError(msg) from error
            time.sleep(5)
    raise AssertionError


def wait_for_substore() -> None:
    """Wait up to 2 min for the Sub-Store container to answer."""
    for _ in range(60):
        try:
            get(HEALTH_URL, timeout=2)
        except RefreshError:
            time.sleep(2)
        else:
            return
    msg = "Sub-Store 未就绪"
    raise RefreshError(msg)


def urltest(tag: str, nodes: list[str], url: str) -> dict[str, Any]:
    """Return a latency-tested group over the given nodes."""
    return {
        "type": "urltest",
        "tag": tag,
        "interrupt_exist_connections": True,
        "outbounds": nodes,
        "url": url,
        "interval": "1m",
        "tolerance": 50,
    }


def build_config(sub: dict[str, Any], template: dict[str, Any]) -> tuple[dict[str, Any], int]:
    """Return (config, pinned-field count)."""
    nodes: dict[str, dict[str, Any]] = {}
    for node in sub.get("outbounds") or []:
        tag = node.get("tag", "")
        if tag and node.get("type") not in GROUP_TYPES and not any(j in tag for j in JUNK):
            nodes.setdefault(tag, node)
    if not nodes:
        msg = "订阅里没有节点"
        raise RefreshError(msg)

    pinned = 0
    for node in nodes.values():
        tls = node.get("tls")
        # Sub-Store passes mihomo's pin field through; sing-box rejects the whole
        # config over it, and these nodes also set "insecure": true.
        if isinstance(tls, dict) and tls.pop("certificate_sha256", None) is not None:
            pinned += 1

    tags = list(nodes)
    config = json.loads(json.dumps(template))
    outbounds = [
        {
            "type": "selector",
            "tag": PROXY_TAG,
            "default": CF_TAG,
            "interrupt_exist_connections": True,
            "outbounds": [CF_TAG, AUTO_TAG, *tags],
        },
        urltest(CF_TAG, tags, "https://cp.cloudflare.com/generate_204"),
        urltest(AUTO_TAG, tags, "https://www.gstatic.com/generate_204"),
        {"type": "direct", "tag": "direct"},
        {"type": "block", "tag": "block"},
        *nodes.values(),
    ]
    config.update(outbounds=outbounds, route={**template.get("route", {}), "final": PROXY_TAG})

    # `sing-box check` does not catch dangling references, so do it here.
    refs = {tag for out in outbounds for tag in out.get("outbounds", [])}
    if missing := refs - {out["tag"] for out in outbounds}:
        msg = f"悬空引用: {sorted(missing)[0]}"
        raise RefreshError(msg)

    return config, pinned


def check(path: Path) -> None:
    """Validate a staged config with `sing-box check`."""
    result = subprocess.run(  # noqa: S603
        [SING_BOX, "check", "-c", str(path)], capture_output=True, check=False
    )
    if result.returncode:
        msg = "sing-box 校验失败"
        raise RefreshError(msg)


def install(payload: bytes) -> bool:
    """Write config.json atomically. Return False when it was unchanged."""
    config_dir = CONFIG_FILE.parent
    config_dir.mkdir(mode=0o750, parents=True, exist_ok=True)
    as_root = os.geteuid() == 0
    gid = grp.getgrnam(GROUP).gr_gid if as_root else os.getgid()
    if as_root:
        os.chown(config_dir, 0, gid)
    config_dir.chmod(0o750)

    if CONFIG_FILE.exists() and CONFIG_FILE.read_bytes() == payload:
        return False

    staged = config_dir / ".config.json"
    _ = staged.write_bytes(payload)
    if as_root:
        os.chown(staged, 0, gid)
    staged.chmod(0o640)
    _ = staged.replace(CONFIG_FILE)
    return True


def main() -> int:
    """Refresh the sing-box config and return the process exit code."""
    logging.basicConfig(level=logging.INFO, format="%(message)s", stream=sys.stderr)
    try:
        wait_for_substore()
        template: dict[str, Any] = json.loads(TEMPLATE.read_bytes())
        sub: dict[str, Any] = json.loads(get(SUB_URL, timeout=60, attempts=3))
        config, pinned = build_config(sub, template)
        payload = (json.dumps(config, ensure_ascii=False, indent=2) + "\n").encode()
        with tempfile.TemporaryDirectory(prefix="sing-box-") as workdir:
            staged = Path(workdir) / "config.json"
            _ = staged.write_bytes(payload)
            check(staged)
    except (RefreshError, ValueError, OSError) as error:
        # Never break a working daemon over a failed refresh.
        if CONFIG_FILE.exists():
            log.error("%s, 沿用现有配置", error)  # noqa: TRY400
            return 0
        log.error("%s, 且没有可用配置", error)  # noqa: TRY400
        return 1

    if not install(payload):
        log.info("配置未变化, 不重启")
        return 0

    log.info("已更新 %s", CONFIG_FILE)
    if pinned:
        log.info("移除了 %d 个节点的 tls.certificate_sha256", pinned)

    if "--no-restart" not in sys.argv:
        # --no-block: as ExecStartPre sing-box is not running yet, and waiting
        # for the restart job would deadlock.
        _ = subprocess.run(  # noqa: S603
            [SYSTEMCTL, "--no-block", "try-restart", "sing-box.service"], check=False
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
