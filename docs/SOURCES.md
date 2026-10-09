# skill_community — sources & inventory

Standalone collection of permissive-licensed skills (MIT + Apache-2.0).
The `../sync.sh` script fetches from upstreams, then applies
`../patches/*.patch` (local customizations).

## Layout

```
skill_community/
  sync.sh            # re-sync script (run from here)
  skills/<name>/     # one dir per vendored skill: SKILL.md + LICENSE (+ README/references/scripts where upstream ships them)
  aliases/<alias>    # symlinks -> ../skills/<canonical> (short names: tdd, review-code, investigate, commit)
  patches/*.patch    # local customizations, paths like a/skills/<name>/SKILL.md
  docs/              # SOURCES.md (this file), ranking pointer, manual-install notes
```

## Aliases

`aliases/` holds symlinks to `skills/` so short invocation names keep
working: `tdd` → `test-driven-development`, `review-code` →
`code-review-and-quality`, `investigate` → `debugging-and-error-recovery`,
`commit` → `git-workflow-and-versioning`. The install hook resolves each
link and deploys a real dir under the alias name (content copy, not a
symlink — `rsync` does not follow a symlinked source dir). Patches also
terraform the canonical skills' frontmatter (`Also fires on \`/tdd\``) so
description routers match the short names too.

## Sources (see `../sync.sh`)

| # | Source | License | Mode |
|---|--------|---------|------|
| 1 | `addyosmani/agent-skills` `skills/<name>/` (`SKILL.md` + per-skill `references/`/`scripts/`) + repo-root `LICENSE` | MIT | vendored (all 25; 5 with local-adaptation patches, see below) |
| 1b | `albertdobmeyer/openskill-forge` `skills/log-analyzer/` (`SKILL.md` + root `LICENSE`; no standalone repo exists) | MIT | vendored as `skills/log-analyzer/` |
| 2 | `yuxiaopeng/Github-Ranking-AI` `Top100/AI Agents.md` | MIT (the list) | docs pointer only (`docs/RANKING-AI-Agents.md`); ranked repos have mixed licenses, nothing auto-vendored |
| 3 | `Shubhamsaboo/awesome-llm-apps` `agent_skills/<name>/` (`SKILL.md` + `references/` + `scripts/`) + repo-root `LICENSE` | Apache-2.0 | vendored (7 skills) |
| 4 | standalone skill repos (root skill or `skills/` family) | MIT except caveman | `bro` (`luchasarie/bro-skill`, root skill), `humanizer` (`blader/humanizer`, root skill), caveman family 22 skills (`JuliusBrussee/caveman` `skills/`, Apache-2.0 since 3.0.0 — see upstream `LICENSING.md`), ponytail family 6 skills (`DietrichGebert/ponytail` `skills/`) |

## Full inventory (63 skills)

- addyosmani/agent-skills, MIT (25): `api-and-interface-design`,
  `browser-testing-with-devtools`, `ci-cd-and-automation`,
  `code-review-and-quality` (+patch), `code-simplification`,
  `constraint-driven-development`, `context-engineering`,
  `debugging-and-error-recovery` (+patch), `deprecation-and-migration`,
  `documentation-and-adrs`, `doubt-driven-development`,
  `frontend-ui-engineering`, `git-workflow-and-versioning` (+patch),
  `idea-refine`, `incremental-implementation`, `interview-me`,
  `observability-and-instrumentation`, `performance-optimization`,
  `planning-and-task-breakdown`, `security-and-hardening`,
  `shipping-and-launch`, `source-driven-development`,
  `spec-driven-development`, `test-driven-development` (+patch),
  `using-agent-skills` (+patch).
- openskill-forge, MIT (1): `log-analyzer`.
- awesome-llm-apps, Apache-2.0 (7): `advisor-orchestrator-worker`,
  `commit-archaeologist`, `dependency-doctor`, `first-reader`,
  `project-graveyard`, `scope-creep-detector`, `thinking-out-loud`.
- bro-skill, MIT (1): `bro`. humanizer, MIT (1): `humanizer`.
- caveman, Apache-2.0 (22): `caveman`, `cavecrew`, `caveman-commit`,
  `caveman-compress`, `caveman-discover`, `caveman-evidence-review`,
  `caveman-explore`, `caveman-help`, `caveman-learn`, `caveman-manage`,
  `caveman-optimize`, `caveman-review`, `caveman-setup`, `caveman-stats`,
  `investigate-first`, `lean-build`, `megacave`, `migration`,
  `safe-refactor`, `surgical-patch`, `ultracave`, `verify-and-stop`.
- ponytail, MIT (6): `ponytail`, `ponytail-audit`, `ponytail-debt`,
  `ponytail-gain`, `ponytail-help`, `ponytail-review`.
- aliases (4, symlinks, no extra source): `tdd`, `review-code`,
  `investigate`, `commit`.

## Why this allowlist

- All 25 upstream MIT skills are vendored (full list in `sync.sh`
  `SKILLS_MIT`), plus `log-analyzer`, plus 7 Apache-2.0 skills, plus the
  standalone skill repos (bro, humanizer, caveman/ponytail families).
- Customization policy: five upstream skills carry appended `## Local
  adaptation` sections via `../patches/*.patch` (environment specifics:
  short-name triggers, tool paths, output contracts). The canonical skill
  names stay upstream; short invocations (`/tdd`, `/review-code`,
  `/investigate`, `/commit`) work through `../aliases/` symlinks plus
  patched frontmatter triggers.

## Re-sync

```sh
./sync.sh --check            # diff without writing
./sync.sh                    # fetch MIT + Apache sets + ranking doc + apply patches
SKILLS_MIT="interview-me" ./sync.sh interview-me
SKILLS_APACHE="dependency-doctor" ./sync.sh dependency-doctor
```

Apache-2.0 is vendored by default (same permissive class as MIT:
commercial use allowed). `self-improving-agent-skills` is skipped — it is
a full-stack app (`backend/` + `frontend/`), not a `SKILL.md` skill.
