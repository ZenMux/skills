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
```

## Available Skills

| Skill | Description |
|-------|-------------|
| **zenmux-context** | ZenMux documentation expert. Answers questions about product features, API usage, integration, configuration, and best practices by pulling the latest official docs and providing cited responses. Supports both English and Chinese. |
| **zenmux-setup** | Interactive onboarding guide. Walks users through configuring ZenMux with their tool or SDK step by step. |
| **zenmux-usage** | Query real-time ZenMux account data via the Management API: subscription detail, quota usage (5h/7d/monthly), account status, Flow rate, PAYG balance, and per-generation cost/token breakdown. |
| **zenmux-feedback** | Submit GitHub issues, feature requests, bug reports, product suggestions, and feedback to ZenMux. Gathers info conversationally and submits via `gh` CLI. |
| **zenmux-statusline** | Install a Claude Code status line that displays real-time ZenMux account info (subscription tier, 5h/7d quota usage, PAYG wallet balance, API key type) alongside session metrics (model, context usage, tokens, cache hits, lines changed, duration). |

## zenmux-statusline

A two-line status bar displayed at the bottom of Claude Code, combining session metrics with ZenMux account data.

```
[Opus 4.6] claude-opus-4-6 📁 skills | 🌿 main* | ████░░░░░░ 42% ctx | ↑152.3k ↓45.2k | 💾 r72.0k w5.0k | +156 -23 | ⏱ 2m15s ⚙45s
⚡ ZenMux Ultra | 🔑 Sub sk-ss-v1-5f8...6e6 | 5h ░░░░░ 5% · 7d ░░░░░ 1% | 💳 Bal $492.74
```

### Line 1 — Session Info

| Segment | Example | Description |
|---------|---------|-------------|
| **Model** | `[Opus 4.6] claude-opus-4-6` | Display name + model ID |
| **Directory** | `📁 skills` | Current working directory name |
| **Git** | `🌿 main*` | Branch name, `*` indicates uncommitted changes |
| **Context** | `████░░░░░░ 42% ctx` | Context window used percentage with progress bar. Green <70%, yellow 70-89%, red 90%+ |
| **Tokens** | `↑152.3k ↓45.2k` | Cumulative input/output tokens across the session (auto-scaled: `856`, `15.2k`, `1.5M`) |
| **Cache** | `💾 r72.0k w5.0k` | Last API call's prompt cache: `r` = cache read (reused tokens), `w` = cache creation (newly cached tokens). Hidden before the first API call |
| **Lines** | `+156 -23` | Total lines added (green) / removed (red) in this session |
| **Duration** | `⏱ 2m15s ⚙45s` | Total session wall-clock time (`⏱`) and time spent waiting for API responses (`⚙`) |

### Line 2 — ZenMux Account

| Segment | Example | Description |
|---------|---------|-------------|
| **Plan** | `⚡ ZenMux Ultra` | Subscription tier. Shows `⚠` suffix when account status is not healthy |
| **API Key** | `🔑 Sub sk-ss-v1-5f8...6e6` | Key type (`Sub` for `sk-ss-v1-*` subscription, `PAYG` for `sk-ai-v1-*`) + masked key (prefix + first 3 chars + last 3 chars). Hidden when `ZENMUX_API_KEY` is not set |
| **Quota 5h** | `5h ░░░░░ 5%` | 5-hour rolling window quota usage with mini-bar. Green <70%, yellow 70-89%, red 90%+ |
| **Quota 7d** | `7d ░░░░░ 1%` | 7-day rolling window quota usage, same color thresholds |
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
| Session (model, context, tokens, duration) | Real-time | Piped from Claude Code after each assistant message |
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
```

## Links

- [ZenMux](https://zenmux.ai)
- [ZenMux Docs](https://docs.zenmux.ai)
- [ZenMux Docs Repository](https://github.com/ZenMux/zenmux-doc)
