#!/usr/bin/env bash
# =============================================================================
# BugBountyOS - Complete Installation Script
# Version: 1.0.0
# Description: One-command setup for Bug Bounty Hunting Environment
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${LOG_DIR}" output reports screenshots workspace wordlists

log() { local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"; echo -e "${msg}" | tee -a "${LOG_FILE}"; }
info()  { log "${BLUE}[INFO]${NC} $1"; }
success() { log "${GREEN}[✓]${NC} $1"; }
warn()  { log "${YELLOW}[!]${NC} $1"; }

check_command() { command -v "$1" &>/dev/null; }

check_version() {
    local cmd="$1" label="$2"
    if check_command "$cmd"; then
        local ver=$("$cmd" --version 2>/dev/null || "$cmd" -version 2>/dev/null || echo "installed")
        success "${label}: ${ver}"
    else
        warn "${label}: NOT FOUND"
    fi
}

# System Setup
phase_system() {
    info "=== Phase 0: System Preparation ==="
    sudo apt-get update -qq && sudo apt-get install -y -qq \
        curl wget git unzip zip gzip tar build-essential pkg-config libpcap-dev \
        jq whois dnsutils net-tools nmap masscon \
        python3 python3-pip python3-venv openssl ca-certificates ripgrep fzf tmux 2>&1 | tee -a "${LOG_FILE}"
    success "System packages installed"
}

# Go + Rust
phase_languages() {
    info "=== Phase 1: Languages ==="
    if ! check_command go; then
        local GO_VER=$(curl -s https://go.dev/VERSION?m=text | head -1)
        wget -q "https://go.dev/dl/${GO_VER}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
        sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf /tmp/go.tar.gz
        rm -f /tmp/go.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
        export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
        success "Go ${GO_VER} installed"
    fi
    if ! check_command cargo; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>/dev/null
        source "$HOME/.cargo/env"
    fi
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.cargo/bin
}

# PDTM → All ProjectDiscovery tools
phase_projectdiscovery() {
    info "=== Phase 2: ProjectDiscovery Tools ==="
    if ! check_command pdtm; then
        go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest 2>&1 | tee -a "${LOG_FILE}"
    fi
    pdtm -install-all 2>&1 | tee -a "${LOG_FILE}" || true
    pdtm -install-path 2>&1 | tee -a "${LOG_FILE}" || true
    nuclei -update-templates 2>/dev/null
    success "ProjectDiscovery tools installed"
    for t in subfinder httpx nuclei naabu dnsx katana interactsh pdtm; do check_version "$t" "$t"; done
}

# Recon Tools
phase_recon() {
    info "=== Phase 3: Recon Tools ==="
    if ! check_command findomain; then
        curl -LO https://github.com/findomain/findomain/releases/latest/download/findomain-linux.zip
        unzip -q -o findomain-linux.zip -d /tmp/findomain && sudo mv /tmp/findomain/findomain-linux /usr/local/bin/findomain
        sudo chmod +x /usr/local/bin/findomain && rm -f findomain-linux.zip
    fi
    if ! check_command amass; then go install -v github.com/owasp-amass/amass/v4/...@master 2>&1 | tee -a "${LOG_FILE}"; fi
    if ! check_command shuffledns; then go install -v github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    if ! check_command httprobe; then go install -v github.com/tomnomnom/httprobe@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    if ! check_command puredns; then go install -v github.com/d3mondev/puredns/v2@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    if ! check_command alterx; then go install -v github.com/projectdiscovery/alterx/cmd/alterx@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    success "Recon tools installed"
}

# Crawlers
phase_crawlers() {
    info "=== Phase 4: Crawlers ==="
    if ! check_command gospider; then go install -v github.com/jaeles-project/gospider@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    if ! check_command hakrawler; then go install -v github.com/hakluke/hakrawler@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    success "Crawlers installed"
}

# Fuzzers
phase_fuzzers() {
    info "=== Phase 5: Fuzzers ==="
    if ! check_command ffuf; then go install -v github.com/ffuf/ffuf/v2@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    if ! check_command gobuster; then go install -v github.com/OJ/gobuster/v3@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    if ! check_command dirsearch; then
        git clone --depth 1 https://github.com/maurosoria/dirsearch.git /tmp/dirsearch 2>/dev/null
        sudo ln -sf /tmp/dirsearch/dirsearch.py /usr/local/bin/dirsearch
    fi
    success "Fuzzers installed"
}

# JavaScript Tools
phase_jstools() {
    info "=== Phase 6: JavaScript Tools ==="
    if ! check_command subjs; then go install -v github.com/lc/subjs@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    if ! check_command getJS; then go install -v github.com/003random/getJS@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    success "JS tools installed"
}

# Secret Discovery
phase_secrets() {
    info "=== Phase 7: Secret Discovery ==="
    pip3 install trufflehog 2>/dev/null || true
    if ! check_command gitleaks; then go install -v github.com/gitleaks/gitleaks/v8@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    success "Secret tools installed"
}

# URL Tools
phase_urltools() {
    info "=== Phase 8: URL Tools ==="
    if ! check_command gau; then go install -v github.com/lc/gau/v2/cmd/gau@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    if ! check_command waybackurls; then go install -v github.com/tomnomnom/waybackurls@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    if ! check_command qsreplace; then go install -v github.com/tomnomnom/qsreplace@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    if ! check_command unfurl; then go install -v github.com/tomnomnom/unfurl@latest 2>&1 | tee -a "${LOG_FILE}"; fi
    if ! check_command gf; then
        go install -v github.com/tomnomnom/gf@latest 2>&1 | tee -a "${LOG_FILE}"
        git clone --depth 1 https://github.com/1ndianl33t/Gf-Patterns.git /tmp/gf-patterns 2>/dev/null
        mkdir -p ~/.gf && cp /tmp/gf-patterns/*.json ~/.gf/ 2>/dev/null || true
    fi
    success "URL tools installed"
}

# BBOT
phase_bbot() {
    info "=== Phase 9: BBOT ==="
    if ! check_command bbot; then pip3 install bbot 2>&1 | tee -a "${LOG_FILE}"; fi
    check_version "bbot" "BBOT"
}

# Wordlists
phase_wordlists() {
    info "=== Phase 10: Wordlists ==="
    if [ ! -f "wordlists/common.txt" ]; then
        wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt -O wordlists/common.txt
        wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-5000.txt -O wordlists/subdomains-top.txt
        success "Wordlists downloaded"
    fi
}

# Finalize
phase_finalize() {
    info "=== Phase 11: Finalization ==="
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin:$HOME/.cargo/bin
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin:$HOME/.cargo/bin' >> ~/.bashrc
    sudo ln -sf "$HOME/go/bin"/* /usr/local/bin/ 2>/dev/null || true
    source ~/.bashrc 2>/dev/null || true
    success "Installation Complete!"
    echo ""
    for t in subfinder httpx nuclei naabu dnsx katana ffuf gospider gau waybackurls gf bbot; do
        check_version "$t" "$t"
    done
}

main() {
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     BugBountyOS Installer v1.0      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    START=$(date +%s)
    phase_system; phase_languages; phase_projectdiscovery; phase_recon
    phase_crawlers; phase_fuzzers; phase_jstools; phase_secrets
    phase_urltools; phase_bbot; phase_wordlists; phase_finalize
    END=$(date +%s)
    success "Total: $(( (END-START)/60 )) min"
    success "Log: ${LOG_FILE}"
    echo -e "${GREEN}Run 'source ~/.bashrc' then 'bbos -d target.com -m full'${NC}"
}

main "$@"
