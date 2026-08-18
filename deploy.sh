#!/bin/bash
# ============================================================
#  Gavin AI Toolkit - Cross-Platform Deploy Script
#  Supports: Linux, macOS
#  Targets: CodeBuddy, Claude Code
#
#  Usage:
#    ./deploy.sh <platform> <scope> [project_path]
#
#  Platform:
#    codebuddy   → Deploy to CodeBuddy skills directory
#    claude      → Deploy to Claude Code commands directory
#
#  Scope:
#    user        → User-level (global)
#    project     → Project-level (requires project_path)
#
#  Examples:
#    ./deploy.sh codebuddy user
#    ./deploy.sh codebuddy project /path/to/project
#    ./deploy.sh claude user
#    ./deploy.sh claude project /path/to/project
# ============================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ── Script Location ─────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/skills/slam-code-reader"

# ── Help ────────────────────────────────────────────────
show_help() {
    echo ""
    echo -e "${BLUE}═════════════════════════════════════════${NC}"
    echo -e "  Gavin AI Toolkit - Deployment Tool"
    echo -e "  (Linux / macOS)"
    echo -e "${BLUE}═════════════════════════════════════════${NC}"
    echo ""
    echo "  Usage:"
    echo "    ./deploy.sh <platform> <scope> [project_path]"
    echo ""
    echo "  Platform:"
    echo "    codebuddy   Deploy to CodeBuddy (~/.workbuddy/skills/)"
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
    echo -e "${BLUE}═════════════════════════════════════════${NC}"
}

# ── Error Handler ────────────────────────────────────────
die() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

ok() {
    echo -e "${GREEN}✅ $1${NC}"
}

info() {
    echo -e "${BLUE}📌 $1${NC}"
}

# ── Parse Arguments ─────────────────────────────────────
if [[ $# -lt 2 ]]; then
    show_help
    exit 0
fi

PLATFORM="$1"
SCOPE="$2"
PROJECT_PATH="${3:-}"

# ── Determine Target Directory ──────────────────────────
detect_target_dir() {
    case "$PLATFORM" in
        codebuddy)
            case "$SCOPE" in
                user)
                    TARGET_DIR="$HOME/.workbuddy/skills/slam-code-reader"
                    ;;
                project)
                    if [[ -z "$PROJECT_PATH" ]]; then
                        die "Project path required for project-level deployment."
                    fi
                    if [[ ! -d "$PROJECT_PATH" ]]; then
                        die "Project path does not exist: $PROJECT_PATH"
                    fi
                    TARGET_DIR="$PROJECT_PATH/.workbuddy/skills/slam-code-reader"
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
                    # Claude uses flat .md files, not a directory
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

# ── Validate Source ─────────────────────────────────────
validate_source() {
    if [[ ! -f "$SOURCE_DIR/SKILL.md" ]]; then
        die "Source directory missing SKILL.md: $SOURCE_DIR"
    fi
    info "Source: $SOURCE_DIR"
}

# ── Deploy for CodeBuddy (symlink or copy) ─────────────
deploy_codebuddy() {
    echo ""
    info "Deploy mode: CodeBuddy ($SCOPE)"
    echo "   Target: $TARGET_DIR"

    # Remove old deployment if exists
    if [[ -e "$TARGET_DIR" ]]; then
        warn "Target exists, removing old version..."
        rm -rf "$TARGET_DIR"
    fi

    # Create parent directory
    mkdir -p "$(dirname "$TARGET_DIR")"

    # Try symbolic link first (preferred)
    if ln -s "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
        ok "Deployed successfully! (Symlink mode)"
        echo ""
        echo "   Source and target stay in sync."
        echo "   Edit source files to update all deployments."
    else
        # Fallback to copy
        warn "Symlink failed, using copy mode..."
        cp -R "$SOURCE_DIR" "$TARGET_DIR"
        ok "Deployed successfully! (Copy mode)"
        echo ""
        warn "Copy mode: re-run this script after editing source files."
    fi
}

# ── Deploy for Claude (flat .md files) ──────────────────
deploy_claude() {
    echo ""
    info "Deploy mode: Claude Code ($SCOPE)"
    echo "   Target: $TARGET_DIR"

    # Create target directory
    mkdir -p "$TARGET_DIR"

    # Claude uses individual .md command files
    # We deploy the main SKILL.md as a slash command + phase files as sub-commands

    # Main command: slam-analyze (or slam-read)
    MAIN_CMD="$TARGET_DIR/slam-code-reader.md"
    cp "$SOURCE_DIR/SKILL.md" "$MAIN_CMD"
    ok "Installed: slam-code-reader (main command)"

    # Phase sub-commands (optional, for granular use)
    PHASES_DIR="$TARGET_DIR"
    for phase_file in "$SOURCE_DIR"/phases/*.md; do
        if [[ -f "$phase_file" ]]; then
            phase_name=$(basename "$phase_file" .md)
            cmd_name="slam-${phase_name}"
            cp "$phase_file" "$PHASES_DIR/${cmd_name}.md"
            ok "Installed: $cmd_name"
        fi
    done

    echo ""
    echo "   Usage in Claude Code:"
    echo "   /slam-code-reader          Run full analysis"
    echo "   /slam-phase0-collect       Collect papers/docs only"
    echo "   /slam-phase1-topology      Scan code topology only"
    echo "   ... (etc)"
}

# ── Main ────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${BLUE}═════════════════════════════════════════${NC}"
    echo -e "  Gavin AI Toolkit - Deploy Tool"
    echo -e "${BLUE}═════════════════════════════════════════${NC}"

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
    echo -e "${GREEN}═════════════════════════════════════════${NC}"
    echo ""
    echo "  Next step:"
    case "$PLATFORM" in
        codebuddy)
            echo '    In CodeBuddy, type: "分析 D:/your-slam-project"'
            ;;
        claude)
            echo '    In Claude Code, type: /slam-code-reader D:/your-slam-project'
            ;;
    esac
    echo ""
}

main "$@"
