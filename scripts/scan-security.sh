#!/bin/bash

# SAST Security Scanning Script
# Runs Trivy (image scanning) and Checkov (IaC scanning) locally
#
# Usage:
#   ./scripts/scan-security.sh              # Run both (default)
#   ./scripts/scan-security.sh trivy        # Run Trivy only
#   ./scripts/scan-security.sh checkov      # Run Checkov only
#   ./scripts/scan-security.sh all          # Run both (explicit)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCAN_TYPE="${1:-all}"
VERBOSE="${VERBOSE:-0}"

log_info() {
  echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
  echo -e "${GREEN}✅${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
  echo -e "${RED}❌${NC} $*"
}

check_command() {
  if ! command -v "$1" &> /dev/null; then
    log_error "$1 is not installed."
    return 1
  fi
}

scan_trivy() {
  log_info "Starting Trivy Docker image scan..."
  echo ""

  if ! check_command trivy; then
    log_warn "Trivy not found locally. Install with:"
    echo "  - macOS:  brew install aquasecurity/trivy/trivy"
    echo "  - Linux:  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin v0.71.0"
    echo "  - Docker: docker run aquasec/trivy image --help"
    return 1
  fi

  local IMAGE="devpolatto/devops-challenge-nginx:latest"

  log_info "Scanning image: $IMAGE"
  echo ""

  trivy image \
    --severity CRITICAL,HIGH,MEDIUM \
    --format table \
    --exit-code 0 \
    "$IMAGE"

  echo ""
  log_success "Trivy scan completed. No blocker on exit code (info only)."
}

scan_checkov() {
  log_info "Starting Checkov IaC scan..."
  echo ""

  if ! check_command checkov; then
    log_warn "Checkov not found locally. Install with:"
    echo "  pip install checkov"
    echo "  or"
    echo "  pip3 install checkov --break-system-packages <- Warning!"
    return 1
  fi

  log_info "Scanning directory: $PROJECT_ROOT"
  echo ""

  cd "$PROJECT_ROOT"

  checkov \
    --directory . \
    --framework dockerfile,kubernetes,github_actions,terraform \
    --skip-check CKV_DOCKER_2,CKV_DOCKER_7 \
    --compact \
    --output cli \
    --quiet

  echo ""
  log_success "Checkov scan completed."
}

main() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  🔒 Security Scanning Suite${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo ""

  case "$SCAN_TYPE" in
    trivy)
      scan_trivy
      ;;
    checkov)
      scan_checkov
      ;;
    all)
      scan_trivy || log_warn "Trivy scan skipped (tool not installed)"
      echo ""
      scan_checkov || log_warn "Checkov scan skipped (tool not installed)"
      ;;
    *)
      log_error "Unknown scan type: $SCAN_TYPE"
      echo ""
      echo "Usage:"
      echo "  $0              # Run both Trivy and Checkov"
      echo "  $0 trivy        # Run Trivy only"
      echo "  $0 checkov      # Run Checkov only"
      echo "  $0 all          # Run both (explicit)"
      echo ""
      exit 1
      ;;
  esac

  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}✅ Security scanning completed.${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo ""
}

main "$@"

# checkov 3.2.533 requires boto3==1.35.49, but you have boto3 1.39.15 which is incompatible.
# prowler 5.14.0 requires botocore==1.39.15, but you have botocore 1.39.17 which is incompatible.

# pip3 uninstall boto3 botocore -y --break-system-packages
# pip3 install boto3==1.35.49  --break-system-packages
# pip3 install botocore==1.35.49 --break-system-packages