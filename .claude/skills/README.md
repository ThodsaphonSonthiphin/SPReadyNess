# Project skills

The `dev-workflows` skill set, mirrored from
[ThodsaphonSonthiphin/workflow-daily-work](https://github.com/ThodsaphonSonthiphin/workflow-daily-work)
(`plugins/dev-workflows/skills/`) so it's available to this repo in Claude
Code CLI, web, and mobile without a plugin marketplace install.

`.dev-workflows-shared/` holds the plugin-level `references/` and `scripts/`
that individual skills point to; every `${CLAUDE_PLUGIN_ROOT}/...` reference
in the skill files was rewritten to the relative path
`.claude/skills/.dev-workflows-shared/...`, which resolves as long as
commands run from the repo root.

To pick up upstream changes, re-run the source repo's
`plugins/dev-workflows/.antigravity/install-antigravity.py` logic against
this directory (stage each skill + `.dev-workflows-shared`, then rewrite
`${CLAUDE_PLUGIN_ROOT}` pointers to `.claude/skills/...`), or copy skills over
by hand and repeat the substitution.
