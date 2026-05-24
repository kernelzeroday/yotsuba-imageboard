import io
import logging
from contextlib import asynccontextmanager

import numpy as np
import open_clip
import torch
from fastapi import FastAPI, File, UploadFile, HTTPException, Request
from PIL import Image

logger = logging.getLogger("clip-server")

model = None
preprocess = None
tokenizer = None
device = None

NSFW_PROMPTS = {
    "unsafe": [
        "nudity",
        "pornography",
        "sexually explicit content",
        "naked person",
        "erotic content",
        "genitalia",
        "sexual act",
    ],
    "safe": [
        "a safe for work photograph",
        "a normal photograph",
        "an illustration or drawing",
        "a landscape or scenery",
        "text or screenshot",
        "a meme or comic",
        "food or drink",
        "an animal or pet",
        "a building or architecture",
        "a vehicle",
    ],
}

TAG_PROMPTS = [
    "anime or manga art",
    "a photograph",
    "a digital illustration",
    "a cartoon or comic",
    "a meme",
    "a screenshot",
    "pixel art",
    "a painting",
    "3D render or CGI",
    "a sketch or line drawing",
    "a person or portrait",
    "a group of people",
    "an animal",
    "a landscape or nature scene",
    "a cityscape or urban scene",
    "a building or architecture",
    "food or drink",
    "a vehicle or transportation",
    "text or typography",
    "a logo or icon",
    "abstract art",
    "a weapon",
    "a video game screenshot",
    "cosplay",
    "a selfie",
    "a political image",
    "a reaction image",
    "a diagram or chart",
    "a map",
    "clothing or fashion",
    "technology or electronics",
    "sports or athletics",
    "music or instruments",
    "military or warfare",
    "fantasy or sci-fi art",
    "horror or creepy content",
    "cute or wholesome content",
    "historical photograph",
    "infographic",
    "a flag or banner",
]

nsfw_features = None
tag_features = None


def encode_text_prompts(prompts: list[str]) -> torch.Tensor:
    tokens = tokenizer(prompts).to(device)
    with torch.no_grad():
        features = model.encode_text(tokens)
        features /= features.norm(dim=-1, keepdim=True)
    return features


@asynccontextmanager
async def lifespan(app: FastAPI):
    global model, preprocess, tokenizer, device
    global nsfw_features, tag_features

    device_name = "cuda" if torch.cuda.is_available() else "cpu"
    device = device_name
    logger.info(f"Using device: {device}")

    model, _, preprocess = open_clip.create_model_and_transforms(
        "ViT-B-32", pretrained="openai", device=device
    )
    tokenizer = open_clip.get_tokenizer("ViT-B-32")
    model.eval()

    all_nsfw = NSFW_PROMPTS["unsafe"] + NSFW_PROMPTS["safe"]
    nsfw_features = encode_text_prompts(all_nsfw)

    tag_features = encode_text_prompts(TAG_PROMPTS)

    logger.info("Model loaded, text prompts pre-encoded")
    yield


app = FastAPI(title="CLIP Server", lifespan=lifespan)


def process_image(image_bytes: bytes) -> torch.Tensor:
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    image_tensor = preprocess(image).unsqueeze(0).to(device)
    with torch.no_grad():
        features = model.encode_image(image_tensor)
        features /= features.norm(dim=-1, keepdim=True)
    return features


def compute_nsfw_score(image_features: torch.Tensor) -> float:
    sims = (image_features @ nsfw_features.T).squeeze(0).cpu().numpy()

    n_unsafe = len(NSFW_PROMPTS["unsafe"])
    unsafe_scores = sims[:n_unsafe]
    safe_scores = sims[n_unsafe:]

    unsafe_max = float(np.max(unsafe_scores))
    safe_max = float(np.max(safe_scores))

    score = unsafe_max / (unsafe_max + safe_max) if (unsafe_max + safe_max) > 0 else 0.0
    return round(score, 4)


def compute_tags(image_features: torch.Tensor, top_k: int = 5, threshold: float = 0.20) -> list[dict]:
    sims = (image_features @ tag_features.T).squeeze(0).cpu().numpy()
    indices = np.argsort(sims)[::-1][:top_k]
    tags = []
    for idx in indices:
        score = float(sims[idx])
        if score >= threshold:
            tags.append({"tag": TAG_PROMPTS[idx], "score": round(score, 4)})
    return tags


@app.post("/analyze")
async def analyze(file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()
        return _analyze(image_bytes)
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Analysis failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/predict")
async def predict(request: Request):
    """Legacy endpoint — accepts raw binary image data (compatible with original tensorchan API)."""
    try:
        image_bytes = await request.body()
        return _analyze(image_bytes)
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Analysis failed")
        raise HTTPException(status_code=500, detail=str(e))


def _analyze(image_bytes: bytes) -> dict:
    if len(image_bytes) > 20 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image too large (max 20MB)")
    if len(image_bytes) < 100:
        raise HTTPException(status_code=400, detail="Image too small or empty")

    image_features = process_image(image_bytes)
    nsfw_score = compute_nsfw_score(image_features)
    tags = compute_tags(image_features)

    description = ", ".join(t["tag"] for t in tags[:3]) if tags else "image"

    return {
        "nsfw": nsfw_score,
        "tags": tags,
        "description": description,
    }


@app.get("/health")
async def health():
    return {"status": "ok", "device": device, "model": "ViT-B-32::openai"}
