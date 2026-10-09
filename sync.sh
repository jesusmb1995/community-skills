#!/usr/bin/env bash
# Re-sync vendored community skills from permissive-licensed upstreams
# (MIT + Apache-2.0 — both allow commercial use, modification, distribution).
#
# Policy: GENERIC UPSTREAM WINS. Local customization is appended as a
# "Local adaptation" section via patches/*.patch (short-name triggers,
# tool paths, output contracts); short invocations also work through
# aliases/ symlinks plus patched frontmatter triggers.
#
# Sources:
#   1. addyosmani/agent-skills (MIT) — skills/<name>/ (SKILL.md + any
#      per-skill references//scripts/) + repo-root LICENSE. Skills that link
#      the upstream repo-level references/ dir have those files copied into
#      their own references/ and the links rewritten (mechanical, in this
#      script — keeps every skill self-contained).
#   2. yuxiaopeng/Github-Ranking-AI Top100/AI Agents.md (MIT) — discovery
#      pointer only, fetched into docs/. The repos it ranks carry mixed
#      licenses, so nothing from it is auto-vendored.
#   3. Shubhamsaboo/awesome-llm-apps agent_skills/ (Apache-2.0) —
#      <skill>/SKILL.md + references/ + scripts/ + repo-root LICENSE.
#      self-improving-agent-skills is skipped: it is a full-stack app
#      (backend/frontend), not a SKILL.md skill.
#
# Curated local changes live in patches/*.patch (paths like
# a/skills/<name>/SKILL.md), applied with patch -p1 to the FETCHED tree —
# including in --check mode, so --check reports real drift, not the
# deliberate customization.
#
# Usage:
#   ./sync.sh [--check] [SKILL...]
#     --check         stage+patch to temp, diff, do not overwrite
#     SKILL...        limit to these skill dirs (default: all allowlists)
#
# Env:
#   SKILLS_MIT="..."     (default allowlist below)
#   SKILLS_APACHE="..."  (default allowlist below)

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ADDY_REPO="https://github.com/addyosmani/agent-skills.git"
ADDY_LICENSE_URL="https://raw.githubusercontent.com/addyosmani/agent-skills/main/LICENSE"
AWESOME_REPO="https://github.com/Shubhamsaboo/awesome-llm-apps.git"
AWESOME_LICENSE_URL="https://raw.githubusercontent.com/Shubhamsaboo/awesome-llm-apps/main/LICENSE"
LOG_SKILL_URL="https://raw.githubusercontent.com/albertdobmeyer/openskill-forge/main/skills/log-analyzer/SKILL.md"
LOG_LICENSE_URL="https://raw.githubusercontent.com/albertdobmeyer/openskill-forge/main/LICENSE"
RANKING_URL="https://raw.githubusercontent.com/yuxiaopeng/Github-Ranking-AI/main/Top100/AI%20Agents.md"

SKILLS_MIT="${SKILLS_MIT:-api-and-interface-design browser-testing-with-devtools ci-cd-and-automation code-review-and-quality code-simplification constraint-driven-development context-engineering debugging-and-error-recovery deprecation-and-migration documentation-and-adrs doubt-driven-development frontend-ui-engineering git-workflow-and-versioning idea-refine incremental-implementation interview-me observability-and-instrumentation performance-optimization planning-and-task-breakdown security-and-hardening shipping-and-launch source-driven-development spec-driven-development test-driven-development using-agent-skills}"
SKILLS_APACHE="${SKILLS_APACHE:-advisor-orchestrator-worker commit-archaeologist dependency-doctor first-reader project-graveyard scope-creep-detector thinking-out-loud}"

check_only=false
only=()
for arg in "$@"; do
    case "$arg" in
        --check) check_only=true ;;
        --*) echo "unknown flag: $arg" >&2; exit 2 ;;
        *) only+=("$arg") ;;
    esac
done

