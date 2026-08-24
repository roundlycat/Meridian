#!/usr/bin/env python3
"""
bench_inference.py
------------------
Runs YOLOv8s on the Hailo-8L against a bench cam MP4 (or live camera).
Prints detection events to stdout as JSON — one line per frame with detections.
Designed to feed into the sensor ecology novelty pipeline.

Usage:
    python3 bench_inference.py --input /path/to/video.mp4
    python3 bench_inference.py --input /dev/video0        # live camera
    python3 bench_inference.py --input /path/to/video.mp4 --threshold 0.4
    python3 bench_inference.py --input /path/to/video.mp4 --mqtt  # publish to MQTT

Requirements:
    pip install opencv-python-headless
    pip install paho-mqtt  (only needed for --mqtt flag)
"""

import argparse
import json
import sys
import time
from datetime import datetime, timezone

import cv2
import numpy as np
import hailo_platform as hp

# ── Config ─────────────────────────────────────────────────────────────────────
HEF_PATH        = "/usr/local/hailo/resources/models/hailo8l/yolov8s.hef"
INPUT_SIZE      = (640, 640)   # YOLOv8s expects 640x640
COCO_CLASSES    = [
    "person","bicycle","car","motorcycle","airplane","bus","train","truck",
    "boat","traffic light","fire hydrant","stop sign","parking meter","bench",
    "bird","cat","dog","horse","sheep","cow","elephant","bear","zebra","giraffe",
    "backpack","umbrella","handbag","tie","suitcase","frisbee","skis","snowboard",
    "sports ball","kite","baseball bat","baseball glove","skateboard","surfboard",
    "tennis racket","bottle","wine glass","cup","fork","knife","spoon","bowl",
    "banana","apple","sandwich","orange","broccoli","carrot","hot dog","pizza",
    "donut","cake","chair","couch","potted plant","bed","dining table","toilet",
    "tv","laptop","mouse","remote","keyboard","cell phone","microwave","oven",
    "toaster","sink","refrigerator","book","clock","vase","scissors","teddy bear",
    "hair drier","toothbrush"
]

# ── Args ───────────────────────────────────────────────────────────────────────
parser = argparse.ArgumentParser(description="Hailo bench cam inference")
parser.add_argument("--input",     required=True, help="MP4 path or /dev/videoN")
parser.add_argument("--threshold", type=float, default=0.35, help="Detection confidence threshold")
parser.add_argument("--every",     type=int,   default=10,   help="Process every Nth frame (default 10)")
parser.add_argument("--mqtt",      action="store_true",      help="Publish detections to MQTT")
parser.add_argument("--mqtt-host", default="192.168.0.25",  help="MQTT broker host")
parser.add_argument("--mqtt-port", type=int, default=1883,  help="MQTT broker port")
parser.add_argument("--show",      action="store_true",      help="Show annotated frames (requires display)")
args = parser.parse_args()

# ── MQTT (optional) ────────────────────────────────────────────────────────────
mqtt_client = None
if args.mqtt:
    try:
        import paho.mqtt.client as mqtt
        mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        mqtt_client.connect(args.mqtt_host, args.mqtt_port)
        mqtt_client.loop_start()
        print(f"[mqtt] connected to {args.mqtt_host}:{args.mqtt_port}", file=sys.stderr)
    except Exception as e:
        print(f"[mqtt] failed to connect: {e} — continuing without MQTT", file=sys.stderr)
        mqtt_client = None

# ── Hailo setup ────────────────────────────────────────────────────────────────
print("[hailo] loading model...", file=sys.stderr)
params   = hp.VDevice.create_params()
vdevice  = hp.VDevice(params)
hef      = hp.HEF(HEF_PATH)
ng       = vdevice.configure(hef)[0]

input_info  = ng.get_input_vstream_infos()[0]
output_info = ng.get_output_vstream_infos()

print(f"[hailo] model ready — input: {input_info.name}", file=sys.stderr)
print(f"[hailo] outputs: {[o.name for o in output_info]}", file=sys.stderr)

# Input params
in_params  = [hp.InputVStreamParams.make(ng, quantized=False,
               format_type=hp.FormatType.FLOAT32)]
out_params = [hp.OutputVStreamParams.make(ng, quantized=False,
               format_type=hp.FormatType.FLOAT32)]

# ── Video source ───────────────────────────────────────────────────────────────
cap = cv2.VideoCapture(args.input)
if not cap.isOpened():
    print(f"[error] could not open: {args.input}", file=sys.stderr)
    sys.exit(1)

