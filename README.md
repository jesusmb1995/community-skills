# skill_community — vendored skills with permissive licenses

Standalone collection of MIT / Apache-2.0 skills (both allow commercial
use, modification, distribution). One repo, one sync script: fetch from
upstreams, apply local patches, deploy.

## Licensing

- Root `LICENSE` (MIT) covers this repo's own files: `sync.sh`, `patches/`,
  `docs/`, this README.
- Each `skills/<name>/` dir carries its own upstream `LICENSE` (MIT or
  Apache-2.0), which governs that skill's files. Caveman skills additionally
  carry upstream `NOTICE` (attribution required by Apache-2.0 §4(d)).

## Layout

```
skill_community/
  sync.sh            # re-sync everything (run from here)
  skills/<name>/     # one dir per skill: SKILL.md + LICENSE (+ README/references/scripts where upstream ships them)
  aliases/<alias>    # symlinks -> ../skills/<canonical> (tdd, review-code, investigate, commit)
  patches/*.patch    # local customizations, paths like a/skills/<name>/SKILL.md
  docs/              # SOURCES.md (full inventory), ranking pointer, manual-install notes
```

## Sources (detail: `docs/SOURCES.md`)

| Upstream | License | Skills |
|----------|---------|--------|
| `addyosmani/agent-skills` | MIT | all 25 `skills/` |
| `albertdobmeyer/openskill-forge` (`skills/log-analyzer`, no standalone repo) | MIT | `log-analyzer` |
| `Shubhamsaboo/awesome-llm-apps` (`agent_skills/`) | Apache-2.0 | 7 skills |
| `luchasarie/bro-skill` (root skill) | MIT | `bro` |
| `blader/humanizer` (root skill) | MIT | `humanizer` |
| `JuliusBrussee/caveman` (`skills/` family; relicensed Apache-2.0 at 3.0.0, see upstream `LICENSING.md`) | Apache-2.0 | 22 skills (`caveman` + command skills) |
| `DietrichGebert/ponytail` (`skills/` family) | MIT | 6 skills (`ponytail` + command skills) |
| `yuxiaopeng/Github-Ranking-AI` (`Top100/AI Agents.md`) | MIT (the list) | docs pointer only — ranked repos are mixed-license, nothing auto-vendored |

## patches/ — local adjustments applied on top of upstream

`sync.sh` applies every `*.patch` here with `patch -p1 --forward` to the
fetched tree (including in `--check` mode, so check reports real drift, not
the deliberate customization). Keep patches small: appended `## Local
adaptation` sections with environment specifics (short-name triggers,
tool paths, output contracts).

| Patch | Alias trigger | Adds |
|-------|---------------|------|
| `test-driven-development.patch` | `/tdd` | red-seam stash dance (git + stg), one-bug-one-test, no-API-change rule, focused-then-broad test order |
| `code-review-and-quality.patch` | `/review-code` | `$AGENT_TMP/review.md` contract, severity sort, `N/4` rubric, merge-gate stance |
| `debugging-and-error-recovery.patch` | `/investigate` | findings-file procedure, analysis-only rule, evidence-before-synthesis |
| `git-workflow-and-versioning.patch` | `/commit` | jj-first quick-commit procedure (status, no staging, describe/squash, fixup) |
| `using-agent-skills.patch` | — | routing note (tree only lists upstream skills; list `~/.agents/skills/` to catch the rest) |
