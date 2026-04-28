# ZenMux Skills

The official skill repository for [ZenMux](https://zenmux.ai) .

## Installation

```bash
npx skills add ZenMux/skills
```

Install a single skill:

```bash
npx skills add https://github.com/zenmux/skills --skill zenmux-context
npx skills add https://github.com/zenmux/skills --skill zenmux-setup
npx skills add https://github.com/zenmux/skills --skill zenmux-usage
npx skills add https://github.com/zenmux/skills --skill zenmux-feedback
npx skills add https://github.com/zenmux/skills --skill zenmux-statusline
npx skills add https://github.com/zenmux/skills --skill zenmux-image-generation
```

## Available Skills

| Skill | Description |
|-------|-------------|
| **zenmux-context** | ZenMux documentation expert. Answers questions about product features, API usage, integration, configuration, and best practices by pulling the latest official docs and providing cited responses. Supports both English and Chinese. |
| **zenmux-setup** | Interactive onboarding guide. Walks users through configuring ZenMux with their tool or SDK step by step. |
| **zenmux-usage** | Query real-time ZenMux account data via the Management API: subscription detail, quota usage (5h/7d/monthly), account status, Flow rate, PAYG balance, per-generation cost/token breakdown, and platform statistics (timeseries trends, model leaderboards, provider market share). |
| **zenmux-feedback** | Submit GitHub issues, feature requests, bug reports, product suggestions, and feedback to ZenMux. Gathers info conversationally and submits via `gh` CLI. |
| **zenmux-statusline** | Install a Claude Code status line that displays real-time ZenMux account info (subscription tier, 5h/7d quota usage, PAYG wallet balance, API key type) alongside session metrics (model, context usage, prompt cache hits). |
| **zenmux-image-generation** | Generate images via ZenMux's image models (`openai/gpt-image-2`, Google Nano Banana Pro, Qwen Image, Doubao Seedream, ERNIE Image, GLM Image, Hunyuan Image, Kling, etc.). Picks an appropriate model, optimizes the prompt against that model's strengths (GPT Image 2 vs. Nano Banana guides), supports multi-image references via local paths or URLs (`[Image #N]` convention), saves the optimized prompt for review, and produces 4 variants by default. |

## zenmux-statusline

A two-line status bar displayed at the bottom of Claude Code, combining session metrics with ZenMux account data.

```
[claude-opus-4-7[1m]] 📁 skills | 🌿 main* | ████░░░░░░ 42% ctx | 💾 r72.0k w5.0k
⚡ ZenMux Ultra | 🔑 Sub sk-ss-...6e6 | 5h █░░░░ 19% · 7d █░░░░ 24% | 💳 Bal $492.74
```

### Line 1 — Session Info

| Segment | Example | Description |
|---------|---------|-------------|
| **Model** | `[claude-opus-4-7[1m]]` | Model slug (`.model.id` from Claude Code) |
| **Directory** | `📁 skills` | Current working directory name |
| **Git** | `🌿 main*` | Branch name, `*` indicates uncommitted changes |
| **Context** | `████░░░░░░ 42% ctx` | Context window used percentage with progress bar. Green <70%, yellow 70-89%, red 90%+ |
| **Cache** | `💾 r72.0k w5.0k` | Last API call's prompt cache: `r` = cache read (reused tokens), `w` = cache creation (newly cached tokens). Auto-scaled (`856`, `15.2k`, `1.5M`). Hidden before the first API call |

### Line 2 — ZenMux Account

| Segment | Example | Description |
|---------|---------|-------------|
| **Plan** | `⚡ ZenMux Ultra` | Subscription tier. Shows `⚠` suffix when account status is not healthy |
| **API Key** | `🔑 Sub sk-ss-...6e6` | Key type (`Sub` for `sk-ss-v1-*` subscription, `PAYG` for `sk-ai-v1-*`) + masked key (type prefix + last 3 chars). Hidden when `ZENMUX_API_KEY` is not set |
| **Quota 5h** | `5h █░░░░ 19%` | 5-hour rolling window quota usage with mini-bar. Green <70%, yellow 70-89%, red 90%+. Shows `⏳ Xh Ym` countdown to reset when 100% used |
| **Quota 7d** | `7d █░░░░ 24%` | 7-day rolling window quota usage, same color and reset-countdown behavior |
| **PAYG Balance** | `💳 Bal $492.74` | Available wallet balance (top-up + bonus credits). Hidden when no PAYG credits exist |

### Fallback Behavior

| Condition | Behavior |
|-----------|----------|
| `ZENMUX_MANAGEMENT_KEY` not set | Line 2 shows setup hint: `⚙ Set ZENMUX_MANAGEMENT_KEY to display account data → zenmux.ai/platform/management` |
| `ZENMUX_API_KEY` not set | API Key segment hidden, rest of Line 2 shown normally |
| API call fails | Uses stale cache if available, otherwise Line 2 hidden |

### Refresh Cycle

| Data | Interval | Source |
|------|----------|--------|
| Session (model, context, cache) | Real-time | Piped from Claude Code after each assistant message |
| Git branch | 5 seconds | Cached per session |
| ZenMux account (plan, quota, PAYG) | 120 seconds | Cached globally, shared across sessions |

### Requirements

- `curl` and `jq` installed
- `ZENMUX_MANAGEMENT_KEY` env var for account data ([create one here](https://zenmux.ai/platform/management))

## Repository Structure

```
skills/                              # Skills directory
  zenmux-context/                    # ZenMux documentation skill
    SKILL.md                         # Skill definition
    scripts/
      update-references.sh           # Clone/update reference repos
      get-doc-tree.sh               # Documentation tree generator
    references/                      # External repo clones (git-ignored)
      references-list.txt            # Source repos list
  zenmux-setup/                      # ZenMux onboarding skill
    SKILL.md                         # Skill definition
  zenmux-usage/                      # ZenMux usage query skill
    SKILL.md                         # Skill definition
  zenmux-feedback/                   # ZenMux feedback & issue submission skill
    SKILL.md                         # Skill definition
    scripts/
      update-references.sh           # Clone/update reference repos
    references/                      # External repo clones (git-ignored)
      references-list.txt            # Source repos list
  zenmux-statusline/                 # Claude Code status line skill
    SKILL.md                         # Skill definition
    scripts/
      zenmux-statusline.sh           # Status line bash script
  zenmux-image-generation/           # ZenMux image generation skill
    SKILL.md                         # Skill definition
    scripts/
      refresh_references.sh          # Curl the two prompt cookbooks from upstream awesome repos (run at start of every invocation)
      list_models.sh                 # Filter ZenMux model list to image models
      generate.py                    # Unified generator (Gemini + OpenAI-family routing, ref-image support)
    references/                      # Curl'd prompt cookbooks + ZenMux API reference
      awesome-gpt-image-2.md           # YouMind-OpenLab/awesome-gpt-image-2 README (~2700 prompts)
      awesome-nano-banana-pro-prompts.md  # YouMind-OpenLab/awesome-nano-banana-pro-prompts README
      zenmux-image-api.md
    prompts/                         # User-confirmed optimized prompts (git-ignored)
    output/                          # Generated images (git-ignored)
```

## Links

- [ZenMux](https://zenmux.ai)
- [ZenMux Docs](https://docs.zenmux.ai)
- [ZenMux Docs Repository](https://github.com/ZenMux/zenmux-doc)
