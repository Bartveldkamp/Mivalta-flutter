#!/usr/bin/env python3
"""Adversarial code review via Claude API — defensive edition.

Reads `.claude/REVIEWER.md` from the repo as the reviewer's system prompt,
reads the PR diff from stdin, and prints a BLOCKERS / WARNINGS / QUESTIONS / PASS
report to stdout. Designed to be invoked from `.github/workflows/claude-review.yml`.

Fail-loud failure handling: if the Anthropic API call fails for any reason
(model name unavailable, rate limit, network, content filter, etc.) we still
emit a structured comment so the workflow doesn't post nothing silently.
The comment includes the actual error string so the founder can diagnose.

Model selection: tries a list in order. The system prompt at the start of
the Claude Code session said `claude-opus-4-7` is the latest, but the public
Anthropic API may not have that exact alias yet. Falls back to the previous
generation if needed.

Loyalty: the system prompt is the contract. This script is dumb plumbing.
"""
from __future__ import annotations

import os
import sys
import traceback
from pathlib import Path

import anthropic

REVIEWER_PATH = Path(".claude/REVIEWER.md")
MAX_OUTPUT_TOKENS = 4096

# Model fallback chain — try the latest first, fall back if 404.
MODEL_CANDIDATES = [
    "claude-opus-4-7",
    "claude-opus-4-5",
    "claude-sonnet-4-6",
    "claude-sonnet-4-5",
]


def emit_structured(blockers: str = "", warnings: str = "", questions: str = "", pass_section: str = "") -> str:
    """Return a markdown comment body in the standard 4-section format."""
    return (
        f"## BLOCKERS\n\n{blockers or '*(none)*'}\n\n"
        f"## WARNINGS\n\n{warnings or '*(none)*'}\n\n"
        f"## QUESTIONS\n\n{questions or '*(none)*'}\n\n"
        f"## PASS\n\n{pass_section or '*(none)*'}\n"
    )


def call_with_fallback(client, reviewer_prompt: str, diff: str):
    """Try each model in MODEL_CANDIDATES until one succeeds. Raise the last
    error if all fail."""
    last_error: Exception | None = None
    for model in MODEL_CANDIDATES:
        try:
            response = client.messages.create(
                model=model,
                max_tokens=MAX_OUTPUT_TOKENS,
                system=[
                    {
                        "type": "text",
                        "text": reviewer_prompt,
                        "cache_control": {"type": "ephemeral"},
                    }
                ],
                messages=[
                    {
                        "role": "user",
                        "content": (
                            "Here is the `git diff main..HEAD` for the PR under review. "
                            "Follow your system prompt exactly — output BLOCKERS / WARNINGS / "
                            "QUESTIONS / PASS sections, nothing else. Cite file:line for every finding.\n\n"
                            "```diff\n"
                            f"{diff}\n"
                            "```\n"
                        ),
                    }
                ],
            )
            return response, model
        except anthropic.NotFoundError as e:
            # Model name not available — try the next candidate.
            last_error = e
            sys.stderr.write(f"::warning::model '{model}' not found, trying next\n")
            continue
        except Exception as e:
            # Other errors (rate limit, content, etc.) — don't try alternatives,
            # surface this directly so the founder can see what's wrong.
            raise
    raise last_error if last_error else RuntimeError("no model candidates succeeded")


def main() -> None:
    if not REVIEWER_PATH.exists():
        sys.stdout.write(
            "## \U0001f916 Adversarial Code Review (configuration error)\n\n"
            + emit_structured(
                blockers=(
                    "- `.claude/REVIEWER.md` missing from repo root. Adversarial review "
                    "infrastructure is not deployed. Cannot proceed."
                )
            )
        )
        sys.exit(0)

    reviewer_prompt = REVIEWER_PATH.read_text()
    diff = sys.stdin.read()

    if not diff.strip():
        sys.stdout.write(
            "## \U0001f916 Adversarial Code Review (no diff to review)\n\n"
            + emit_structured(pass_section="- Empty diff.")
        )
        sys.exit(0)

    # Sanity-check the API key exists before calling.
    if not os.getenv("ANTHROPIC_API_KEY"):
        sys.stdout.write(
            "## \U0001f916 Adversarial Code Review (configuration error)\n\n"
            + emit_structured(
                blockers=(
                    "- `ANTHROPIC_API_KEY` env var not set in the workflow context. "
                    "Check repo secrets and workflow `env:` block."
                )
            )
        )
        sys.exit(0)

    try:
        client = anthropic.Anthropic()
        response, model_used = call_with_fallback(client, reviewer_prompt, diff)

        body = response.content[0].text
        usage = response.usage
        header = (
            f"## \U0001f916 Adversarial Code Review ({model_used})\n\n"
            "Automated review against `.claude/REVIEWER.md` and the CLAUDE.md "
            "invariants. The reviewer did not write this code; its only loyalty "
            "is to the contract.\n\n"
            "---\n\n"
        )
        footer = (
            f"\n\n---\n\n"
            f"*Model: `{model_used}` · input tokens: {usage.input_tokens} "
            f"(cached: {getattr(usage, 'cache_read_input_tokens', 0)}) · "
            f"output tokens: {usage.output_tokens}. "
            f"Findings here are advisory; founder reviews on GitHub.*\n"
        )
        sys.stdout.write(header + body + footer)
    except Exception as e:
        # Any API failure: emit a structured comment with the error so the
        # founder can see what's wrong, instead of silently failing.
        tb = traceback.format_exc()
        sys.stderr.write(f"::error::adversarial review API call failed\n{tb}\n")
        sys.stdout.write(
            "## \U0001f916 Adversarial Code Review (API error)\n\n"
            + emit_structured(
                blockers=(
                    f"- Anthropic API call failed: `{type(e).__name__}: {e}`\n"
                    f"- Tried models in order: {', '.join(MODEL_CANDIDATES)}\n"
                    f"- This is an infrastructure failure, not a code review verdict. "
                    f"PR has NOT been reviewed. Check workflow logs for full traceback."
                )
            )
        )


if __name__ == "__main__":
    main()
