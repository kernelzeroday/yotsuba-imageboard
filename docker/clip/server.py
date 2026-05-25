import io
import logging
from contextlib import asynccontextmanager

import numpy as np
import open_clip
import torch
import yake
from fastapi import FastAPI, File, UploadFile, HTTPException, Request
from PIL import Image
from transformers import BlipProcessor, BlipForConditionalGeneration, pipeline

logger = logging.getLogger("clip-server")

clip_model = None
clip_preprocess = None
clip_tokenizer = None
blip_model = None
blip_processor = None
device = None
toxicity_pipe = None

kw_extractor = None

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

ANIME_PROMPTS = {
    "anime": [
        "anime art style illustration",
        "manga drawing",
        "Japanese animation character",
        "anime girl or boy",
        "chibi character",
        "visual novel artwork",
        "anime screenshot",
        "Japanese cartoon style",
    ],
    "not_anime": [
        "a real photograph of a person",
        "a realistic photograph",
        "a 3D rendering",
        "western cartoon or comic",
        "pixel art or retro game",
        "a painting or fine art",
        "a meme with text overlay",
        "a screenshot of a website or app",
    ],
}

AI_DETECT_PROMPTS = {
    "ai": [
        "AI-generated text that mimics human conversation",
        "chatbot response pretending to be a person",
        "template-like AI assistant response",
        "AI language model output",
        "automated generated content",
        "text written by an AI to sound human",
    ],
    "human": [
        "genuine human conversation with typos and slang",
        "informal message with personal opinions",
        "authentic human emotion and experience",
        "natural writing with mistakes and corrections",
        "raw unfiltered human perspective",
        "personal anecdote or real experience",
    ],
}

