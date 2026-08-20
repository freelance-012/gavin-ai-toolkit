#!/bin/bash
# ============================================================
#  Gavin AI Toolkit - Deploy Script (Linux / macOS)
#  Supports: CodeBuddy, Claude Code
#
#  Usage:
#    ./deploy.sh <platform> <scope> [project_path]
#
#  Platform: codebuddy | claude
#  Scope:   user | project
#
#  Examples:
#    ./deploy.sh codebuddy user
#    ./deploy.sh codebuddy project /path/to/project
#    ./deploy.sh claude user
#    ./deploy.sh claude project /path/to/project
# ============================================================

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Script Location ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/skills"

# --- Helper Functions ---
die() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

ok() {
    echo -e "${GREEN}[OK] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# --- Help ---
show_help() {
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "  Gavin AI Toolkit - Deployment Tool"
    echo -e "  (Linux / macOS)"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
    echo "  Usage:"
    echo "    ./deploy.sh <platform> <scope> [project_path]"
    echo ""
    echo "  Platform:"
    echo "    codebuddy   Deploy to CodeBuddy (~/.codebuddy/skills/)"
    echo "    claude      Deploy to Claude Code (~/.claude/commands/)"
    echo ""
    echo "  Scope:"
    echo "    user        User-level (global, all projects)"
    echo "    project     Project-level (requires path)"
    echo ""
    echo "  Examples:"
    echo "    ./deploy.sh codebuddy user"
    echo "    ./deploy.sh codebuddy project /home/user/my-project"
    echo "    ./deploy.sh claude user"
    echo "    ./deploy.sh claude project /home/user/my-project"
    echo ""
    echo -e "${BLUE}==========================================${NC}"
}

# --- Parse Arguments ---
if [[ $# -lt 2 ]]; then
    show_help
    exit 0
fi

PLATFORM="$1"
SCOPE="$2"
PROJECT_PATH="${3:-}"

# --- Determine Target Directory ---
detect_target_dir() {
    case "$PLATFORM" in
        codebuddy)
            case "$SCOPE" in
                user)
                    TARGET_DIR="$HOME/.codebuddy/skills"
                    ;;
                project)
                    if [[ -z "$PROJECT_PATH" ]]; then
                        die "Project path required for project-level deployment."
                    fi
                    if [[ ! -d "$PROJECT_PATH" ]]; then
                        die "Project path does not exist: $PROJECT_PATH"
                    fi
                    TARGET_DIR="$PROJECT_PATH/.codebuddy/skills"
                    ;;
                *)
                    die "Unknown scope: '$SCOPE'. Use 'user' or 'project'."
                    ;;
            esac
            ;;
        claude)
            case "$SCOPE" in
                user)
                    TARGET_DIR="$HOME/.claude/commands"
                    CLAUDE_MODE="flat"
                    ;;
                project)
                    if [[ -z "$PROJECT_PATH" ]]; then
                        die "Project path required for project-level deployment."
                    fi
                    if [[ ! -d "$PROJECT_PATH" ]]; then
                        die "Project path does not exist: $PROJECT_PATH"
                    fi
                    TARGET_DIR="$PROJECT_PATH/.claude/commands"
                    CLAUDE_MODE="flat"
                    ;;
                *)
                    die "Unknown scope: '$SCOPE'. Use 'user' or 'project'."
                    ;;
            esac
            ;;
        *)
            die "Unknown platform: '$PLATFORM'. Use 'codebuddy' or 'claude'."
            ;;
    esac
}

