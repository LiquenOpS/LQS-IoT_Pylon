#!/usr/bin/env python3
"""Minimal Discovery API: pending devices for provisioning.
POST /devices - register; GET /devices - list; DELETE /devices/<id> - remove.
"""
import json
import os
import threading
from pathlib import Path

from flask import Flask, jsonify, request

app = Flask(__name__)
DATA_FILE = os.environ.get("DISCOVERY_DATA_FILE", "/data/pending_devices.json")
LOCK = threading.Lock()


def _load():
    p = Path(DATA_FILE)
    if not p.exists():
        return {}
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def _save(data: dict):
    Path(DATA_FILE).parent.mkdir(parents=True, exist_ok=True)
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


@app.route("/devices", methods=["GET"])
def list_devices():
    with LOCK:
        data = _load()
    return jsonify(list(data.values()))


@app.route("/devices/<device_id>", methods=["GET"])
def get_device(device_id):
    with LOCK:
        data = _load()
    d = data.get(device_id)
    if not d:
        return jsonify({"error": "not found"}), 404
    return jsonify(d)


@app.route("/devices", methods=["POST"])
def register_device():
    body = request.get_json(force=True, silent=True) or {}
    device_id = body.get("device_id") or body.get("deviceId")
    device_name = body.get("device_name") or body.get("deviceName")
    endpoint = body.get("endpoint")
    entity_type = body.get("entity_type", "Yardmaster")

    if not device_id or not endpoint:
        return jsonify({"error": "device_id and endpoint required"}), 400

    device_name = device_name or device_id
    entry = {
        "device_id": device_id,
        "device_name": device_name,
        "entity_type": entity_type,
        "endpoint": endpoint.rstrip("/"),
    }

    with LOCK:
        data = _load()
        data[device_id] = entry
        _save(data)

    return jsonify(entry), 201


@app.route("/devices/<device_id>", methods=["DELETE"])
def remove_device(device_id):
    with LOCK:
        data = _load()
        if device_id not in data:
            return jsonify({"error": "not found"}), 404
        del data[device_id]
        _save(data)
    return "", 204


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("DISCOVERY_PORT", "5050")))
