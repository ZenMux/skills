# ZenMux Skills

The official skill repository for [ZenMux](https://zenmux.ai) .

## Installation

```bash
npx skills add ZenMux/skills
```

Install a single skill:

```bash
npx skills add ZenMux/skills/zenmux-context
```

## Available Skills

| Skill | Description |
|-------|-------------|
| **zenmux-context** | ZenMux documentation expert. Answers questions about product features, API usage, integration, configuration, and best practices by pulling the latest official docs and providing cited responses. Supports both English and Chinese. |

## Repository Structure

```
scripts/                         # Infrastructure scripts
  update-references.sh           # Clone/update external reference repos

skills/                          # Skills directory
  zenmux-context/                # ZenMux documentation skill
    SKILL.md                     # Skill definition
    scripts/get-doc-tree.sh      # Documentation tree generator

.context/references/             # Local reference docs (git ignored)
  references-list.txt            # External repository list
```

## Links

- [ZenMux](https://zenmux.ai)
- [ZenMux Docs](https://docs.zenmux.ai)
- [ZenMux Docs Repository](https://github.com/ZenMux/zenmux-doc)