# --- Validate Source ---
validate_source() {
    if [[ ! -d "$SKILLS_DIR" ]]; then
        die "Skills directory missing: $SKILLS_DIR"
    fi
    SKILL_COUNT=$(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l)
    if [[ "$SKILL_COUNT" -eq 0 ]]; then
        die "No skills found in: $SKILLS_DIR"
    fi
    info "Skills directory: $SKILLS_DIR ($SKILL_COUNT skills)"
    for skill_dir in "$SKILLS_DIR"/*/; do
        skill_name=$(basename "$skill_dir")
        if [[ ! -f "$skill_dir/SKILL.md" ]]; then
            warn "Skill '$skill_name' missing SKILL.md, skipping"
        fi
    done
}

# --- Deploy for CodeBuddy (symlink or copy) ---
deploy_codebuddy() {
    echo ""
    info "Deploy mode: CodeBuddy ($SCOPE)"
    echo "   Target: $TARGET_DIR"

    # Create parent directory
    mkdir -p "$TARGET_DIR"

    local deployed=0
    for skill_dir in "$SKILLS_DIR"/*/; do
        [[ ! -f "$skill_dir/SKILL.md" ]] && continue
        skill_name=$(basename "$skill_dir")
        local target="$TARGET_DIR/$skill_name"

        echo "   Deploying: $skill_name → $target"

        # Remove old deployment if exists
        if [[ -e "$target" ]]; then
            rm -rf "$target"
        fi

        # Try symbolic link first
        if ln -s "$skill_dir" "$target" 2>/dev/null; then
            ok "$skill_name deployed (symlink)"
        else
            cp -R "$skill_dir" "$target"
            ok "$skill_name deployed (copy)"
        fi
        deployed=$((deployed + 1))
    done

    echo ""
    if [[ $deployed -gt 0 ]]; then
        ok "All $deployed skills deployed successfully!"
    else
        warn "No valid skills found to deploy."
    fi
}

# --- Deploy for Claude (flat .md files) ---
deploy_claude() {
    echo ""
    info "Deploy mode: Claude Code ($SCOPE)"
    echo "   Target: $TARGET_DIR"

    # Create target directory
    mkdir -p "$TARGET_DIR"

    local deployed=0
    for skill_dir in "$SKILLS_DIR"/*/; do
        [[ ! -f "$skill_dir/SKILL.md" ]] && continue
        skill_name=$(basename "$skill_dir")

        # Main command - use cat to avoid file lock issues
        cat "$skill_dir/SKILL.md" > "$TARGET_DIR/${skill_name}.md"
        ok "Installed: ${skill_name}.md (main command)"

        # Phase sub-commands
        if [[ -d "$skill_dir/phases" ]]; then
            for phase_file in "$skill_dir"/phases/*.md; do
                if [[ -f "$phase_file" ]]; then
                    phase_name=$(basename "$phase_file" .md)
                    cmd_name="${skill_name}-${phase_name}"
                    cat "$phase_file" > "$TARGET_DIR/${cmd_name}.md"
                    ok "Installed: ${cmd_name}.md"
                fi
            done
        fi
        deployed=$((deployed + 1))
    done

    echo ""
    ok "All $deployed skills deployed successfully!"
    echo ""
    echo "   Usage in Claude Code:"
    for skill_dir in "$SKILLS_DIR"/*/; do
        [[ ! -f "$skill_dir/SKILL.md" ]] && continue
        skill_name=$(basename "$skill_dir")
        echo "   /${skill_name}          Run ${skill_name}"
    done
}

# --- Main ---
main() {
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "  Gavin AI Toolkit - Deploy Tool"
    echo -e "${BLUE}==========================================${NC}"

    detect_target_dir
    validate_source

    case "$PLATFORM" in
        codebuddy)
            deploy_codebuddy
            ;;
        claude)
            deploy_claude
            ;;
    esac

    echo ""
    echo -e "${GREEN}==========================================${NC}"
    echo ""
    echo "  Next step:"
    case "$PLATFORM" in
        codebuddy)
            echo '    In CodeBuddy, type: "profiler /path/to/project"'
            ;;
        claude)
            echo '    In Claude Code, type: /slam-project-profiler /path/to/project'
            echo '    Or: /slam-code-reader /path/to/project'
            ;;
    esac
    echo ""
}

main "$@"
