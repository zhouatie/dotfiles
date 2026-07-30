#!/usr/bin/env python3
"""Call Hermes to save pi-agent context into the user's Obsidian vault.

Usage:
  python3 hermes_obsidian_note.py [--title TITLE] [--dir OBSIDIAN_REL_DIR] < content.md
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from datetime import datetime

VAULT = "/Users/zhoushitie/My/Obsidian/AtieVault"
DEFAULT_DIR = "00 Inbox/pi-agent/"


def build_prompt(content: str, title: str | None, target_dir: str) -> str:
    now = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")
    title_hint = title.strip() if title else "请根据内容自动生成清晰标题"
    return f"""你是我的 Obsidian 笔记助手。请把 pi-agent 传来的内容整理成一篇 Markdown 笔记，并写入我的 Obsidian Vault。

Vault 绝对路径：
{VAULT}

写入目录（Vault 内相对路径）：
{target_dir}

标题建议：
{title_hint}

要求：
1. 文件名格式：YYYY-MM-DD HHmm - 标题.md。
2. 添加 YAML frontmatter：
   - source: pi-agent
   - created_at: {now}
   - tags: [pi-agent]
3. 保留原始信息，不要丢失用户给出的 prompt、文档内容、链接、代码块和待办。
4. 在保留原文的基础上，适当整理为标题、摘要、条目和待办。
5. 如果内容里有明确待办，使用 Obsidian checkbox：- [ ]。
6. 不要记录明显的 API key、token、Cookie、密码等秘密；如出现，请省略并标注“已省略敏感信息”。
7. 写入完成后返回最终文件路径；如果失败，明确说明失败原因。

pi-agent 传来的待记录内容如下：

<<<PI_AGENT_CONTENT
{content.rstrip()}
PI_AGENT_CONTENT
"""


def main() -> int:
    parser = argparse.ArgumentParser(description="Use Hermes to record pi-agent content into Obsidian.")
    parser.add_argument("--title", help="Optional title hint for the Obsidian note.")
    parser.add_argument("--dir", default=DEFAULT_DIR, help=f"Vault-relative target dir. Default: {DEFAULT_DIR}")
    parser.add_argument("--timeout", type=int, default=180, help="Seconds to wait for Hermes. Default: 180")
    parser.add_argument("--dry-run", action="store_true", help="Print the Hermes prompt without calling Hermes.")
    args = parser.parse_args()

    content = sys.stdin.read()
    if not content.strip():
        print("ERROR: stdin is empty. Pipe the prompt/document content into this script.", file=sys.stderr)
        return 2

    target_dir = args.dir.strip() or DEFAULT_DIR
    prompt = build_prompt(content, args.title, target_dir)

    if args.dry_run:
        print(prompt)
        return 0

    hermes = shutil.which("hermes")
    if not hermes:
        print("ERROR: hermes CLI not found in PATH.", file=sys.stderr)
        return 127

    cmd = [
        hermes,
        "chat",
        "-Q",
        "--source",
        "tool",
        "-s",
        "obsidian",
        "-t",
        "file,terminal,skills",
        "-q",
        prompt,
    ]

    try:
        result = subprocess.run(cmd, text=True, capture_output=True, timeout=args.timeout)
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout or ""
        stderr = exc.stderr or ""
        if stdout:
            print(stdout, end="")
        print(f"ERROR: hermes timed out after {args.timeout}s.", file=sys.stderr)
        if stderr:
            print(stderr, file=sys.stderr, end="")
        return 124

    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
