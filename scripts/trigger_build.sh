#!/usr/bin/env bash
###############################################################################
# FogOS Kernel — GitHub Actions Build Trigger
#
# Developer : Prince · VirgoYT707
# Usage     : bash scripts/trigger_build.sh [--release] [--prerelease]
#
# Set FOGOS_GITHUB_TOKEN in Replit Secrets before running.
# The script calls the GitHub API to dispatch the build workflow.
###############################################################################

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✅ $*${NC}"; }
info() { echo -e "${CYAN}ℹ  $*${NC}"; }
warn() { echo -e "${YELLOW}⚠  $*${NC}"; }
fail() { echo -e "${RED}❌ $*${NC}"; exit 1; }

###############################################################################
# Parse flags
###############################################################################
RELEASE="false"
PRERELEASE="false"
for arg in "$@"; do
    case "$arg" in
        --release)    RELEASE="true" ;;
        --prerelease) PRERELEASE="true" ;;
        --help|-h)
            echo "Usage: bash scripts/trigger_build.sh [--release] [--prerelease]"
            echo "  --release    Create a GitHub Release after build"
            echo "  --prerelease Mark the release as pre-release/beta"
            exit 0
            ;;
    esac
done

###############################################################################
# Token
###############################################################################
TOKEN="${FOGOS_GITHUB_TOKEN:-}"
if [ -z "$TOKEN" ]; then
    echo ""
    warn "FOGOS_GITHUB_TOKEN is not set."
    echo -e "${BOLD}How to set it:${NC}"
    echo "  In Replit → Tools → Secrets → Add secret"
    echo "  Key:   FOGOS_GITHUB_TOKEN"
    echo "  Value: your GitHub Personal Access Token"
    echo ""
    echo "  Required PAT scopes: repo (Contents: write, Actions: write)"
    echo ""
    printf "Or paste your token now (hidden): "
    read -rs TOKEN
    echo ""
    [ -z "$TOKEN" ] && fail "No token provided."
fi

###############################################################################
# Detect repo from git remote
###############################################################################
REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+/[^/.]+) ]]; then
    REPO="${BASH_REMATCH[1]}"
else
    fail "Cannot detect GitHub repo from remote '$REMOTE_URL'. Set origin to your GitHub repo."
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

info "Repository : $REPO"
info "Branch     : $BRANCH"
info "Release    : $RELEASE"
info "Pre-release: $PRERELEASE"
echo ""

###############################################################################
# Trigger workflow dispatch
###############################################################################
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${REPO}/actions/workflows/build.yml/dispatches" \
  -d "{\"ref\":\"${BRANCH}\",\"inputs\":{\"release\":\"${RELEASE}\",\"prerelease\":\"${PRERELEASE}\"}}")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

case "$HTTP_CODE" in
    204)
        echo ""
        ok "Build triggered successfully!"
        echo ""
        echo -e "${BOLD}Monitor your build:${NC}"
        echo -e "  ${CYAN}https://github.com/${REPO}/actions${NC}"
        echo ""
        if [ "$RELEASE" = "true" ]; then
            ok "A GitHub Release will be created automatically when the build finishes."
        fi
        ;;
    401)
        fail "Authentication failed — check your FOGOS_GITHUB_TOKEN has 'repo' scope."
        ;;
    404)
        fail "Workflow not found. Make sure build.yml is in .github/workflows/ and the branch '$BRANCH' exists."
        ;;
    422)
        fail "Validation error — the branch '$BRANCH' may not have the workflow_dispatch trigger. Push to main first."
        ;;
    *)
        fail "Unexpected response (HTTP $HTTP_CODE): $BODY"
        ;;
esac
