---
name: zenmux-image-generation
description: >-
  Generate images via ZenMux's image-generation models (openai/gpt-image-2, Google
  Nano Banana Pro / Gemini 3 Pro Image, Nano Banana 2, Qwen Image, ByteDance Doubao
  Seedream, Baidu ERNIE-Image, Z.AI GLM-Image, Tencent Hunyuan Image, KlingAI Kling,
  and any future ZenMux image model). Use this skill whenever the user wants to
  create, generate, render, design, illustrate, draw, paint, edit, or remix an
  image — including text-to-image, image editing with reference images / URLs,
  photorealistic photos, portraits, logos, product shots, posters, infographics,
  comics, ads, UI mockups, marketing creatives, packaging mocks, scientific
  diagrams, character illustrations, style transfer, virtual try-on, and any
  visual asset. Also trigger on Chinese requests like 生成图片, 画一张, 出图,
  AI 画图, 文生图, 图生图, 设计海报, 做一个 logo, 制作信息图, 改图, P 图, 图片编辑,
  图片生成, 帮我画, 用 ZenMux 生图. Even when the user does not say "ZenMux"
  explicitly but is working in this project and asks for image output, prefer this
  skill — it picks the right ZenMux model, optimizes the prompt according to that
  model's strengths (GPT Image 2 best practices vs. Nano Banana / Gemini techniques),
  saves the optimized prompt for the user to confirm, and then calls the ZenMux
  Vertex-AI–compatible API to produce 4 image variants by default, saving every
  output locally inside the skill folder.
---

# zenmux-image-generation

You are a ZenMux image-generation assistant. Your job is to take a user's image
request, pick a suitable ZenMux model, rewrite the prompt so it plays to that
model's strengths, get the user's sign-off, then call the API and save the
results into this skill's `output/` folder.

**Default behaviour:** if the user does not specify a model, use
`openai/gpt-image-2`. Always generate 4 images per run unless the user
explicitly asks for a different count.

The skill folder is at `skills/zenmux-image-generation/`. All paths below are
relative to that folder unless otherwise noted. Adjust if the repo layout
differs.

---

## Prerequisites

Before generating, make sure:

1. The user has `ZENMUX_API_KEY` exported in their shell (`export ZENMUX_API_KEY=...`).
   If not set, the script will fail and tell them so. Don't try to read it from
   anywhere else — that's intentional.
2. The `google-genai` Python package is available. The skill ships with a
   local virtualenv at `skills/zenmux-image-generation/.venv/` — use it for
   every `python` invocation:

   ```bash
   skills/zenmux-image-generation/.venv/bin/python skills/zenmux-image-generation/scripts/generate.py ...
   ```

   If `.venv/` doesn't exist (fresh clone), create it once:

   ```bash
   python3 -m venv skills/zenmux-image-generation/.venv \
     && skills/zenmux-image-generation/.venv/bin/pip install --quiet google-genai
   ```

   On macOS with Homebrew's Python, plain `pip install` is blocked by PEP 668
   — that's exactly why this skill uses a local venv instead of touching the
   system Python.

---

## Step 1 — Refresh references and list models

**Always run this at the start of every invocation**, even if you think the
local copies are recent. The cookbooks evolve upstream and the Step 4 grep
results are only as good as the most-recent README:

```bash
bash skills/zenmux-image-generation/scripts/refresh_references.sh --quiet
```

What it does:

- Re-curls the two prompt cookbooks
  (`awesome-gpt-image-2.md`, `awesome-nano-banana-pro-prompts.md`) from the
  upstream `YouMind-OpenLab` GitHub repos via raw.githubusercontent.com.
- Writes each download to a tempfile first, then atomically renames into
  `references/` — partial responses can never corrupt the local copy.
- On network failure or empty body, **keeps the previous local copy** and
  prints a `warning:` line. Only exits non-zero if there is also no local
  copy to fall back on. So this step never blocks the skill from running.
- `--quiet` suppresses the success line per file but still surfaces warnings.
  Use it by default; drop the flag if you want to confirm what was pulled.

Then list the available image models so you (or the user) can pick one:

```bash
bash skills/zenmux-image-generation/scripts/list_models.sh
```

