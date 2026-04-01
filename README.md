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
```

## Available Skills

| Skill | Description |
|-------|-------------|
| **zenmux-context** | ZenMux documentation expert. Answers questions about product features, API usage, integration, configuration, and best practices by pulling the latest official docs and providing cited responses. Supports both English and Chinese. |
| **zenmux-setup** | Interactive onboarding guide. Walks users through configuring ZenMux with their tool or SDK step by step. |
| **zenmux-usage** | Query real-time ZenMux account data via the Management API: subscription detail, quota usage (5h/7d/monthly), account status, Flow rate, PAYG balance, and per-generation cost/token breakdown. |
| **zenmux-feedback** | Submit GitHub issues, feature requests, bug reports, product suggestions, and feedback to ZenMux. Gathers info conversationally and submits via `gh` CLI. |

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
```

## Links

- [ZenMux](https://zenmux.ai)
- [ZenMux Docs](https://docs.zenmux.ai)
- [ZenMux Docs Repository](https://github.com/ZenMux/zenmux-doc)