VISUAL_VOCAB = [
    # People & Characters
    ("a photo of a person", "person"),
    ("a photo of a woman", "woman"),
    ("a photo of a man", "man"),
    ("a young girl", "girl"),
    ("a young boy", "boy"),
    ("a baby or infant", "baby"),
    ("a group of people", "group"),
    ("a couple together", "couple"),
    ("an elderly person", "elderly"),
    # Anime/Manga
    ("anime girl character", "anime girl"),
    ("anime boy character", "anime boy"),
    ("mecha robot anime", "mecha"),
    ("chibi cute character", "chibi"),
    ("magical girl transformation", "magical girl"),
    ("monster or creature", "monster"),
    ("kemonomimi animal ears character", "animal ears"),
    ("a humanoid robot or android", "android"),
    # Animals
    ("a cat", "cat"),
    ("a dog", "dog"),
    ("a bird", "bird"),
    ("a fish or marine life", "fish"),
    ("a horse", "horse"),
    ("an insect or bug", "insect"),
    ("a reptile or lizard", "reptile"),
    # Settings
    ("outdoors nature scene", "outdoors"),
    ("indoors interior room", "indoors"),
    ("a beach with sand and water", "beach"),
    ("a forest with trees", "forest"),
    ("a mountain landscape", "mountain"),
    ("a city skyline or urban street", "city"),
    ("a park or garden", "park"),
    ("outer space or cosmos", "space"),
    ("underwater ocean scene", "underwater"),
    ("a desert landscape", "desert"),
    ("a snowy winter scene", "snow"),
    ("a sunset or sunrise sky", "sunset"),
    ("night time darkness", "night"),
    ("a school or classroom", "school"),
    ("a kitchen", "kitchen"),
    ("an office or workspace", "office"),
    ("a bathroom", "bathroom"),
    ("a library", "library"),
    ("a hospital or medical", "hospital"),
    ("a stage or concert", "stage"),
    # Vehicles
    ("a car or automobile", "car"),
    ("a motorcycle", "motorcycle"),
    ("a bicycle", "bicycle"),
    ("a train or railway", "train"),
    ("an airplane or aircraft", "airplane"),
    ("a boat or ship", "boat"),
    ("a military tank", "tank"),
    ("a spacecraft or rocket", "spacecraft"),
    # Objects
    ("food and meal", "food"),
    ("a drink or beverage", "drink"),
    ("a computer or laptop", "computer"),
    ("a mobile phone or smartphone", "phone"),
    ("a video game or gaming", "gaming"),
    ("a book or manga volume", "book"),
    ("flowers or floral arrangement", "flowers"),
    ("a musical instrument", "instrument"),
    ("a camera or photography equipment", "camera"),
    ("clothing and fashion", "fashion"),
    ("a hat or headwear", "hat"),
    ("eyeglasses or sunglasses", "glasses"),
    ("jewelry or accessories", "jewelry"),
    ("a mask or face covering", "mask"),
    ("a plush toy or stuffed animal", "plush"),
    ("a figurine or action figure", "figurine"),
    # Weapons
    ("a gun or firearm", "gun"),
    ("a sword or blade weapon", "sword"),
    ("a bow and arrow", "bow"),
    ("military equipment and gear", "military"),
    # Architecture
    ("a building exterior", "building"),
    ("a house or home", "house"),
    ("a church temple or shrine", "shrine"),
    ("a castle or fortress", "castle"),
    ("a bridge", "bridge"),
    ("a tower or skyscraper", "tower"),
    ("ruins or abandoned place", "ruins"),
    ("a Japanese torii gate", "torii"),
    # Art Style
    ("a photograph", "photograph"),
    ("a painting artwork", "painting"),
    ("a pencil drawing or sketch", "sketch"),
    ("watercolor artwork", "watercolor"),
    ("digital art illustration", "digital art"),
    ("pixel art retro game style", "pixel art"),
    ("3D rendered CGI image", "3d render"),
    ("a comic strip or panel", "comic"),
    ("abstract art", "abstract"),
    ("surrealist artwork", "surreal"),
    ("minimalist design", "minimalist"),
    ("graffiti or street art", "graffiti"),
    ("calligraphy or hand lettering", "calligraphy"),
    ("an internet meme with funny text overlay", "meme"),
    ("a screenshot of software or website", "screenshot"),
    ("an infographic or data chart", "infographic"),
    ("a map or diagram", "diagram"),
    ("a logo or icon design", "logo"),
    ("black and white monochrome", "monochrome"),
    ("vintage retro style photo", "vintage"),
    ("vaporwave aesthetic", "vaporwave"),
    ("art nouveau style", "art nouveau"),
    # Colors
    ("predominantly red colored image", "red"),
    ("predominantly blue colored image", "blue"),
    ("predominantly green colored image", "green"),
    ("predominantly yellow or gold image", "yellow"),
    ("predominantly pink colored image", "pink"),
    ("predominantly purple colored image", "purple"),
    ("very colorful vibrant image", "colorful"),
    ("dark moody shadowy image", "dark"),
    ("bright well-lit image", "bright"),
    ("pastel soft colors", "pastel"),
    # Actions
    ("smiling happy expression", "smiling"),
    ("crying sad expression", "crying"),
    ("angry furious expression", "angry"),
    ("sleeping or resting", "sleeping"),
    ("eating food", "eating"),
    ("drinking a beverage", "drinking"),
    ("reading a book", "reading"),
    ("playing a sport", "sports"),
    ("dancing", "dancing"),
    ("swimming in water", "swimming"),
    ("fighting or combat scene", "fighting"),
    ("running or jogging", "running"),
    ("cooking or baking", "cooking"),
    ("singing or performing", "singing"),
    # Themes
    ("cute and adorable kawaii", "cute"),
    ("scary horror creepy", "horror"),
    ("funny humorous comedy", "funny"),
    ("romantic love affection", "romantic"),
    ("sad melancholic emotional", "melancholic"),
    ("epic dramatic intense", "epic"),
    ("peaceful calm serene", "peaceful"),
    ("chaotic energetic wild", "chaotic"),
    ("mysterious eerie atmosphere", "mysterious"),
    ("nostalgic retro memories", "nostalgic"),
    # Content
    ("a landscape panorama", "landscape"),
    ("a portrait close-up", "portrait"),
    ("text words and typography", "text"),
    ("nature and wildlife photography", "nature"),
    ("science fiction futuristic", "sci-fi"),
    ("fantasy medieval magical", "fantasy"),
    ("technology electronics gadgets", "technology"),
    ("cosplay costume roleplay", "cosplay"),
    ("wallpaper desktop background", "wallpaper"),
    ("album cover music artwork", "album art"),
    ("soviet propaganda poster art style", "propaganda"),
    ("tattoo body art", "tattoo"),
]

