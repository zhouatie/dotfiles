# km-skills

Agent Skills for Knowledge Management (KM) system.

## Overview

km-skills is an Agent Skill for interacting with a Knowledge Management system. It follows a **four-layer pyramid architecture** (Metadata → Router → Reference → Execution), inspired by enterprise-grade skill design patterns.

## Project Structure

```
km-skills/
├── SKILL.md          # Entry point: metadata + intent routing + guardrails
├── references/       # Reference docs (cross-cutting + per-domain API)
│   ├── products/     # Per-domain API reference (documents, search, tags)
│   └── ...           # Auth, error codes, intent guide, field rules
├── scripts/          # Automation scripts + shared modules
│   ├── shared/       # Shared modules (HTTP client, auth, validators, output)
│   └── ...           # Domain-prefixed scripts: doc_, search_, tag_
├── tests/            # Tests for scripts
├── docs/             # Development guides and standards
├── templates/        # Script template
├── mixspec/          # MixSpec workflow directory
├── .codemaker/       # CodeMaker configuration
├── pyproject.toml    # Python project configuration
└── .gitignore        # Git ignore rules
```

## Quick Start

### Prerequisites

- Python >= 3.10
- pip

### Setup

```bash
# Install dependencies
pip install -e ".[dev]"
```

### Add a New Script

1. Copy the script template:
   ```bash
   cp templates/script_template.py scripts/{domain}_{action}.py
   ```
2. Follow the development guide: [docs/dev-guide.md](docs/dev-guide.md)

## Development Guide

See [docs/dev-guide.md](docs/dev-guide.md) for complete development standards, templates, and best practices.

## Tech Stack

- **Language**: Python 3.10+
- **HTTP Client**: requests (wrapped by `scripts/shared/client.py`)
- **Auth**: OAuth2
- **Linter/Formatter**: ruff
- **Testing**: pytest
- **Type Checking**: mypy
