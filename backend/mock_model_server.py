"""
Local Mock ISL Model Server for SignBridge
==========================================
Simulates the remote Swin3D-S inference server on http://127.0.0.1:5001
Allows testing the complete end-to-end loop locally:
  Camera feed -> WebSocket -> 16-frame buffer -> Model -> Translation & TTS
"""

import itertools
import logging
import random
from fastapi import FastAPI, Request
from app.websocket.frame_codec import unpack_frames

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("mock_model_server")

app = FastAPI(title="SignBridge Mock Model Server")

# 76 ISL classes supported by signBridge
ISL_CLASSES = [
    "good", "morning", "afternoon", "evening", "night", "happy", "healthy",
    "today", "tomorrow", "yesterday", "time", "hour", "minute", "second",
    "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
    "beautiful", "big", "small", "tall", "short", "fast", "slow", "quiet", "loud"
]

# Cycle through sample words so predictions change naturally
_word_cycle = itertools.cycle(ISL_CLASSES)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/health/deep")
def deep_health():
    return {
        "status": "ok",
        "model": {
            "name": "Local Mock Swin3D-S",
            "loaded": True,
            "compiled": True,
            "device": "cpu",
            "dtype": "fp32",
            "fp16": False,
            "num_classes": len(ISL_CLASSES),
            "num_parameters": 50000000,
            "num_parameters_million": 50.0,
            "parameter_memory_mb": 200.0,
            "parameterized_layers": 100,
        },
        "input": {
            "input_shape": [1, 3, 16, 224, 224],
            "input_tensor_memory_mb": 9.6,
            "clip_length": 16,
            "resolution": "224x224",
            "batch_size": 1,
        },
        "inference": {
            "working": True,
            "time_ms": 30.0,
            "memory": "low",
        },
        "gpu": {"available": False},
        "runtime": {"python": "local"},
    }


@app.post("/predict_frames_bin")
async def predict_frames_bin(request: Request, top_k: int = 1):
    body = await request.body()
    try:
        frames = unpack_frames(body, expected=16)
        num_frames = len(frames)
    except Exception as exc:
        logger.warning("Frame unpacking note: %s", exc)
        num_frames = 16

    predicted_label = next(_word_cycle)
    confidence = round(random.uniform(0.88, 0.98), 2)

    logger.info("Predicted sign: '%s' (confidence: %.2f) from %d frames", predicted_label, confidence, num_frames)

    return {
        "prediction": predicted_label,
        "confidence": confidence,
        "inference_time_ms": 30.0,
    }


if __name__ == "__main__":
    import uvicorn
    logger.info("Starting Mock Model Server on http://127.0.0.1:5001")
    uvicorn.run(app, host="127.0.0.1", port=5001)