nsfw_features = None
ai_detect_features = None
anime_features = None
vocab_features = None
vocab_labels = None


def encode_text_prompts(prompts: list[str]) -> torch.Tensor:
    tokens = clip_tokenizer(prompts).to(device)
    with torch.no_grad():
        features = clip_model.encode_text(tokens)
        features /= features.norm(dim=-1, keepdim=True)
    return features


@asynccontextmanager
async def lifespan(app: FastAPI):
    global clip_model, clip_preprocess, clip_tokenizer, device
    global blip_model, blip_processor
    global nsfw_features, ai_detect_features, anime_features, kw_extractor
    global vocab_features, vocab_labels
    global toxicity_pipe

    device_name = "cuda" if torch.cuda.is_available() else "cpu"
    device = device_name
    logger.info(f"Using device: {device}")

    clip_model, _, clip_preprocess = open_clip.create_model_and_transforms(
        "ViT-B-32", pretrained="openai", device=device
    )
    clip_tokenizer = open_clip.get_tokenizer("ViT-B-32")
    clip_model.eval()

    all_nsfw = NSFW_PROMPTS["unsafe"] + NSFW_PROMPTS["safe"]
    nsfw_features = encode_text_prompts(all_nsfw)

    all_ai = AI_DETECT_PROMPTS["ai"] + AI_DETECT_PROMPTS["human"]
    ai_detect_features = encode_text_prompts(all_ai)

    all_anime = ANIME_PROMPTS["anime"] + ANIME_PROMPTS["not_anime"]
    anime_features = encode_text_prompts(all_anime)

    vocab_prompts = [p for p, _ in VISUAL_VOCAB]
    vocab_labels = [l for _, l in VISUAL_VOCAB]
    vocab_features = encode_text_prompts(vocab_prompts)
    logger.info(f"Visual vocabulary loaded: {len(VISUAL_VOCAB)} concepts")

    logger.info("CLIP model loaded")

    blip_processor = BlipProcessor.from_pretrained("Salesforce/blip-image-captioning-base")
    blip_model = BlipForConditionalGeneration.from_pretrained(
        "Salesforce/blip-image-captioning-base"
    ).to(device)
    blip_model.eval()
    logger.info("BLIP captioning model loaded")

    toxicity_pipe = pipeline(
        "text-classification",
        model="unitary/unbiased-toxic-roberta",
        device=-1,
        truncation=True,
        max_length=512,
        top_k=None,
    )
    logger.info("unbiased-toxic-roberta model loaded")

    kw_extractor = yake.KeywordExtractor(
        lan="en", n=2, dedupLim=0.5, top=15, features=None
    )
    logger.info("YAKE keyword extractor ready")

    yield


app = FastAPI(title="CLIP Server", lifespan=lifespan)


def process_image(image_bytes: bytes) -> torch.Tensor:
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    image_tensor = clip_preprocess(image).unsqueeze(0).to(device)
    with torch.no_grad():
        features = clip_model.encode_image(image_tensor)
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


def compute_toxicity(text: str) -> dict:
    results = toxicity_pipe(text[:512])
    if not results:
        return {}
    scores = {}
    for item in results[0] if isinstance(results[0], list) else results:
        scores[item["label"]] = round(item["score"], 4)
    return scores


def compute_ai_score(text: str) -> float:
    features = encode_text_prompts([text])
    sims = (features @ ai_detect_features.T).squeeze(0).cpu().numpy()

    n_ai = len(AI_DETECT_PROMPTS["ai"])
    ai_scores = sims[:n_ai]
    human_scores = sims[n_ai:]

    ai_max = float(np.max(ai_scores))
    human_max = float(np.max(human_scores))

    score = ai_max / (ai_max + human_max) if (ai_max + human_max) > 0 else 0.0
    return round(score, 4)


