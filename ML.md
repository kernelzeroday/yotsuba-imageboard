# ML Pipeline — Yotsuba Imageboard

## What This Is

This is the first imageboard with a real-time ML pipeline integrated into the posting flow. Every image uploaded gets a CLIP embedding, a BLIP caption, visual vocabulary classification, NSFW scoring, anime detection, and toxicity analysis. Every text post gets keyword extraction, toxicity scoring, AI detection, and context-aware moderation. All of this happens at post time, not as a batch job.

No public imageboard — Futaba, vichan, lynxchan, jschan, or any 4chan fork — has done this. Images on traditional imageboards are opaque blobs: upload, thumbnail, serve. The software has no idea what's in them. Here, the board understands its own content.

## Architecture

```
                    ┌─────────────────────┐
                    │   Apache + PHP 8.2  │
                    │   (imgboard.php)    │
                    └────────┬────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
     ┌────────────┐  ┌────────────┐  ┌──────────┐
     │  CLIP/BLIP │  │ PostgreSQL │  │ Memcached │
     │  FastAPI   │  │  + pgvector│  │          │
     │  (CPU)     │  │            │  │          │
     └────────────┘  └────────────┘  └──────────┘
```

The CLIP server (`docker/clip/server.py`, 670 lines) runs as a sidecar container. It loads four models at startup:

| Model | Purpose | Size |
|-------|---------|------|
| **CLIP ViT-B-32** (OpenAI) | Image/text embeddings, zero-shot classification | 354M params |
| **BLIP-base** (Salesforce) | Image captioning | 224M params |
| **unbiased-toxic-roberta** (Unitary) | Text toxicity (6 dimensions) | 125M params |
| **YAKE** | Statistical keyword extraction | No model (algorithmic) |

All inference runs on CPU. A single image analysis takes ~1-2 seconds. The server exposes 10 endpoints.

## What Happens When You Post

### Image Post

1. **CLIP embedding** — Image encoded to a 512-dimensional vector via ViT-B-32. Stored in `clip_vector` (pgvector column with HNSW index).

2. **NSFW scoring** — Image embedding compared against 7 unsafe prompts ("nudity", "pornography", etc.) and 10 safe prompts ("landscape", "text or screenshot", etc.) via cosine similarity. Score is the ratio: `max(unsafe) / (max(unsafe) + max(safe))`. Stored in `clip_nsfw`.

3. **Anime detection** — Same technique with 8 anime prompts and 8 non-anime prompts. Stored in `clip_anime`.

4. **Visual vocabulary probing** — Image scored against 148 curated concept prompts organized into 14 categories (subjects, settings, vehicles, objects, weapons, architecture, art styles, colors, actions, themes, content types, anime/manga). Uses adaptive thresholding: `max(0.25, mean + 1.5σ)` to avoid flooding with false positives on complex images. Produces 5-20 tags per image.

5. **BLIP captioning** — Image captioned by BLIP-base with beam search (num_beams=3, max_tokens=100). Caption like "a girl with long hair and glasses is looking at the camera".

6. **YAKE keyword extraction** — Caption processed by YAKE (n=2, dedupLim=0.5, top=15) to extract keywords. Produces 3-10 tags from the caption.

7. **Tag merging** — BLIP-YAKE tags and visual vocabulary tags are deduplicated and merged. BLIP tags get score 1.0; visual tags keep their cosine similarity score. Combined description stored in `clip_desc` (VARCHAR 500).

8. **Image + thumbnail stored** — Raw image bytes stored in `image_data` (BYTEA), thumbnail in `thumb_data`. This enables re-analysis without filesystem access.

### Text Post

1. **Toxicity scoring** — Text scored by toxic-roberta across 6 dimensions: toxicity, severe_toxicity, obscene, threat, insult, identity_attack, sexual_explicit. Each stored as a separate float column.

2. **AI detection** — Text embedded via CLIP and compared against 6 "AI-generated" prompts and 6 "human-written" prompts. Score stored in `clip_ai_score`.

3. **Keyword extraction** — Text processed by YAKE to extract up to 10 keywords. Stored in `clip_text_desc`.

4. **Text embedding** — Text encoded to 512-dim CLIP vector. Stored in `clip_vector` for semantic search.

### Reply (Context-Aware Moderation)

When a reply is posted, the system builds a context window:

```
[OP]: <first 200 chars of thread OP>
[>>123]: <first 150 chars of quoted post>
[Reply]: <first 150 chars of the reply>
```

This concatenated context is scored for toxicity alongside the reply text alone. The delta reveals when context shifts meaning — a reply that scores 0.02 toxicity alone but 0.85 in context is flagged. The context toxicity is stored in `clip_context_toxicity`.