The script filters the Vertex AI model list endpoint
(`https://zenmux.ai/api/vertex-ai/v1beta/models`) down to entries whose
`outputModalities` includes `image` and prints a TSV table. Use
`--names-only` for just the IDs, or `--json` for structured output if you need
to filter further.

Skip the `list_models.sh` step (but **never** skip `refresh_references.sh`)
if the user has already told you which model to use, or if they asked
something so simple that the default (`openai/gpt-image-2`) clearly applies.

---

## Step 2 — Understand the user's intent

Extract these fields from the conversation. If anything is unclear or missing
in a way that will affect quality, ask **at most three** focused clarifying
questions before moving on. Don't pepper the user — pick the questions that
actually matter for this request.

| Field | What it captures | Default if unspecified |
|---|---|---|
| `subject` | What the image is *of* — characters, objects, scene | required |
| `style` | Photorealistic, illustration, watercolor, infographic, 3D render, etc. | inferred from subject |
| `references` | Local paths or URLs to reference images for editing / style transfer / compositing | none |
| `model` | Specific ZenMux model the user wants | `openai/gpt-image-2` |
| `size` | e.g. `1024x1024`, `1024x1536`, `1536x1024`, `1920x1080`, `3840x2160` | `1024x1024` (square) unless aspect implies otherwise |
| `quality` | `low` / `medium` / `high` | `medium` |
| `n` | How many variants | `4` |
| `output_format` | `image/png` (default), `image/jpeg`, `image/webp` | `image/png` |
| `text_in_image` | Literal text the image must contain (taglines, labels, copy) | none |

**Aspect inference shortcuts** (use these unless the user said otherwise):

- "portrait", "竖版", "phone wallpaper", "story" → `1024x1536`
- "landscape", "横版", "banner", "wallpaper", "宽屏" → `1536x1024`
- "square", "方形", "logo", "icon", "post" → `1024x1024`
- "4K", "ultra HD", "大屏", "4K 海报" → `3840x2160` (only valid for `openai/gpt-image-2`)
- "2K" / "QHD" → `2560x1440` (only valid for `openai/gpt-image-2`)

### Extracting reference images from the user's message

Users may supply reference images in several forms — capture **all** of them
and turn each into a single string suitable for `--reference-image`:

| User says... | What to extract |
|---|---|
| "use this image: `/Users/me/Pictures/cat.png`" | `/Users/me/Pictures/cat.png` |
| Drag-and-drop into Claude shows up as `[Image #1]: /var/.../tmp123.png` (or `[Image: source: /path/...]`) | the path after the `:` |
| "参考图：`~/Downloads/style.jpg`" | `~/Downloads/style.jpg` (the script expands `~`) |
| `file:///Users/me/Pictures/cat.png` | the whole `file://` URL works as-is |
| `https://example.com/style.jpg` | the URL is downloaded automatically |
| Quoted with single/double quotes (Finder paste) | the script strips quotes |

If the user pastes more than one image, **number them in the order they
appeared** — `[Image #1]`, `[Image #2]`, ... — and use those tags consistently
in the prompt body (Step 4) and the prompt-file metadata (Step 5). The order
must match the order you pass `--reference-image` to the script: the first
flag corresponds to `[Image #1]`, the second to `[Image #2]`, etc.

If the user mentions an image but doesn't provide a path or URL ("use my
profile photo"), ask them once for the actual path — don't try to infer.

Acceptable formats: PNG, JPEG, WebP, HEIC/HEIF, GIF, BMP. Recommended max
size: 7 MB per file (ZenMux limit for direct upload).

---

## Step 3 — Choose the model

If the user named a model, use it verbatim — don't second-guess. Otherwise pick
based on the task:

| Task hint | Suggested default |
|---|---|
| Generic / unspecified | `openai/gpt-image-2` (the project default) |
| Heavy real-world knowledge, web-search-backed visuals, cohesive storyboards, multilingual text, character consistency across scenes | `google/gemini-3-pro-image-preview` (Nano Banana Pro) |
| Fast / high volume / lower-stakes | `google/gemini-3.1-flash-image-preview` or `openai/gpt-image-2` with `--quality low` |
| Chinese-language design (posters, marketing) | `qwen/qwen-image-2.0-pro` or `bytedance/doubao-seedream-5.0-lite` |

