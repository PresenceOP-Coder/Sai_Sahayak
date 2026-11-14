import base64
import json
import logging
import os
import time
from io import BytesIO

import requests
from dotenv import load_dotenv
from PIL import Image

from app.websocket.frame_codec import pack_frames

load_dotenv()

logger = logging.getLogger(__name__)

CLIP_LENGTH = 16
JPEG_QUALITY = 80


class ISLModelAPI:
    def __init__(self, top_k: int = 5):
        self.base_url = os.getenv(
            "MODEL_API_URL",
            os.getenv("BASE_URL", "http://127.0.0.1:7860"),
        ).rstrip("/")
        if not self.base_url.startswith(("http://", "https://")):
            self.base_url = f"http://{self.base_url}"

        self.api_type = os.getenv("MODEL_API_TYPE", "fastapi").lower()
        self.predict_frames_bin_url  = f"{self.base_url}/predict_frames_bin"
        self.predict_video_url       = f"{self.base_url}/predict"
        self.health_url              = f"{self.base_url}/health"
        self.deep_health_url         = f"{self.base_url}/health/deep"
        self.gradio_info_url = f"{self.base_url}/gradio_api/info"
        self.gradio_call_url = (
            f"{self.base_url}/gradio_api/call/predict_frames_bin"
        )
        self.gradio_submit_url = (
            f"{self.base_url}/gradio_api/call/v2/predict_frames_bin"
        )
        self.top_k                   = top_k

        # Persistent connection pool — avoids TCP handshake on every request
        self.session = requests.Session()
        adapter = requests.adapters.HTTPAdapter(
            pool_connections=2,
            pool_maxsize=4,
            max_retries=0,          # retries handled manually below
        )
        self.session.mount("https://", adapter)

    #  Health
    def check_health(self) -> bool:
        try:
            if self.api_type == "gradio":
                r = self.session.get(self.gradio_info_url, timeout=3)
                if r.status_code != 200:
                    return False
                endpoints = r.json().get("named_endpoints", {})
                return "/predict_frames_bin" in endpoints

            r = self.session.get(self.health_url, timeout=3)
            return r.status_code == 200 and r.json().get("status") == "ok"
        except Exception:
            return False

    def deep_health(self):
        try:
            if self.api_type == "gradio":
                if not self.check_health():
                    return {"isl_model_status": "Model server unavailable"}
                return {
                    "isl_model_status": "connected",
                    "model_api_type": "gradio",
                    "endpoint": "/predict_frames_bin",
                }

            r = self.session.get(self.deep_health_url, timeout=5)

            if r.status_code == 200:
                json_response = r.json()

                model = json_response.get("model", {})
                input_info = json_response.get("input", {})
                inference = json_response.get("inference", {})
                gpu = json_response.get("gpu", {})
                runtime = json_response.get("runtime", {})

                return {
                    "isl_model_status": "connected",

                    # Model
                    "model_name": model.get("name"),
                    "model_loaded": model.get("loaded"),
                    "model_compiled": model.get("compiled"),
                    "device": model.get("device"),
                    "dtype": model.get("dtype"),
                    "fp16": model.get("fp16"),
                    "num_classes": model.get("num_classes"),

                    # Model size
                    "num_parameters": model.get("num_parameters"),
                    "num_parameters_million": model.get(
                        "num_parameters_million"
                    ),
                    "parameter_memory_mb": model.get(
                        "parameter_memory_mb"
                    ),
                    "parameterized_layers": model.get(
                        "parameterized_layers"
                    ),
                    "total_modules": model.get(
                        "total_modules"
                    ),

                    # Input
                    "input_shape": input_info.get("input_shape"),
                    "input_tensor_memory_mb": input_info.get(
                        "input_tensor_memory_mb"
                    ),
                    "clip_length": input_info.get("clip_length"),
                    "resolution": input_info.get("resolution"),
                    "batch_size": input_info.get("batch_size"),

                    # Inference
                    "inference_working": inference.get("working"),
                    "inference_time_ms": inference.get("time_ms"),

                    # Memory
                    "memory": inference.get("memory"),

                    # GPU
                    "gpu": gpu,

                    # Runtime
                    "runtime": runtime,
                }

            else:
                return {
                    "isl_model_status": (
                        f"Model server not ready "
                        f"(HTTP {r.status_code})"
                    )
                }

        except Exception:
            logger.exception("Deep health check failed")
            return {
                "isl_model_status": "Model server unavailable"
            }

    # Frames path (primary real-time path)
    @staticmethod
    def _to_jpeg(frame) -> bytes:
        """
        Return JPEG bytes for one frame.

        Frames normally arrive pre-encoded (bytes) from the WebSocket
        pipeline, which encodes each frame once when it enters the sliding
        buffer. PIL images are still accepted and encoded here.
        """
        if isinstance(frame, (bytes, bytearray, memoryview)):
            return bytes(frame)

        buf = BytesIO()
        try:
            frame.save(buf, format="JPEG", quality=JPEG_QUALITY)
            return buf.getvalue()
        finally:
            buf.close()

    def predict_from_frames(self, frames: list) -> dict:
        """
        Send 16 JPEG frames to /predict_frames_bin as one binary container.

        `frames` is a list of JPEG bytes (preferred) or PIL Images.
        No base64 and no JSON: see frame_codec.pack_frames.
        """
        if not frames or len(frames) != CLIP_LENGTH:
            return {"error": f"Exactly {CLIP_LENGTH} frames required, got {len(frames) if frames else 0}"}

        try:
            body = pack_frames([self._to_jpeg(f) for f in frames])
            logger.info(
                "[MODEL TX] binary frame batch: %.2f KB (%d bytes), frames=%d",
                len(body) / 1024,
                len(body),
                len(frames),
            )
        except Exception as e:
            return {"error": f"Failed to encode frames: {e}"}

        last_err = "Unknown error"

        for attempt in range(2):
            try:
                if self.api_type == "gradio":
                    return self._predict_from_gradio(body)

                r = self.session.post(
                    self.predict_frames_bin_url,
                    params={"top_k": self.top_k},
                    data=body,
                    headers={"Content-Type": "application/octet-stream"},
                    timeout=15,
                )
                if r.status_code == 200:
                    return r.json()
                if r.status_code == 503:
                    time.sleep(1.5)
                    continue
                last_err = f"API error {r.status_code}: {r.text}"
            except Exception as e:
                last_err = str(e)
                time.sleep(0.5)

        return {"error": last_err}

    def _predict_from_gradio(self, body: bytes) -> dict:
        payload = {"payload_b64": base64.b64encode(body).decode("ascii")}

        response = self.session.post(
            self.gradio_submit_url,
            json=payload,
            timeout=15,
        )
        if response.status_code != 200:
            return {
                "error": (
                    f"Gradio API error {response.status_code}: "
                    f"{response.text}"
                )
            }

        event_id = response.json().get("event_id")
        if not event_id:
            return {"error": "Gradio API did not return an event ID"}

        events = self.session.get(
            f"{self.gradio_call_url}/{event_id}",
            stream=True,
            timeout=60,
        )
        if events.status_code != 200:
            return {
                "error": (
                    f"Gradio event error {events.status_code}: "
                    f"{events.text}"
                )
            }

        for line in events.iter_lines(decode_unicode=True):
            if not line or not line.startswith("data:"):
                continue

            data = json.loads(line.removeprefix("data:").strip())
            if isinstance(data, list) and data and isinstance(data[0], dict):
                return data[0]
            if isinstance(data, dict):
                return data

        return {"error": "Gradio API ended without a prediction"}

    # Video path (fallback only)
    def predict(self, frames: list[Image.Image]) -> dict:
        """
        Compile PIL frames → in-memory MP4 (no disk I/O) and POST to /predict.
        Only used as a fallback in hybrid mode.
        """
        if not frames:
            return {"error": "No frames provided"}

        import cv2
        import numpy as np

        width, height = frames[0].size
        fourcc        = cv2.VideoWriter_fourcc(*'mp4v')

        # Write directly to memory via a temp buffer trick using BytesIO-backed file
        # cv2.VideoWriter requires a real path, so use /tmp (RAM-backed on Linux)
        tmp_path = f"/tmp/isl_infer_{int(time.time()*1000)}.mp4"
        out      = cv2.VideoWriter(tmp_path, fourcc, 15.0, (width, height))
        for frame in frames:
            out.write(cv2.cvtColor(np.array(frame), cv2.COLOR_RGB2BGR))
        out.release()

        try:
            with open(tmp_path, "rb") as f:
                r = self.session.post(
                    self.predict_video_url,
                    params={"top_k": self.top_k},
                    files={"file": (f"clip.mp4", f, "video/mp4")},
                    timeout=15,
                )
            if r.status_code == 200:
                return r.json()
            return {"error": f"API error {r.status_code}: {r.text}"}
        except Exception as e:
            return {"error": str(e)}
        finally:
            if os.environ.get("SAVE_TEST_VIDEOS", "0") != "1":
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)