## Moderation System

### Two-Tier Thresholds

Each toxicity dimension has two thresholds configured in the INI cascade:

- **Review threshold** (`ML_*_REVIEW`): Post is published but flagged for staff review. Stored in `moderation_flag` / `moderation_reason`.
- **Block threshold** (`ML_*_BLOCK`): Post is rejected with an error message citing the specific rule.

### Per-Board Rules via INI Cascade

The config cascade (`global → category → board`) maps ML scores to board rules:

| Board | Policy | Key Overrides |
|-------|--------|---------------|
| Global default | Moderate everything | All thresholds active |
| Worksafe category | Strict NSFW/sexual | nsfw_review=0.55, context_mode=2 (blocking) |
| NSFW category | Relax sexual/obscene/nsfw | nsfw/sexual/obscene disabled (1.0) |
| `/b/` | "ZOMG NONE!!!1" | Only threats + severe toxicity enforced |
| `/pol/` | Free speech, no porn | toxicity/insult/identity disabled, nsfw strict |
| `/g/` | Anti-trolling (g3 rule) | Lower insult threshold (0.60 review) |
| `/trash/` | Minimal rules | Most thresholds disabled, context advisory |

Staff with `has_level()` bypass all ML blocks.

### What Works Well

- **NSFW detection** is reliable. CLIP zero-shot with the unsafe/safe prompt pairs produces clean separation. Worksafe boards correctly block NSFW uploads.
- **Visual vocabulary tags** are the biggest win. "anime girl", "sword", "sunset", "pixel art" — these are navigational tags that were never typed by any human but are searchable on the tagboard.
- **Vector similarity search** via pgvector. The tagboard shows "Semantically Related Posts" by computing the average CLIP vector of all posts matching a tag, then finding the nearest unmatched posts. This discovers content that's visually similar but differently tagged.
- **Context-aware moderation** catches replies that are only toxic in context. The delta between solo and contextual scores is a meaningful signal.

### What Doesn't Work Well

- **BLIP-base captions are generic**. "a girl with long hair" for complex anime art. The model was trained on natural photos, not illustrations. Produces 3-5 YAKE keywords from a 10-15 word caption. The visual vocabulary probing compensates but doesn't replace good captioning.
- **Text keyword tags are noisy**. YAKE extracts keywords like "post", "real", "Yotsuba engine" from discussion text. These pollute the tag cloud. Needs stopword filtering or separation from image tags.
- **Some visual vocab prompts fire too broadly**. "singing" tagged 70 of 554 images. The adaptive threshold helps but doesn't eliminate all false positives. The vocabulary needs ongoing tuning.
- **AI detection is weak**. CLIP text similarity between "AI-generated text" and "human text" prompts doesn't separate well. Most posts score 0.49-0.52 regardless of origin. A dedicated classifier would be needed for real AI detection.
- **Anime scores cluster around 0.50**. Most images score 0.49-0.55 for anime detection. The prompts don't create enough separation to reliably distinguish anime from non-anime art. Works as a rough signal, not a binary classifier.

## Database Schema (ML Columns)

```sql
-- Scores (all REAL NOT NULL DEFAULT 0)
clip_nsfw              -- NSFW probability (0-1)
clip_anime             -- Anime style probability (0-1)
clip_toxicity          -- Overall toxicity
clip_ai_score          -- AI-generated text probability
clip_severe_toxicity   -- Severe toxicity
clip_obscene           -- Obscene content
clip_threat            -- Threatening language
clip_insult            -- Insulting content
clip_identity_attack   -- Identity-based attacks
clip_sexual_explicit   -- Sexually explicit text
clip_context_toxicity  -- Contextual toxicity (replies only)

-- Moderation
moderation_flag        -- SMALLINT: 0=clean, 1=review, 2=blocked
moderation_reason      -- VARCHAR(200): human-readable reason

-- Content
clip_caption           -- TEXT: BLIP natural language caption
clip_desc              -- VARCHAR(500): comma-separated image tags (BLIP + visual vocab)
clip_text_desc         -- VARCHAR(500): comma-separated text keywords (YAKE)
clip_vector            -- vector(512): CLIP embedding (pgvector, HNSW indexed)

-- Binary storage
image_data             -- BYTEA: original image bytes
thumb_data             -- BYTEA: thumbnail bytes
```

## CLIP Server Endpoints