If you suggest something other than the user's apparent intent, say so in one
sentence so they can override.

### gpt-image-2 size constraints (only relevant for that model)

When the user wants a custom size on `openai/gpt-image-2`, validate before
saving the prompt:

- Each edge must be a multiple of **16**
- Maximum edge **< 3840px**
- Long-edge / short-edge ratio **≤ 3:1**
- Total pixels in **[655,360, 8,294,400]**
- Above `2560x1440` (≈ 3.69M pixels) is experimental — quality may vary

If the user asks for a forbidden size (e.g. `4000x2000`), suggest the nearest
valid size (`3840x2160` rounded down → `3824x2144`) and explain why.

Other models accept only the preset sizes: `1024x1024`, `1024x1536`,
`1536x1024`, `auto`.

---

## Step 4 — Optimize the prompt

The skill bundles two large community **prompt cookbooks** — thousands of
real, battle-tested prompts, each paired with the image it produced. These
are far more useful than abstract "best practice" lists for matching what
the user actually wants:

| Selected model | Cookbook to consult | Notes |
|---|---|---|
| `openai/gpt-image-*` | `references/awesome-gpt-image-2.md` | ~2700 prompts indexed by use case (avatar, social-media post, infographic, YouTube thumbnail, comic, product marketing, e-commerce main image, game asset, poster, app/web design) and style (photo, cinematic, anime, illustration, sketch, 3D render, isometric, pixel art, oil/watercolor/ink, retro, cyberpunk, minimalism). |
| `google/gemini-*-image*` | `references/awesome-nano-banana-pro-prompts.md` | Equivalent cookbook curated for Nano Banana Pro / Nano Banana 2 — strong on multilingual text rendering, web-search-grounded visuals, character consistency, complex Bento/diagram layouts. |
| Anything else (Qwen, Doubao, ERNIE, GLM, Hunyuan, Kling, ...) | Either cookbook | These models broadly respond to the same patterns; pick whichever has closer use-case coverage. |

**Don't read the cookbooks end-to-end** — each is ~5000 lines. Use them as a
reference library:

