# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the ZenMux skills repository — a collection of Claude Code skills for working with ZenMux, an LLM API aggregation service. Skills here help Claude answer questions about ZenMux by reading its official documentation.

## Architecture

```
skills/                      # Claude skills (each skill = a directory)
  zenmux-context/            # Documentation expert skill
    SKILL.md                 # Skill definition (YAML frontmatter + workflow)
    scripts/                 # Skill-specific scripts
      update-references.sh   # Clones/pulls repos listed in references-list.txt
      get-doc-tree.sh        # Generates documentation tree (titles + paths)

.context/references/         # Git-ignored local clones of external repos
  references-list.txt        # One GitHub URL per line (source of truth)
  zenmux-doc/                # Cloned ZenMux documentation (bilingual: en/ + zh/)
```

**Reference management pattern:** External repos are listed in `.context/references/references-list.txt` and cloned locally by `skills/zenmux-context/scripts/update-references.sh`. The cloned repos are git-ignored — they are runtime dependencies, not committed content.

## Key Commands

```bash
# Pull/update all reference repositories
bash skills/zenmux-context/scripts/update-references.sh

# Generate the ZenMux documentation tree (titles + paths)
bash skills/zenmux-context/scripts/get-doc-tree.sh
```

## Skill Format

Each skill lives in `skills/<skill-name>/` with a required `SKILL.md`:

```yaml
---
name: skill-name
description: >-
  Trigger conditions — be "pushy" to avoid under-triggering.
  Include both English and Chinese keywords where relevant.
---

# skill-name

Step-by-step workflow instructions for Claude...
```

Skills can include a `scripts/` subdirectory for bash helpers. The SKILL.md body should stay under 500 lines; use `references/` for larger supporting documents.

## ZenMux Documentation Structure

The documentation at `.context/references/zenmux-doc/docs_source/` is bilingual:
- `en/` — English docs
- `zh/` — Chinese docs (source-of-truth, translated to English)

Major sections: `about/`, `guide/` (with `advanced/`, `observability/`, `studio/`), `api/` (OpenAI, Anthropic, VertexAI, Platform), `best-practices/` (17 tool integrations), `help/`.

Online docs: https://docs.zenmux.ai (English at root, Chinese under `/zh/`).

## Adding a New Skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter (`name`, `description`)
2. Add any helper scripts in `skills/<skill-name>/scripts/` (make them executable)
3. If the skill needs external repos, add URLs to `.context/references/references-list.txt`