wanted() { # name allowlist...
    local name="$1"; shift
    if [ "${#only[@]}" -gt 0 ]; then
        for x in "${only[@]}"; do
            [ "$x" = "$name" ] && return 0
        done
        return 1
    fi
    for x in $*; do
        [ "$x" = "$name" ] && return 0
    done
    return 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
new="$tmp/new/skills"
mkdir -p "$new"

# License gates: upstream repo-root LICENSEs must still read as expected.
curl -fsSL "$ADDY_LICENSE_URL" -o "$tmp/LICENSE.addyosmani-MIT"
if ! head -n 1 "$tmp/LICENSE.addyosmani-MIT" | grep -q "MIT License"; then
    echo "MIT gate failed: addyosmani LICENSE no longer MIT-headed" >&2
    exit 1
fi
curl -fsSL "$AWESOME_LICENSE_URL" -o "$tmp/LICENSE.awesome-Apache-2.0"
if ! grep -q "Apache License" "$tmp/LICENSE.awesome-Apache-2.0"; then
    echo "Apache gate failed: awesome-llm-apps LICENSE no longer Apache-headed" >&2
    exit 1
fi

frontmatter_gate() { # file expected-name
    if ! head -n 6 "$1" | grep -q "^name: $2\$"; then
        echo "frontmatter gate failed for $2 (expected 'name: $2' in $1)" >&2
        exit 1
    fi
}

sparse_clone() { # dest repo pattern...
    local dest="$1" repo="$2"; shift 2
    git clone --depth 1 --filter=blob:none --sparse "$repo" "$dest" >&2
    # shellcheck disable=SC2086
    (cd "$dest" && git sparse-checkout set --no-cone $* >&2)
}

# 1. addyosmani/agent-skills (MIT): SKILL.md + per-skill references//scripts/.
addy="$tmp/addy"
addy_paths=""
for skill in $SKILLS_MIT; do
    if wanted "$skill" $SKILLS_MIT; then
        addy_paths="$addy_paths /skills/$skill/SKILL.md skills/$skill/references skills/$skill/scripts"
    fi
done
if [ -n "$addy_paths" ]; then
    # shellcheck disable=SC2086
    sparse_clone "$addy" "$ADDY_REPO" $addy_paths references
    for skill in $SKILLS_MIT; do
        wanted "$skill" $SKILLS_MIT || continue
        frontmatter_gate "$addy/skills/$skill/SKILL.md" "$skill"
        mkdir -p "$new/$skill"
        cp "$addy/skills/$skill/SKILL.md" "$new/$skill/SKILL.md"
        for sub in references scripts; do
            if [ -d "$addy/skills/$skill/$sub" ]; then
                cp -r "$addy/skills/$skill/$sub" "$new/$skill/$sub"
            fi
        done
        cp "$tmp/LICENSE.addyosmani-MIT" "$new/$skill/LICENSE"
        # Normalize repo-level shared-ref links into per-skill copies so the
        # vendored skill is self-contained (deploys as one dir).
        needed="$(grep -o '\.\./\.\./references/[A-Za-z0-9_./-]*' "$new/$skill/SKILL.md" | sed 's|../../references/||' | sort -u || true)"
        for ref in $needed; do
            mkdir -p "$new/$skill/references"
            cp "$addy/references/$ref" "$new/$skill/references/$ref"
        done
        if [ -n "$needed" ]; then
            sed -i 's|\.\./\.\./references/|references/|' "$new/$skill/SKILL.md"
        fi
    done
fi

# 1b. log-analyzer (MIT, vendored from the openskill-forge collection —
# skills/log-analyzer; there is no standalone log-analyzer repo).
if [ "${#only[@]}" -eq 0 ] || wanted "log-analyzer" "${only[@]}"; then
    curl -fsSL "$LOG_SKILL_URL" -o "$tmp/log-analyzer.SKILL.md"
    curl -fsSL "$LOG_LICENSE_URL" -o "$tmp/LICENSE.log-analyzer-MIT"
    frontmatter_gate "$tmp/log-analyzer.SKILL.md" "log-analyzer"
    if ! head -n 1 "$tmp/LICENSE.log-analyzer-MIT" | grep -q "MIT License"; then
        echo "MIT gate failed: openskill-forge LICENSE no longer MIT-headed" >&2
        exit 1
    fi
    mkdir -p "$new/log-analyzer"
    cp "$tmp/log-analyzer.SKILL.md" "$new/log-analyzer/SKILL.md"
    cp "$tmp/LICENSE.log-analyzer-MIT" "$new/log-analyzer/LICENSE"
fi
# 1c. Standalone skill repos (MIT): root-level skills plus skills/ families.
# bro/humanizer keep a single skill at repo root; caveman/ponytail ship a
# skills/ family (main skill + command skills) — each becomes its own
# skills/<name>/ dir, discovered dynamically so new upstream siblings are
# picked up automatically. Root LICENSE rides with every skill.
BRO_REPO="https://github.com/luchasarie/bro-skill.git"
HUMANIZER_REPO="https://github.com/blader/humanizer.git"
CAVEMAN_REPO="https://github.com/JuliusBrussee/caveman.git"
PONYTAIL_REPO="https://github.com/DietrichGebert/ponytail.git"

vendor_root_skill() { # clone-dir dest-name license-tmpfile
    frontmatter_gate "$1/SKILL.md" "$2"
    mkdir -p "$new/$2"
    cp "$1/SKILL.md" "$new/$2/SKILL.md"
    [ -f "$1/README.md" ] && cp "$1/README.md" "$new/$2/README.md"
    cp "$3" "$new/$2/LICENSE"
}

vendor_family() { # clone-dir skills-subdir license-tmpfile [notice-file]
    local clonedir="$1" subdir="$2" lic="$3" notice="${4:-}"
    for skilldir in "$clonedir/$subdir"/*/; do
        [ -f "$skilldir/SKILL.md" ] || continue
        local name
        name="$(basename "$skilldir")"
        if [ "${#only[@]}" -gt 0 ]; then
            wanted "$name" "${only[@]}" || continue
        fi
        frontmatter_gate "$skilldir/SKILL.md" "$name"
        mkdir -p "$new/$name"
        cp "$skilldir/SKILL.md" "$new/$name/SKILL.md"
        [ -f "$skilldir/README.md" ] && cp "$skilldir/README.md" "$new/$name/README.md"
        for sub in references scripts; do
            if [ -d "$skilldir/$sub" ]; then
                cp -r "$skilldir/$sub" "$new/$name/$sub"
            fi
        done
        cp "$lic" "$new/$name/LICENSE"
        if [ -n "$notice" ] && [ -f "$notice" ]; then
            cp "$notice" "$new/$name/NOTICE"
        fi
    done
}

mit_gate() { # license-tmpfile repo-label
    if ! head -n 1 "$1" | grep -q "MIT License"; then
        echo "MIT gate failed: $2 LICENSE no longer MIT-headed" >&2
        exit 1
    fi
}

if [ "${#only[@]}" -eq 0 ] || wanted "bro" "${only[@]}" || wanted "humanizer" "${only[@]}"; then
    bro="$tmp/bro"
    sparse_clone "$bro" "$BRO_REPO" /SKILL.md /README.md /LICENSE
    cp "$bro/LICENSE" "$tmp/LICENSE.bro-MIT"
    mit_gate "$tmp/LICENSE.bro-MIT" "bro-skill"
    { [ "${#only[@]}" -eq 0 ] || wanted "bro" "${only[@]}"; } && vendor_root_skill "$bro" "bro" "$tmp/LICENSE.bro-MIT"
    human="$tmp/humanizer"
    sparse_clone "$human" "$HUMANIZER_REPO" /SKILL.md /README.md /LICENSE
    cp "$human/LICENSE" "$tmp/LICENSE.humanizer-MIT"
    mit_gate "$tmp/LICENSE.humanizer-MIT" "humanizer"
    { [ "${#only[@]}" -eq 0 ] || wanted "humanizer" "${only[@]}"; } && vendor_root_skill "$human" "humanizer" "$tmp/LICENSE.humanizer-MIT"
fi
# Family repos are small blobless clones; vendor_family filters by name itself.
cave="$tmp/caveman"
sparse_clone "$cave" "$CAVEMAN_REPO" skills /LICENSE /NOTICE
cp "$cave/LICENSE" "$tmp/LICENSE.caveman-Apache-2.0"
# NOTE: caveman relicensed at 3.0.0: skills were MIT, now Apache-2.0
# (see upstream LICENSING.md). Apache-2.0 is allowed here.
if ! grep -q "Apache License" "$tmp/LICENSE.caveman-Apache-2.0"; then
    echo "Apache gate failed: caveman LICENSE no longer Apache-headed" >&2
    exit 1
fi
vendor_family "$cave" "skills" "$tmp/LICENSE.caveman-Apache-2.0" "$cave/NOTICE"
pony="$tmp/ponytail"
sparse_clone "$pony" "$PONYTAIL_REPO" skills /LICENSE
cp "$pony/LICENSE" "$tmp/LICENSE.ponytail-MIT"
mit_gate "$tmp/LICENSE.ponytail-MIT" "ponytail"
vendor_family "$pony" "skills" "$tmp/LICENSE.ponytail-MIT"
# 2. Ranking pointer (MIT list, docs only — never auto-vendored as skills).
if [ "$check_only" = true ]; then
    curl -fsSL "$RANKING_URL" -o "$tmp/RANKING-AI-Agents.md"
    diff -u "$script_dir/docs/RANKING-AI-Agents.md" "$tmp/RANKING-AI-Agents.md" || true
else
    curl -fsSL "$RANKING_URL" -o "$script_dir/docs/RANKING-AI-Agents.md"
fi

# 3. awesome-llm-apps (Apache-2.0): SKILL.md + references/ + scripts/.
awesome="$tmp/awesome"
awesome_paths=""
for skill in $SKILLS_APACHE; do
    if wanted "$skill" $SKILLS_APACHE; then
        awesome_paths="$awesome_paths /agent_skills/$skill/SKILL.md agent_skills/$skill/references agent_skills/$skill/scripts"
    fi
done
if [ -n "$awesome_paths" ]; then
    # shellcheck disable=SC2086
    sparse_clone "$awesome" "$AWESOME_REPO" $awesome_paths
    for skill in $SKILLS_APACHE; do
        wanted "$skill" $SKILLS_APACHE || continue
        frontmatter_gate "$awesome/agent_skills/$skill/SKILL.md" "$skill"
        mkdir -p "$new/$skill"
        cp "$awesome/agent_skills/$skill/SKILL.md" "$new/$skill/SKILL.md"
        for sub in references scripts; do
            if [ -d "$awesome/agent_skills/$skill/$sub" ]; then
                cp -r "$awesome/agent_skills/$skill/$sub" "$new/$skill/$sub"
            fi
        done
        cp "$tmp/LICENSE.awesome-Apache-2.0" "$new/$skill/LICENSE"
    done
fi

# 4. Curated local customizations on top of the fetched tree (also in
# --check mode, so check reports real drift, not the deliberate patches).
for p in "$script_dir"/patches/*.patch; do
    [ -e "$p" ] || continue
    if patch -p1 --forward -d "$tmp/new" < "$p"; then
        :
    elif [ "$check_only" = true ] && [ "${#only[@]}" -gt 0 ]; then
        echo "warning: patch $(basename "$p") did not apply to filtered tree" >&2
    else
        echo "patch failed: $p" >&2
        exit 1
    fi
done

# 5. Diff (check) or install (sync) each staged skill.
report_new() { # repo-path staged-path label
    if [ ! -e "$1" ]; then
        echo "new: $3"
        [ -f "$2" ] && cat "$2"
        [ -d "$2" ] && find "$2" -type f
        return 0
    fi
    return 1
}
for staged in "$new"/*/; do
    [ -d "$staged" ] || continue
    skill="$(basename "$staged")"
    if [ "$check_only" = true ]; then
        report_new "$script_dir/skills/$skill/SKILL.md" "$staged/SKILL.md" "skills/$skill/SKILL.md" || \
            diff -u "$script_dir/skills/$skill/SKILL.md" "$staged/SKILL.md" || true
        report_new "$script_dir/skills/$skill/LICENSE" "$staged/LICENSE" "skills/$skill/LICENSE" || \
            diff -u "$script_dir/skills/$skill/LICENSE" "$staged/LICENSE" || true
        if [ -f "$staged/NOTICE" ] || [ -f "$script_dir/skills/$skill/NOTICE" ]; then
            report_new "$script_dir/skills/$skill/NOTICE" "$staged/NOTICE" "skills/$skill/NOTICE" || \
                diff -u "$script_dir/skills/$skill/NOTICE" "$staged/NOTICE" || true
        fi
        for sub in references scripts; do
            if [ -d "$staged/$sub" ] || [ -d "$script_dir/skills/$skill/$sub" ]; then
                report_new "$script_dir/skills/$skill/$sub" "$staged/$sub" "skills/$skill/$sub/" || \
                    diff -ru "$script_dir/skills/$skill/$sub" "$staged/$sub" || true
            fi
        done
    else
        mkdir -p "$script_dir/skills/$skill"
        cp "$staged/SKILL.md" "$script_dir/skills/$skill/SKILL.md"
        cp "$staged/LICENSE" "$script_dir/skills/$skill/LICENSE"
        rm -f "$script_dir/skills/$skill/NOTICE"
        if [ -f "$staged/NOTICE" ]; then
            cp "$staged/NOTICE" "$script_dir/skills/$skill/NOTICE"
        fi
        for sub in references scripts; do
            rm -rf "$script_dir/skills/$skill/$sub"
            if [ -d "$staged/$sub" ]; then
                cp -r "$staged/$sub" "$script_dir/skills/$skill/$sub"
            fi
        done
    fi
done

if [ "$check_only" = false ]; then
    sha256sum "$script_dir"/skills/*/SKILL.md 2>/dev/null || true
fi