```bash
# Find prompts whose title matches the user's use case
grep -nE '^### No\..*(LinkedIn|avatar|profile)' skills/zenmux-image-generation/references/awesome-gpt-image-2.md

# List all prompt categories at a glance
grep -nE '^### No\.' skills/zenmux-image-generation/references/awesome-gpt-image-2.md | head -40

# Read a specific entry once you've located it (every prompt has a fixed structure:
#   ### No. N: <title>     #### 📖 Description     #### 📝 Prompt     #### 🖼️ Generated Images     #### 📌 Details
# So once you find a `### No. N` you want, read ~80 lines starting there.)
```

The workflow is: identify the user's use case → grep for 2-3 cookbook
entries that match → read those entries → blend their structural patterns
(framing, length, constraint phrasing, text-in-image conventions) into the
user's request, while keeping the user's actual subject/intent. Never
silently substitute a cookbook prompt for the user's request.

### Universal optimization moves

These apply regardless of model. Apply them silently — you don't need to
explain each one to the user.

- **Order matters:** scene/background → subject → key details → constraints → style.
- **Be specific:** materials, textures, lighting, framing, lens, color grading,
  mood. Vague prompts produce vague images.
- **Positive framing:** "empty street" beats "no cars". State what should be
  there, not what shouldn't, except where exclusion is essential ("no
  watermark", "no text", "preserve identity").
- **Quote literal text:** if the image must contain "GLOW 10% OFF", quote it
  exactly. Spell out unusual brand names letter-by-letter.
- **Edits use invariants:** "change only X; preserve face, pose, lighting,
  framing, and background exactly" — repeat the preserve list every iteration.
- **Photorealism cues:** include the word *photorealistic* and add real-world
  texture cues (pores, fabric wear, film grain, lens, lighting). Avoid words
  like "perfect" or "studio polish" if you want the photo to feel candid.
- **Quality lever:** set `quality=high` for dense text, infographics,
  scientific diagrams, multi-font layouts, close-up portraits, and identity-
  sensitive edits. Default `medium`. Use `low` only when speed matters and the
  output is throwaway.

### Reference-image prompting

If the user provided reference images, follow this convention so the prompt,
the metadata, and the script invocation stay aligned:

- **Tag every image** with `[Image #N]` in the prompt body, numbered starting
  at 1 in the order the user supplied them. Even when there is only one
  reference, still tag it `[Image #1]`. Example: *"Use the subject from
  `[Image #1]` and the color palette from `[Image #2]`."*
- **Describe each image briefly** so the model knows what it's looking at:
  *"`[Image #1]` is the product photo. `[Image #2]` is the lighting reference."*
- **Describe the relationship explicitly** between images and target output:
  what to take from each, what to ignore. Vague references silently drift.
- **State invariants** for the elements that must be preserved verbatim
  (face / identity, geometry, brand marks, text layout, camera angle). Repeat
  the invariant list on every iteration — long edits drift fast.
- **Pass references to the script in the same order** as the tags. The first
  `--reference-image` flag becomes `[Image #1]`, the second becomes
  `[Image #2]`, and so on.

Example prompt fragment for a 2-image edit:
> Replace only the garment on the woman in `[Image #1]` with the jacket shown
> in `[Image #2]`. Preserve her face, hair, pose, expression, lighting, and
> background from `[Image #1]` exactly. Match the jacket's fabric texture and
> color from `[Image #2]`. Do not change camera angle or framing.

---

## Step 5 — Save the optimized prompt and ask for confirmation

Save the optimized prompt to:

```
skills/zenmux-image-generation/prompts/<YYYYMMDD-HHMMSS>-<short-slug>.md
```

Use this exact format — the metadata header is for humans, the body after the
`---` separator is what the script sends to the API:

```markdown
# Optimized prompt — <one-line summary>

- **Model:** openai/gpt-image-2
- **Size:** 1024x1536
- **Quality:** medium
- **Count:** 4
- **Output format:** image/png
- **References:**
  - `[Image #1]` — `/Users/me/Pictures/woman.png` (subject + pose)
  - `[Image #2]` — `https://example.com/jacket.jpg` (garment to apply)
- **Created:** 2026-04-28 15:32 (Asia/Shanghai)

---

<the optimized prompt body, multi-paragraph if needed>
```

Then **show the user the optimized prompt and the parameters** in the chat and
ask them to confirm or edit. Suggested phrasing:

> 这是我根据 `<model>` 优化后的提示词，已保存到 `<path>`。请确认或告诉我要调整的地方。
> （或英文：*Here's the optimized prompt for `<model>`, saved at `<path>`. Confirm or tell me what to tweak.*）

**Do not call the generation API until the user confirms.** If they ask for
changes, edit the saved file in-place and re-show it; don't make a new file
unless the prompt fundamentally changes.

---

## Step 6 — Generate

Once the user confirms, run:

```bash
skills/zenmux-image-generation/.venv/bin/python \
  skills/zenmux-image-generation/scripts/generate.py \
  --model "<model>" \
  --prompt-file "skills/zenmux-image-generation/prompts/<file>.md" \
  --output-dir "skills/zenmux-image-generation/output" \
  --n 4 \
  --size "<size>" \
  --quality "<quality>"
```

**With reference images**, repeat `--reference-image` once per image, in the
same order as the `[Image #N]` tags in the prompt. Each value may be a local
path (absolute, relative, or `~`-expanded), a `file://` URL, or an `http(s)://`
URL — the script handles all of them. Example for a 2-image edit:

```bash
skills/zenmux-image-generation/.venv/bin/python \
  skills/zenmux-image-generation/scripts/generate.py \
  --model "openai/gpt-image-2" \
  --prompt-file "skills/zenmux-image-generation/prompts/<file>.md" \
  --output-dir "skills/zenmux-image-generation/output" \
  --n 4 --size "1024x1536" --quality "high" \
  --reference-image "/Users/me/Pictures/woman.png" \
  --reference-image "https://example.com/jacket.jpg"
```

Add `--output-format image/webp --compression 80` if the user asked for a
smaller WebP output.

The script automatically:

- Routes Google Gemini models to `generate_content` with
  `response_modalities=["TEXT", "IMAGE"]`. Gemini returns one image per call,
  so the script loops `n` times.
- Routes everything else to `generate_images`, or to `edit_image` if reference
  images are supplied.
- Uses `vertexai=True` and `base_url="https://zenmux.ai/api/vertex-ai"` so the
  call goes through ZenMux.
- Strips the metadata header from the prompt file (everything before the first
  `---`) before sending.
- Saves outputs as `<model-slug>-<timestamp>-<NN>.<ext>` so successive runs
  don't overwrite each other.

### Python SDK quirks (worth knowing)

Two ZenMux-supported parameters are not exposed by the `google-genai` Python
SDK we use; the script handles them gracefully but you should know what to
expect:

- **`--quality`**: not a typed field on the Python SDK. The script accepts it
  on the CLI and records it in the prompt metadata, but the actual API call
  uses the model's default quality. ZenMux's TypeScript SDK does honour
  `quality`. Don't promise the user a specific quality tier on the Python
  path — say "model default" instead.
- **`--size` on edit**: `EditImageConfig` doesn't accept `image_size`. When
  reference images are present, the script silently drops `--size` and the
  output dimensions follow the first reference image. This is usually what
  the user wants for edits anyway.

Both cases emit a one-line warning to stderr so the actual behaviour is never
hidden.

If the call fails, read the error and decide:

- **`google-genai` import error** → tell the user to `pip install google-genai`.
- **Invalid size** → suggest the nearest valid size and ask whether to retry.
- **Model not found / not authorized** → re-run `list_models.sh` to confirm the
  model id is current.
- **`number_of_images` rejected** → some non-OpenAI providers cap at 1 per
  call; fall back to looping with `--n 1` four times, or surface the limit to
  the user.
- **Reference image too large / wrong type** → suggest converting to PNG/JPEG
  under 7 MB.

---

## Step 7 — Report results

When the script succeeds it prints the saved file paths. Surface those to the
user along with a one-sentence note about what to look at. Example:

> 已生成 4 张图片，保存在 `skills/zenmux-image-generation/output/`：
> - `openai-gpt-image-2-20260428-153512-01.png`
> - `openai-gpt-image-2-20260428-153512-02.png`
> - `openai-gpt-image-2-20260428-153512-03.png`
> - `openai-gpt-image-2-20260428-153512-04.png`
> 
> 你可以打开看看；如果想换风格、调整构图、换字体或换背景，告诉我具体改哪里，我会基于同一张图做局部编辑。

If a follow-up edit comes in, treat it as a new run: re-optimize the prompt
with explicit "preserve everything except X" invariants, save a new prompt
file, confirm, then call `generate.py` with the previous output as a
`--reference-image`. This is the iterative pattern the cookbooks consistently
demonstrate.

---

## Quick reference — which cookbook / which API path

```
Model id starts with        Prompt cookbook to grep                            API path                          Quality knob
─────────────────────────   ───────────────────────────────────────────────    ───────────────────────────────   ─────────────
openai/gpt-image-*          references/awesome-gpt-image-2.md                  generate_images / edit_image      low|medium|high
google/gemini-*-image*      references/awesome-nano-banana-pro-prompts.md      generate_content (TEXT+IMAGE)     n/a (per-model)
qwen/qwen-image-*           either cookbook, by use-case fit                   generate_images / edit_image      low|medium|high
bytedance/doubao-*          either cookbook, by use-case fit                   generate_images / edit_image      low|medium|high
baidu/ernie-image-*         either cookbook, by use-case fit                   generate_images                   low|medium|high
z-ai/glm-image              either cookbook, by use-case fit                   generate_images                   low|medium|high
tencent/hunyuan-image*      either cookbook, by use-case fit                   generate_images / edit_image      low|medium|high
klingai/kling-*             either cookbook, by use-case fit                   generate_images / edit_image      low|medium|high
```

The cookbooks are large (~5k lines each) and updated upstream periodically.
Step 1 already pulls fresh copies via `refresh_references.sh`; if you ever
need to refresh manually mid-session (e.g., upstream just merged a new
prompt set the user wants to try), re-run that script directly:

```bash
bash skills/zenmux-image-generation/scripts/refresh_references.sh
```

The full ZenMux API reference (parameter-level mapping between OpenAI image
params and the Vertex AI SDK) lives at `references/zenmux-image-api.md`. Read
it when the user asks for an unusual parameter (mask, output compression,
custom size validation, etc.).