fps_src    = cap.get(cv2.CAP_PROP_FPS) or 30
total      = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
print(f"[video] source={args.input} fps={fps_src:.1f} frames={total}", file=sys.stderr)

# ── Preprocessing ──────────────────────────────────────────────────────────────
def preprocess(frame):
    """Resize to 640x640, normalize to [0,1], add batch dim."""
    img = cv2.resize(frame, INPUT_SIZE)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    img = img.astype(np.float32) / 255.0
    return np.expand_dims(img, axis=0)  # (1, 640, 640, 3)

# ── Postprocessing (simple NMS-free parse for FLOAT32 output) ─────────────────
def parse_detections(outputs, threshold, orig_w, orig_h):
    """
    YOLOv8 output is (1, 84, 8400) — 4 box coords + 80 class scores per anchor.
    Returns list of {label, confidence, bbox: [x1,y1,x2,y2]} in original coords.
    """
    detections = []
    for name, data in outputs.items():
        arr = np.squeeze(data)  # (84, 8400) or similar
        if arr.ndim != 2:
            continue

        # Transpose if needed to get (8400, 84)
        if arr.shape[0] == 84:
            arr = arr.T

        boxes   = arr[:, :4]    # cx, cy, w, h (normalized)
        scores  = arr[:, 4:]    # class scores

        class_ids   = np.argmax(scores, axis=1)
        confidences = scores[np.arange(len(scores)), class_ids]

        mask = confidences >= threshold
        boxes       = boxes[mask]
        class_ids   = class_ids[mask]
        confidences = confidences[mask]

        for box, cls_id, conf in zip(boxes, class_ids, confidences):
            cx, cy, w, h = box
            x1 = int((cx - w / 2) * orig_w)
            y1 = int((cy - h / 2) * orig_h)
            x2 = int((cx + w / 2) * orig_w)
            y2 = int((cy + h / 2) * orig_h)

            label = COCO_CLASSES[cls_id] if cls_id < len(COCO_CLASSES) else str(cls_id)
            detections.append({
                "label":      label,
                "confidence": round(float(conf), 3),
                "bbox":       [x1, y1, x2, y2],
            })

    # Sort by confidence descending
    detections.sort(key=lambda d: d["confidence"], reverse=True)
    return detections

# ── Inference loop ─────────────────────────────────────────────────────────────
frame_idx  = 0
det_count  = 0
t_start    = time.time()

print("[inference] starting — press Ctrl-C to stop", file=sys.stderr)

with hp.InferVStreams(ng, in_params, out_params) as streams:
    input_stream, output_streams = streams

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame_idx += 1
        if frame_idx % args.every != 0:
            continue

        orig_h, orig_w = frame.shape[:2]
        tensor = preprocess(frame)

        # Run inference
        input_data  = {input_info.name: tensor}
        output_data = {}
        input_stream.send(input_data)
        for out in output_streams:
            output_data[out.get_info().name] = out.recv()

        detections = parse_detections(output_data, args.threshold, orig_w, orig_h)

        if detections:
            det_count += 1
            ts = datetime.now(timezone.utc).isoformat()

            event = {
                "ts":          ts,
                "frame":       frame_idx,
                "source":      args.input,
                "detections":  detections,
                "top_label":   detections[0]["label"],
                "top_conf":    detections[0]["confidence"],
                "count":       len(detections),
            }

            # Always print to stdout (one JSON line per detection event)
            print(json.dumps(event), flush=True)

            # Optionally publish to MQTT ecology topic
            if mqtt_client:
                mqtt_client.publish(
                    "agents/bench/detections",
                    json.dumps(event),
                    qos=0
                )

        # Optional display
        if args.show and detections:
            for d in detections:
                x1, y1, x2, y2 = d["bbox"]
                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 80), 2)
                cv2.putText(frame, f"{d['label']} {d['confidence']:.2f}",
                            (x1, y1 - 6), cv2.FONT_HERSHEY_SIMPLEX,
                            0.5, (0, 255, 80), 1)
            cv2.imshow("Hailo Bench Inference", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

# ── Summary ────────────────────────────────────────────────────────────────────
elapsed = time.time() - t_start
print(f"\n[done] frames processed: {frame_idx // args.every} "
      f"| frames with detections: {det_count} "
      f"| elapsed: {elapsed:.1f}s", file=sys.stderr)

cap.release()
if args.show:
    cv2.destroyAllWindows()
if mqtt_client:
    mqtt_client.loop_stop()
    mqtt_client.disconnect()