| Endpoint | Method | Input | Output |
|----------|--------|-------|--------|
| `/analyze` | POST (multipart) | Image file | nsfw, anime, tags, caption, visual_tags, description |
| `/predict` | POST (raw binary) | Image bytes | Same as /analyze (legacy) |
| `/embed` | POST (multipart) | Image file | 512-dim float array |
| `/embed_text` | POST (JSON) | `{text}` | 512-dim float array |
| `/caption` | POST (multipart) | Image file | caption, tags |
| `/extract_keywords` | POST (JSON) | `{text, max_keywords}` | keywords, description |
| `/moderate` | POST (JSON) | `{text}` | 7 toxicity scores + ai_score + flagged |
| `/moderate_context` | POST (JSON) | `{text, context}` | solo scores, context scores, delta |
| `/moderate_image` | POST (multipart) | Image file | nsfw, flagged, caption, tags |
| `/health` | GET | — | status, device, models, embedding_dim |

## Visual Vocabulary Categories

148 concept prompts across 14 categories:

- **People & Characters** (9): person, woman, man, girl, boy, baby, group, couple, elderly
- **Anime/Manga** (8): anime girl, anime boy, mecha, chibi, magical girl, monster, animal ears, android
- **Animals** (7): cat, dog, bird, fish, horse, insect, reptile
- **Settings** (20): outdoors, indoors, beach, forest, mountain, city, park, space, underwater, desert, snow, sunset, night, school, kitchen, office, bathroom, library, hospital, stage
- **Vehicles** (8): car, motorcycle, bicycle, train, airplane, boat, tank, spacecraft
- **Objects** (16): food, drink, computer, phone, gaming, book, flowers, instrument, camera, fashion, hat, glasses, jewelry, mask, plush, figurine
- **Weapons** (4): gun, sword, bow, military
- **Architecture** (8): building, house, shrine, castle, bridge, tower, ruins, torii
- **Art Style** (22): photograph, painting, sketch, watercolor, digital art, pixel art, 3d render, comic, abstract, surreal, minimalist, graffiti, calligraphy, meme, screenshot, infographic, diagram, logo, monochrome, vintage, vaporwave, art nouveau
- **Colors** (10): red, blue, green, yellow, pink, purple, colorful, dark, bright, pastel
- **Actions** (14): smiling, crying, angry, sleeping, eating, drinking, reading, sports, dancing, swimming, fighting, running, cooking, singing
- **Themes** (10): cute, horror, funny, romantic, melancholic, epic, peaceful, chaotic, mysterious, nostalgic
- **Content Types** (12): landscape, portrait, text, nature, sci-fi, fantasy, technology, cosplay, wallpaper, album art, propaganda, tattoo

## Tagboard

`tagboard.php` provides two views:

1. **Tag Index** (`/tags`) — Tag cloud weighted by frequency + sortable table of all tags. Combines both `clip_desc` (image tags) and `clip_text_desc` (text keywords).

2. **Tag Page** (`/tag/{slug}`) — Grid of all posts matching a tag (searched across both image and text tag columns). Below the results: "Semantically Related Posts" section that uses pgvector to find the 20 nearest posts by cosine distance to the average embedding of matched posts.

## Retag Script

`docker/retag.php` re-processes all posts through the ML pipeline in three phases:

1. **Phase 1**: All image posts → `/predict` → update clip_nsfw, clip_anime, clip_caption, clip_desc
2. **Phase 2**: All text posts → `/moderate` + `/extract_keywords` → update toxicity scores + clip_text_desc
3. **Phase 3**: All replies → `/moderate_context` → update clip_context_toxicity

Run with `--force` to reprocess posts that already have scores (default: skip scored posts).

## What This Makes Possible

Things no imageboard has done:

- **Visual search**: Find all posts containing swords, or cats, or pixel art — without anyone ever tagging them
- **Semantic similarity**: "Show me posts that look like this one" via CLIP vector nearest-neighbor
- **Automated NSFW enforcement**: Worksafe boards reject uploads that cross an NSFW threshold, no human review needed
- **Context-aware moderation**: Detect replies that are innocuous alone but predatory/toxic in context
- **Per-board rule enforcement**: Map ML scores to actual board rules (anti-troll, no-porn, free-speech) via config, not code
- **Content clustering**: Group all images on a board by visual style, find duplicates across boards without perceptual hashing
- **Tag discovery**: Surface what's actually in the images without manual booru-style tagging
- **Cross-modal search**: Text query → CLIP embedding → find matching images (not implemented in UI yet, but the embeddings exist)

## Dependencies

```
open-clip-torch          # CLIP ViT-B-32
transformers             # BLIP captioning
torch                    # PyTorch (CPU)
yake                     # Keyword extraction
fastapi + uvicorn        # HTTP server
Pillow                   # Image processing
numpy                    # Array ops
pgvector (PostgreSQL)    # Vector similarity search
```