def compute_anime_score(image_features: torch.Tensor) -> float:
    sims = (image_features @ anime_features.T).squeeze(0).cpu().numpy()

    n_anime = len(ANIME_PROMPTS["anime"])
    anime_scores = sims[:n_anime]
    not_anime_scores = sims[n_anime:]

    anime_max = float(np.max(anime_scores))
    not_anime_max = float(np.max(not_anime_scores))

    score = anime_max / (anime_max + not_anime_max) if (anime_max + not_anime_max) > 0 else 0.0
    return round(score, 4)


def compute_visual_tags(image_features: torch.Tensor, threshold: float = 0.25, max_tags: int = 20) -> list[dict]:
    sims = (image_features @ vocab_features.T).squeeze(0).cpu().numpy()
    mean_sim = float(np.mean(sims))
    std_sim = float(np.std(sims))
    adaptive_thresh = max(threshold, mean_sim + 1.5 * std_sim)
    tags = []
    for i, score in enumerate(sims):
        if float(score) >= adaptive_thresh:
            tags.append({"tag": vocab_labels[i], "score": round(float(score), 4)})
    tags.sort(key=lambda x: x["score"], reverse=True)
    return tags[:max_tags]


def caption_image(image_bytes: bytes) -> str:
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    inputs = blip_processor(image, return_tensors="pt").to(device)
    with torch.no_grad():
        out = blip_model.generate(**inputs, max_new_tokens=100, num_beams=3)
    caption = blip_processor.decode(out[0], skip_special_tokens=True)
    return caption


def extract_keywords(text: str, max_keywords: int = 5) -> list[str]:
    if not text or len(text.strip()) < 5:
        return []
    keywords = kw_extractor.extract_keywords(text)
    return [kw for kw, score in keywords[:max_keywords]]


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
    """Legacy endpoint — accepts raw binary image data."""
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
    anime_score = compute_anime_score(image_features)
    caption = caption_image(image_bytes)
    blip_tags = extract_keywords(caption, max_keywords=10)
    visual_tags = compute_visual_tags(image_features)

    seen = set()
    all_tags = []
    for t in blip_tags:
        key = t.lower()
        if key not in seen:
            seen.add(key)
            all_tags.append({"tag": t, "score": 1.0})
    for vt in visual_tags:
        key = vt["tag"].lower()
        if key not in seen:
            seen.add(key)
            all_tags.append(vt)

    all_desc_tags = list(dict.fromkeys(blip_tags + [vt["tag"] for vt in visual_tags]))
    description = ", ".join(all_desc_tags) if all_desc_tags else caption

    return {
        "nsfw": nsfw_score,
        "anime": anime_score,
        "tags": all_tags,
        "description": description,
        "caption": caption,
        "visual_tags": visual_tags,
    }


@app.post("/embed")
async def embed(file: UploadFile = File(...)):
    """Return the raw 512-dim CLIP embedding for an image."""
    try:
        image_bytes = await file.read()
        if len(image_bytes) > 20 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Image too large (max 20MB)")
        if len(image_bytes) < 100:
            raise HTTPException(status_code=400, detail="Image too small or empty")
        image_features = process_image(image_bytes)
        return {"embedding": image_features.squeeze(0).cpu().numpy().tolist()}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Embedding failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/embed_text")
async def embed_text(request: Request):
    """Return the raw 512-dim CLIP embedding for a text string."""
    try:
        body = await request.json()
        text = body.get("text", "")
        if not text:
            raise HTTPException(status_code=400, detail="Missing 'text' field")
        features = encode_text_prompts([text])
        return {"embedding": features.squeeze(0).cpu().numpy().tolist()}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Text embedding failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/caption")
async def caption(file: UploadFile = File(...)):
    """Generate a text caption for an image using BLIP."""
    try:
        image_bytes = await file.read()
        if len(image_bytes) > 20 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Image too large (max 20MB)")
        if len(image_bytes) < 100:
            raise HTTPException(status_code=400, detail="Image too small or empty")
        cap = caption_image(image_bytes)
        tags = extract_keywords(cap, max_keywords=5)
        return {"caption": cap, "tags": tags}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Captioning failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/extract_keywords")
async def extract_keywords_endpoint(request: Request):
    """Extract keywords from text using YAKE."""
    try:
        body = await request.json()
        text = body.get("text", "")
        if not text or len(text.strip()) < 5:
            raise HTTPException(status_code=400, detail="Text too short")
        max_kw = body.get("max_keywords", 5)
        keywords = extract_keywords(text, max_keywords=max_kw)
        return {"keywords": keywords, "description": ", ".join(keywords)}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Keyword extraction failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/moderate")
async def moderate(request: Request):
    """Score text for toxicity (roberta multi-label) and AI detection (CLIP)."""
    try:
        body = await request.json()
        text = body.get("text", "")
        if not text or len(text.strip()) < 3:
            return {
                "toxicity": 0.0, "severe_toxicity": 0.0, "obscene": 0.0,
                "threat": 0.0, "insult": 0.0, "identity_attack": 0.0,
                "sexual_explicit": 0.0, "ai_score": 0.0, "flagged": False,
            }
        scores = compute_toxicity(text[:512])
        ai = compute_ai_score(text[:500])
        tox = scores.get("toxicity", 0.0)
        return {
            "toxicity": tox,
            "severe_toxicity": scores.get("severe_toxicity", 0.0),
            "obscene": scores.get("obscene", 0.0),
            "threat": scores.get("threat", 0.0),
            "insult": scores.get("insult", 0.0),
            "identity_attack": scores.get("identity_attack", 0.0),
            "sexual_explicit": scores.get("sexual_explicit", 0.0),
            "ai_score": ai,
            "flagged": tox > 0.6 or ai > 0.7,
        }
    except Exception as e:
        logger.exception("Moderation failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/moderate_context")
async def moderate_context(request: Request):
    """Score text for toxicity both solo and in conversational context."""
    try:
        body = await request.json()
        text = body.get("text", "")
        context = body.get("context", "")

        empty_scores = {
            "toxicity": 0.0, "severe_toxicity": 0.0, "obscene": 0.0,
            "threat": 0.0, "insult": 0.0, "identity_attack": 0.0,
            "sexual_explicit": 0.0,
        }

        core_keys = set(empty_scores.keys())

        raw_solo = compute_toxicity(text[:512]) if text and len(text.strip()) >= 3 else {}
        raw_ctx = compute_toxicity(context[:512]) if context and len(context.strip()) >= 3 else {}
        ai = compute_ai_score(text[:500]) if text and len(text.strip()) >= 3 else 0.0

        solo_scores = {k: v for k, v in raw_solo.items() if k in core_keys}
        ctx_scores = {k: v for k, v in raw_ctx.items() if k in core_keys}

        delta = {}
        for k in core_keys:
            if k in solo_scores and k in ctx_scores:
                delta[k] = round(ctx_scores[k] - solo_scores[k], 4)

        solo_out = {**empty_scores, **solo_scores, "ai_score": ai}
        ctx_out = {**empty_scores, **ctx_scores}

        return {
            "solo": solo_out,
            "context": ctx_out,
            "delta": delta,
            "max_context_score": round(max(ctx_out.values()), 4) if ctx_out else 0.0,
            "max_delta": round(max(delta.values()), 4) if delta else 0.0,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Context moderation failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/moderate_image")
async def moderate_image(file: UploadFile = File(...)):
    """Full moderation scan for an image: NSFW + caption + keywords."""
    try:
        image_bytes = await file.read()
        if len(image_bytes) < 100:
            raise HTTPException(status_code=400, detail="Image too small")
        image_features = process_image(image_bytes)
        nsfw_score = compute_nsfw_score(image_features)
        caption = caption_image(image_bytes)
        tags = extract_keywords(caption, max_keywords=10)
        return {
            "nsfw": nsfw_score,
            "flagged": nsfw_score > 0.6,
            "caption": caption,
            "tags": tags,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Image moderation failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "device": device,
        "models": {
            "clip": "ViT-B-32::openai",
            "blip": "Salesforce/blip-image-captioning-base",
            "toxicity": "unitary/unbiased-toxic-roberta",
        },
        "embedding_dim": 512,
    }
