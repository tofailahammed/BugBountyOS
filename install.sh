#!/usr/bin/env bash
set -euo pipefail

echo "======================================"
echo "   BugBountyOS Bootstrap Installer"
echo "======================================"

bash install/core.sh
bash install/projectdiscovery.sh
bash install/recon.sh
bash install/web.sh
bash install/javascript.sh
bash install/vulnerability.sh
bash install/bbot.sh
bash install/automation.sh

echo ""
echo "Core installation complete."

echo ""
echo "Next modules will be added gradually:"
echo " - ProjectDiscovery"
echo " - Recon"
echo " - Crawlers"
echo " - JS"
echo " - Secrets"
echo " - Vulnerability Tools"
echo " - BBOT"
echo " - reNgine"
#!/usr/bin/env bash
# =============================================================================
# BugBountyOS - Complete Installation Script
# Version: 1.0.0
# Author: Your Name
# Description: One-command setup for Bug Bounty Hunting Environment
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log file
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${LOG_DIR}" output reports screenshots workspace

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${msg}" | tee -a "${LOG_FILE}"
}

info()  { log "${BLUE}[INFO]${NC} $1"; }
success() { log "${GREEN}[✓]${NC} $1"; }
warn()  { log "${YELLOW}[!]${NC} $1"; }
error() { log "${RED}[✗]${NC} $1"; }

check_command() {
    if command -v "$1" &>/dev/null; then
        return 0
    fi
    return 1
}

check_version() {
    local cmd="$1"
    local label="$2"
    if check_command "${cmd}"; then
        local ver
        ver=$("${cmd}" --version 2>/dev/null || "${cmd}" -version 2>/dev/null || "${cmd}" version 2>/dev/null || echo "installed")
        success "${label}: ${ver}"
    else
        error "${label}: NOT FOUND"
    fi
}

# =============================================================================
# Phase 0: System Preparation
# =============================================================================

phase_system() {
    info "========================================"
    info "Phase 0: System Preparation"
    info "========================================"

    # Update package lists
    info "Updating package lists..."
    sudo apt-get update -qq 2>&1 | tee -a "${LOG_FILE}"

    # Install essential packages
    info "Installing essential system packages..."
    sudo apt-get install -y -qq \
        curl wget git unzip zip gzip tar \
        build-essential pkg-config libpcap-dev \
        jq whois dnsutils net-tools iputils-ping \
        nmap masscan \
        python3 python3-pip python3-venv \
        openssl ca-certificates \
        libxml2-dev libxslt1-dev \
        ripgrep fzf tmux \
        2>&1 | tee -a "${LOG_FILE}"

    success "System packages installed"
}

# =============================================================================
# Phase 1: Go & Rust Installation
# =============================================================================

phase_languages() {
    info "========================================"
    info "Phase 1: Languages (Go & Rust)"
    info "========================================"

    # Go Installation
    if ! check_command go; then
        info "Installing Go..."
        local GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -1)
        wget -q "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf /tmp/go.tar.gz
        rm -f /tmp/go.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
        export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
        success "Go ${GO_VERSION} installed"
    else
        info "Go already installed: $(go version)"
    fi

    # Rust (for some tools)
    if ! check_command cargo; then
        info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>&1 | tee -a "${LOG_FILE}"
        source "$HOME/.cargo/env"
        success "Rust installed"
    else
        info "Rust already installed: $(rustc --version)"
    fi

    # Ensure PATH
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.cargo/bin
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.cargo/bin' >> ~/.bashrc
    source ~/.bashrc 2>/dev/null || true
}

# =============================================================================
# Phase 2: ProjectDiscovery Tools (via PDTM)
# =============================================================================

phase_projectdiscovery() {
    info "========================================"
    info "Phase 2: ProjectDiscovery Tools (PDTM)"
    info "========================================"

    # Install PDTM
    if ! check_command pdtm; then
        info "Installing PDTM (ProjectDiscovery Tool Manager)..."
        go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest 2>&1 | tee -a "${LOG_FILE}"
        success "PDTM installed"
    else
        info "PDTM already installed: $(pdtm --version 2>/dev/null || echo 'latest')"
    fi

    # Install all PD tools via PDTM
    info "Installing all ProjectDiscovery tools..."
    pdtm -install-all 2>&1 | tee -a "${LOG_FILE}"
    pdtm -install-path 2>&1 | tee -a "${LOG_FILE}"

    # Install Nuclei templates
    info "Installing Nuclei templates..."
    nuclei -update-templates 2>&1 | tee -a "${LOG_FILE}"

    success "ProjectDiscovery tools installed"
    
    # Verify
    check_version "subfinder" "Subfinder"
    check_version "httpx"     "HTTPx"
    check_version "nuclei"    "Nuclei"
    check_version "naabu"     "Naabu"
    check_version "dnsx"      "DNSx"
    check_version "katana"    "Katana"
    check_version "interactsh" "Interactsh"
    check_version "pdtm"      "PDTM"
}

# =============================================================================
# Phase 3: Recon Tools
# =============================================================================

phase_recon() {
    info "========================================"
    info "Phase 3: Reconnaissance Tools"
    info "========================================"

    # Subdomain Enumeration
    if ! check_command findomain; then
        info "Installing Findomain..."
        curl -LO https://github.com/findomain/findomain/releases/latest/download/findomain-linux.zip
        unzip -q -o findomain-linux.zip -d /tmp/findomain
        sudo mv /tmp/findomain/findomain-linux /usr/local/bin/findomain
        sudo chmod +x /usr/local/bin/findomain
        rm -f findomain-linux.zip
        success "Findomain installed"
    fi

    if ! check_command amass; then
        info "Installing Amass..."
        go install -v github.com/owasp-amass/amass/v4/...@master 2>&1 | tee -a "${LOG_FILE}"
        success "Amass installed"
    fi

    if ! check_command shuffledns; then
        info "Installing ShuffleDNS..."
        go install -v github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest 2>&1 | tee -a "${LOG_FILE}"
        success "ShuffleDNS installed"
    fi

    if ! check_command alterx; then
        info "Installing alterx..."
        go install -v github.com/projectdiscovery/alterx/cmd/alterx@latest 2>&1 | tee -a "${LOG_FILE}"
        success "alterx installed"
    fi

    # Certificate Transparency
    if ! check_command crtsh; then
        info "Installing crtsh..."
        go install -v github.com/projectdiscovery/crtsh/cmd/crtsh@latest 2>&1 | tee -a "${LOG_FILE}"
        success "crtsh installed"
    fi

    # HTTP Probing
    if ! check_command httprobe; then
        info "Installing httprobe..."
        go install -v github.com/tomnomnom/httprobe@latest 2>&1 | tee -a "${LOG_FILE}"
        success "httprobe installed"
    fi

    # DNS Tools
    if ! check_command puredns; then
        info "Installing puredns..."
        go install -v github.com/d3mondev/puredns/v2@latest 2>&1 | tee -a "${LOG_FILE}"
        success "puredns installed"
    fi
    
    success "Recon tools installation completed"
    
    # Verify
    check_version "findomain"  "Findomain"
    check_version "amass"      "Amass"
    check_version "shuffledns" "ShuffleDNS"
    check_version "httprobe"   "httprobe"
}

# =============================================================================
# Phase 4: Crawlers
# =============================================================================

phase_crawlers() {
    info "========================================"
    info "Phase 4: Crawlers"
    info "========================================"

    if ! check_command gospider; then
        info "Installing GoSpider..."
        go install -v github.com/jaeles-project/gospider@latest 2>&1 | tee -a "${LOG_FILE}"
        success "GoSpider installed"
    fi

    if ! check_command hakrawler; then
        info "Installing Hakrawler..."
        go install -v github.com/hakluke/hakrawler@latest 2>&1 | tee -a "${LOG_FILE}"
        success "Hakrawler installed"
    fi

    success "Crawlers installation completed"
    check_version "gospider"   "GoSpider"
    check_version "hakrawler"  "Hakrawler"
}

# =============================================================================
# Phase 5: Fuzzers
# =============================================================================

phase_fuzzers() {
    info "========================================"
    info "Phase 5: Fuzzers"
    info "========================================"

    if ! check_command ffuf; then
        info "Installing FFUF..."
        go install -v github.com/ffuf/ffuf/v2@latest 2>&1 | tee -a "${LOG_FILE}"
        success "FFUF installed"
    fi

    if ! check_command dirsearch; then
        info "Installing Dirsearch..."
        git clone --depth 1 https://github.com/maurosoria/dirsearch.git /tmp/dirsearch 2>&1 | tee -a "${LOG_FILE}"
        sudo ln -sf /tmp/dirsearch/dirsearch.py /usr/local/bin/dirsearch 2>/dev/null || true
        sudo chmod +x /tmp/dirsearch/dirsearch.py
        success "Dirsearch installed"
    fi

    if ! check_command gobuster; then
        info "Installing GoBuster..."
        go install -v github.com/OJ/gobuster/v3@latest 2>&1 | tee -a "${LOG_FILE}"
        success "GoBuster installed"
    fi

    success "Fuzzers installation completed"
    check_version "ffuf"      "FFUF"
    check_version "gobuster"  "GoBuster"
}

# =============================================================================
# Phase 6: JavaScript Tools
# =============================================================================

phase_jstools() {
    info "========================================"
    info "Phase 6: JavaScript Analysis Tools"
    info "========================================"

    if ! check_command subjs; then
        info "Installing subjs..."
        go install -v github.com/lc/subjs@latest 2>&1 | tee -a "${LOG_FILE}"
        success "subjs installed"
    fi

    if ! check_command nuclei; then
        info "Nuclei already installed, updating JS-related templates..."
        nuclei -update-templates 2>&1 | tee -a "${LOG_FILE}"
    fi

    # LinkFinder for JS endpoints
    if [ ! -d "/opt/linkfinder" ]; then
        info "Installing LinkFinder..."
        sudo git clone --depth 1 https://github.com/GerbenJavado/LinkFinder.git /opt/linkfinder 2>&1 | tee -a "${LOG_FILE}"
        sudo pip3 install -r /opt/linkfinder/requirements.txt 2>&1 | tee -a "${LOG_FILE}"
        sudo ln -sf /opt/linkfinder/linkfinder.py /usr/local/bin/linkfinder
        sudo chmod +x /opt/linkfinder/linkfinder.py
        success "LinkFinder installed"
    fi

    if ! check_command getJS; then
        info "Installing getJS..."
        go install -v github.com/003random/getJS@latest 2>&1 | tee -a "${LOG_FILE}"
        success "getJS installed"
    fi

    success "JavaScript tools installation completed"
    check_version "subjs"  "subjs"
    check_version "getJS"  "getJS"
}

# =============================================================================
# Phase 7: Secret Discovery
# =============================================================================

phase_secrets() {
    info "========================================"
    info "Phase 7: Secret Discovery"
    info "========================================"

    if ! check_command trufflehog; then
        info "Installing TruffleHog..."
        pip3 install trufflehog 2>&1 | tee -a "${LOG_FILE}"
        success "TruffleHog installed"
    fi

    if ! check_command gitleaks; then
        info "Installing Gitleaks..."
        go install -v github.com/gitleaks/gitleaks/v8@latest 2>&1 | tee -a "${LOG_FILE}"
        success "Gitleaks installed"
    fi

    success "Secret discovery tools installed"
    check_version "trufflehog" "TruffleHog"
    check_version "gitleaks"   "Gitleaks"
}

# =============================================================================
# Phase 8: URL & Param Tools
# =============================================================================

phase_urltools() {
    info "========================================"
    info "Phase 8: URL & Parameter Tools"
    info "========================================"

    if ! check_command gau; then
        info "Installing gau..."
        go install -v github.com/lc/gau/v2/cmd/gau@latest 2>&1 | tee -a "${LOG_FILE}"
        success "gau installed"
    fi

    if ! check_command waybackurls; then
        info "Installing waybackurls..."
        go install -v github.com/tomnomnom/waybackurls@latest 2>&1 | tee -a "${LOG_FILE}"
        success "waybackurls installed"
    fi

    if ! check_command qsreplace; then
        info "Installing qsreplace..."
        go install -v github.com/tomnomnom/qsreplace@latest 2>&1 | tee -a "${LOG_FILE}"
        success "qsreplace installed"
    fi

    if ! check_command unfurl; then
        info "Installing unfurl..."
        go install -v github.com/tomnomnom/unfurl@latest 2>&1 | tee -a "${LOG_FILE}"
        success "unfurl installed"
    fi

    if ! check_command gf; then
        info "Installing gf..."
        go install -v github.com/tomnomnom/gf@latest 2>&1 | tee -a "${LOG_FILE}"
        # Install gf patterns
        git clone --depth 1 https://github.com/1ndianl33t/Gf-Patterns.git /tmp/gf-patterns 2>&1 | tee -a "${LOG_FILE}"
        mkdir -p ~/.gf
        cp /tmp/gf-patterns/*.json ~/.gf/ 2>/dev/null || true
        success "gf installed with patterns"
    fi

    success "URL & Parameter tools installed"
    check_version "gau"         "gau"
    check_version "waybackurls" "waybackurls"
    check_version "qsreplace"   "qsreplace"
    check_version "unfurl"      "unfurl"
}

# =============================================================================
# Phase 9: BBOT Installation
# =============================================================================

phase_bbot() {
    info "========================================"
    info "Phase 9: BBOT (Bighuge BLS OSINT Tool)"
    info "========================================"

    if ! check_command bbot; then
        info "Installing BBOT..."
        pip3 install bbot 2>&1 | tee -a "${LOG_FILE}"
        success "BBOT installed"
    else
        info "BBOT already installed: $(bbot --version 2>&1 | head -1)"
    fi

    check_version "bbot" "BBOT"
}

# =============================================================================
# Phase 10: Validation & Additional Tools
# =============================================================================

phase_validation() {
    info "========================================"
    info "Phase 10: Validation & Additional Tools"
    info "========================================"

    # Install pipx if not present
    if ! check_command pipx; then
        pip3 install pipx 2>&1 | tee -a "${LOG_FILE}"
        python3 -m pipx ensurepath 2>&1 | tee -a "${LOG_FILE}"
        export PATH="$HOME/.local/bin:$PATH"
    fi

    if ! check_command arjun; then
        info "Installing Arjun (Param Brute-forcer)..."
        pipx install arjun 2>&1 | tee -a "${LOG_FILE}"
        success "Arjun installed"
    fi

    success "Validation tools installed"
}

# =============================================================================
# Phase 11: Setup Wordlists
# =============================================================================

phase_wordlists() {
    info "========================================"
    info "Phase 11: Wordlists Setup"
    info "========================================"

    mkdir -p wordlists

    # Download common wordlists if not present
    if [ ! -f "wordlists/common.txt" ]; then
        info "Downloading common wordlists..."
        wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt -O wordlists/common.txt 2>&1 | tee -a "${LOG_FILE}"
        wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-medium-directories.txt -O wordlists/raft-medium.txt 2>&1 | tee -a "${LOG_FILE}"
        wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-5000.txt -O wordlists/subdomains-top.txt 2>&1 | tee -a "${LOG_FILE}"
        success "Wordlists downloaded"
    else
        info "Wordlists already exist"
    fi
}

# =============================================================================
# Phase 12: Cleanup & Finalization
# =============================================================================

phase_finalize() {
    info "========================================"
    info "Phase 12: Finalization"
    info "========================================"

    # Clean up Go cache
    go clean -cache 2>/dev/null || true

    # Source bashrc
    source ~/.bashrc 2>/dev/null || true

    # Final PATH setup
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin:$HOME/.cargo/bin
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin:$HOME/.cargo/bin' >> ~/.bashrc

    # Create symlinks for tools
    sudo ln -sf "$HOME/go/bin"/* /usr/local/bin/ 2>/dev/null || true

    success "========================================"
    success "✅ BugBountyOS Installation COMPLETE!"
    success "========================================"
    
    # Final verification
    info "Final verification of key tools:"
    for tool in subfinder httpx nuclei naabu dnsx katana ffuf gospider gau waybackurls bbot; do
        check_version "$tool" "$tool"
    done
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              BugBountyOS Installer v1.0              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""

    START_TIME=$(date +%s)

    phase_system
    phase_languages
    phase_projectdiscovery
    phase_recon
    phase_crawlers
    phase_fuzzers
    phase_jstools
    phase_secrets
    phase_urltools
    phase_bbot
    phase_validation
    phase_wordlists
    phase_finalize

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    success "🎯 Total installation time: ${DURATION} seconds ($((DURATION / 60)) minutes)"
    success "📝 Log file: ${LOG_FILE}"
    echo ""
    echo -e "${GREEN}Run 'source ~/.bashrc' or restart your terminal${NC}"
    echo -e "${GREEN}Then use 'bbos --help' for scanning commands${NC}"
    echo ""
}

main "$@"
#!/usr/bin/env bash
# =============================================================================
# BugBountyOS - Complete Installation Script
# Version: 1.0.0
# Author: Your Name
# Description: One-command setup for Bug Bounty Hunting Environment
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log file
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${LOG_DIR}" output reports screenshots workspace

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${msg}" | tee -a "${LOG_FILE}"
}

info()  { log "${BLUE}[INFO]${NC} $1"; }
success() { log "${GREEN}[✓]${NC} $1"; }
warn()  { log "${YELLOW}[!]${NC} $1"; }
error() { log "${RED}[✗]${NC} $1"; }

check_command() {
    if command -v "$1" &>/dev/null; then
        return 0
    fi
    return 1
}

check_version() {
    local cmd="$1"
    local label="$2"
    if check_command "${cmd}"; then
        local ver
        ver=$("${cmd}" --version 2>/dev/null || "${cmd}" -version 2>/dev/null || "${cmd}" version 2>/dev/null || echo "installed")
        success "${label}: ${ver}"
    else
        error "${label}: NOT FOUND"
    fi
}

# =============================================================================
# Phase 0: System Preparation
# =============================================================================

phase_system() {
    info "========================================"
    info "Phase 0: System Preparation"
    info "========================================"

    # Update package lists
    info "Updating package lists..."
    sudo apt-get update -qq 2>&1 | tee -a "${LOG_FILE}"

    # Install essential packages
    info "Installing essential system packages..."
    sudo apt-get install -y -qq \
        curl wget git unzip zip gzip tar \
        build-essential pkg-config libpcap-dev \
        jq whois dnsutils net-tools iputils-ping \
        nmap masscan \
        python3 python3-pip python3-venv \
        openssl ca-certificates \
        libxml2-dev libxslt1-dev \
        ripgrep fzf tmux \
        2>&1 | tee -a "${LOG_FILE}"

    success "System packages installed"
}

# =============================================================================
# Phase 1: Go & Rust Installation
# =============================================================================

phase_languages() {
    info "========================================"
    info "Phase 1: Languages (Go & Rust)"
    info "========================================"

    # Go Installation
    if ! check_command go; then
        info "Installing Go..."
        local GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -1)
        wget -q "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf /tmp/go.tar.gz
        rm -f /tmp/go.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
        export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
        success "Go ${GO_VERSION} installed"
    else
        info "Go already installed: $(go version)"
    fi

    # Rust (for some tools)
    if ! check_command cargo; then
        info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>&1 | tee -a "${LOG_FILE}"
        source "$HOME/.cargo/env"
        success "Rust installed"
    else
        info "Rust already installed: $(rustc --version)"
    fi

    # Ensure PATH
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.cargo/bin
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.cargo/bin' >> ~/.bashrc
    source ~/.bashrc 2>/dev/null || true
}

# =============================================================================
# Phase 2: ProjectDiscovery Tools (via PDTM)
# =============================================================================

phase_projectdiscovery() {
    info "========================================"
    info "Phase 2: ProjectDiscovery Tools (PDTM)"
    info "========================================"

    # Install PDTM
    if ! check_command pdtm; then
        info "Installing PDTM (ProjectDiscovery Tool Manager)..."
        go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest 2>&1 | tee -a "${LOG_FILE}"
        success "PDTM installed"
    else
        info "PDTM already installed: $(pdtm --version 2>/dev/null || echo 'latest')"
    fi

    # Install all PD tools via PDTM
    info "Installing all ProjectDiscovery tools..."
    pdtm -install-all 2>&1 | tee -a "${LOG_FILE}"
    pdtm -install-path 2>&1 | tee -a "${LOG_FILE}"

    # Install Nuclei templates
    info "Installing Nuclei templates..."
    nuclei -update-templates 2>&1 | tee -a "${LOG_FILE}"

    success "ProjectDiscovery tools installed"
    
    # Verify
    check_version "subfinder" "Subfinder"
    check_version "httpx"     "HTTPx"
    check_version "nuclei"    "Nuclei"
    check_version "naabu"     "Naabu"
    check_version "dnsx"      "DNSx"
    check_version "katana"    "Katana"
    check_version "interactsh" "Interactsh"
    check_version "pdtm"      "PDTM"
}

# =============================================================================
# Phase 3: Recon Tools
# =============================================================================

phase_recon() {
    info "========================================"
    info "Phase 3: Reconnaissance Tools"
    info "========================================"

    # Subdomain Enumeration
    if ! check_command findomain; then
        info "Installing Findomain..."
        curl -LO https://github.com/findomain/findomain/releases/latest/download/findomain-linux.zip
        unzip -q -o findomain-linux.zip -d /tmp/findomain
        sudo mv /tmp/findomain/findomain-linux /usr/local/bin/findomain
        sudo chmod +x /usr/local/bin/findomain
        rm -f findomain-linux.zip
        success "Findomain installed"
    fi

    if ! check_command amass; then
        info "Installing Amass..."
        go install -v github.com/owasp-amass/amass/v4/...@master 2>&1 | tee -a "${LOG_FILE}"
        success "Amass installed"
    fi

    if ! check_command shuffledns; then
        info "Installing ShuffleDNS..."
        go install -v github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest 2>&1 | tee -a "${LOG_FILE}"
        success "ShuffleDNS installed"
    fi

    if ! check_command alterx; then
        info "Installing alterx..."
        go install -v github.com/projectdiscovery/alterx/cmd/alterx@latest 2>&1 | tee -a "${LOG_FILE}"
        success "alterx installed"
    fi

    # Certificate Transparency
    if ! check_command crtsh; then
        info "Installing crtsh..."
        go install -v github.com/projectdiscovery/crtsh/cmd/crtsh@latest 2>&1 | tee -a "${LOG_FILE}"
        success "crtsh installed"
    fi

    # HTTP Probing
    if ! check_command httprobe; then
        info "Installing httprobe..."
        go install -v github.com/tomnomnom/httprobe@latest 2>&1 | tee -a "${LOG_FILE}"
        success "httprobe installed"
    fi

    # DNS Tools
    if ! check_command puredns; then
        info "Installing puredns..."
        go install -v github.com/d3mondev/puredns/v2@latest 2>&1 | tee -a "${LOG_FILE}"
        success "puredns installed"
    fi
    
    success "Recon tools installation completed"
    
    # Verify
    check_version "findomain"  "Findomain"
    check_version "amass"      "Amass"
    check_version "shuffledns" "ShuffleDNS"
    check_version "httprobe"   "httprobe"
}

# =============================================================================
# Phase 4: Crawlers
# =============================================================================

phase_crawlers() {
    info "========================================"
    info "Phase 4: Crawlers"
    info "========================================"

    if ! check_command gospider; then
        info "Installing GoSpider..."
        go install -v github.com/jaeles-project/gospider@latest 2>&1 | tee -a "${LOG_FILE}"
        success "GoSpider installed"
    fi

    if ! check_command hakrawler; then
        info "Installing Hakrawler..."
        go install -v github.com/hakluke/hakrawler@latest 2>&1 | tee -a "${LOG_FILE}"
        success "Hakrawler installed"
    fi

    success "Crawlers installation completed"
    check_version "gospider"   "GoSpider"
    check_version "hakrawler"  "Hakrawler"
}

# =============================================================================
# Phase 5: Fuzzers
# =============================================================================

phase_fuzzers() {
    info "========================================"
    info "Phase 5: Fuzzers"
    info "========================================"

    if ! check_command ffuf; then
        info "Installing FFUF..."
        go install -v github.com/ffuf/ffuf/v2@latest 2>&1 | tee -a "${LOG_FILE}"
        success "FFUF installed"
    fi

    if ! check_command dirsearch; then
        info "Installing Dirsearch..."
        git clone --depth 1 https://github.com/maurosoria/dirsearch.git /tmp/dirsearch 2>&1 | tee -a "${LOG_FILE}"
        sudo ln -sf /tmp/dirsearch/dirsearch.py /usr/local/bin/dirsearch 2>/dev/null || true
        sudo chmod +x /tmp/dirsearch/dirsearch.py
        success "Dirsearch installed"
    fi

    if ! check_command gobuster; then
        info "Installing GoBuster..."
        go install -v github.com/OJ/gobuster/v3@latest 2>&1 | tee -a "${LOG_FILE}"
        success "GoBuster installed"
    fi

    success "Fuzzers installation completed"
    check_version "ffuf"      "FFUF"
    check_version "gobuster"  "GoBuster"
}

# =============================================================================
# Phase 6: JavaScript Tools
# =============================================================================

phase_jstools() {
    info "========================================"
    info "Phase 6: JavaScript Analysis Tools"
    info "========================================"

    if ! check_command subjs; then
        info "Installing subjs..."
        go install -v github.com/lc/subjs@latest 2>&1 | tee -a "${LOG_FILE}"
        success "subjs installed"
    fi

    if ! check_command nuclei; then
        info "Nuclei already installed, updating JS-related templates..."
        nuclei -update-templates 2>&1 | tee -a "${LOG_FILE}"
    fi

    # LinkFinder for JS endpoints
    if [ ! -d "/opt/linkfinder" ]; then
        info "Installing LinkFinder..."
        sudo git clone --depth 1 https://github.com/GerbenJavado/LinkFinder.git /opt/linkfinder 2>&1 | tee -a "${LOG_FILE}"
        sudo pip3 install -r /opt/linkfinder/requirements.txt 2>&1 | tee -a "${LOG_FILE}"
        sudo ln -sf /opt/linkfinder/linkfinder.py /usr/local/bin/linkfinder
        sudo chmod +x /opt/linkfinder/linkfinder.py
        success "LinkFinder installed"
    fi

    if ! check_command getJS; then
        info "Installing getJS..."
        go install -v github.com/003random/getJS@latest 2>&1 | tee -a "${LOG_FILE}"
        success "getJS installed"
    fi

    success "JavaScript tools installation completed"
    check_version "subjs"  "subjs"
    check_version "getJS"  "getJS"
}

# =============================================================================
# Phase 7: Secret Discovery
# =============================================================================

phase_secrets() {
    info "========================================"
    info "Phase 7: Secret Discovery"
    info "========================================"

    if ! check_command trufflehog; then
        info "Installing TruffleHog..."
        pip3 install trufflehog 2>&1 | tee -a "${LOG_FILE}"
        success "TruffleHog installed"
    fi

    if ! check_command gitleaks; then
        info "Installing Gitleaks..."
        go install -v github.com/gitleaks/gitleaks/v8@latest 2>&1 | tee -a "${LOG_FILE}"
        success "Gitleaks installed"
    fi

    success "Secret discovery tools installed"
    check_version "trufflehog" "TruffleHog"
    check_version "gitleaks"   "Gitleaks"
}

# =============================================================================
# Phase 8: URL & Param Tools
# =============================================================================

phase_urltools() {
    info "========================================"
    info "Phase 8: URL & Parameter Tools"
    info "========================================"

    if ! check_command gau; then
        info "Installing gau..."
        go install -v github.com/lc/gau/v2/cmd/gau@latest 2>&1 | tee -a "${LOG_FILE}"
        success "gau installed"
    fi

    if ! check_command waybackurls; then
        info "Installing waybackurls..."
        go install -v github.com/tomnomnom/waybackurls@latest 2>&1 | tee -a "${LOG_FILE}"
        success "waybackurls installed"
    fi

    if ! check_command qsreplace; then
        info "Installing qsreplace..."
        go install -v github.com/tomnomnom/qsreplace@latest 2>&1 | tee -a "${LOG_FILE}"
        success "qsreplace installed"
    fi

    if ! check_command unfurl; then
        info "Installing unfurl..."
        go install -v github.com/tomnomnom/unfurl@latest 2>&1 | tee -a "${LOG_FILE}"
        success "unfurl installed"
    fi

    if ! check_command gf; then
        info "Installing gf..."
        go install -v github.com/tomnomnom/gf@latest 2>&1 | tee -a "${LOG_FILE}"
        # Install gf patterns
        git clone --depth 1 https://github.com/1ndianl33t/Gf-Patterns.git /tmp/gf-patterns 2>&1 | tee -a "${LOG_FILE}"
        mkdir -p ~/.gf
        cp /tmp/gf-patterns/*.json ~/.gf/ 2>/dev/null || true
        success "gf installed with patterns"
    fi

    success "URL & Parameter tools installed"
    check_version "gau"         "gau"
    check_version "waybackurls" "waybackurls"
    check_version "qsreplace"   "qsreplace"
    check_version "unfurl"      "unfurl"
}

# =============================================================================
# Phase 9: BBOT Installation
# =============================================================================

phase_bbot() {
    info "========================================"
    info "Phase 9: BBOT (Bighuge BLS OSINT Tool)"
    info "========================================"

    if ! check_command bbot; then
        info "Installing BBOT..."
        pip3 install bbot 2>&1 | tee -a "${LOG_FILE}"
        success "BBOT installed"
    else
        info "BBOT already installed: $(bbot --version 2>&1 | head -1)"
    fi

    check_version "bbot" "BBOT"
}

# =============================================================================
# Phase 10: Validation & Additional Tools
# =============================================================================

phase_validation() {
    info "========================================"
    info "Phase 10: Validation & Additional Tools"
    info "========================================"

    # Install pipx if not present
    if ! check_command pipx; then
        pip3 install pipx 2>&1 | tee -a "${LOG_FILE}"
        python3 -m pipx ensurepath 2>&1 | tee -a "${LOG_FILE}"
        export PATH="$HOME/.local/bin:$PATH"
    fi

    if ! check_command arjun; then
        info "Installing Arjun (Param Brute-forcer)..."
        pipx install arjun 2>&1 | tee -a "${LOG_FILE}"
        success "Arjun installed"
    fi

    success "Validation tools installed"
}

# =============================================================================
# Phase 11: Setup Wordlists
# =============================================================================

phase_wordlists() {
    info "========================================"
    info "Phase 11: Wordlists Setup"
    info "========================================"

    mkdir -p wordlists

    # Download common wordlists if not present
    if [ ! -f "wordlists/common.txt" ]; then
        info "Downloading common wordlists..."
        wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt -O wordlists/common.txt 2>&1 | tee -a "${LOG_FILE}"
        wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-medium-directories.txt -O wordlists/raft-medium.txt 2>&1 | tee -a "${LOG_FILE}"
        wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-5000.txt -O wordlists/subdomains-top.txt 2>&1 | tee -a "${LOG_FILE}"
        success "Wordlists downloaded"
    else
        info "Wordlists already exist"
    fi
}

# =============================================================================
# Phase 12: Cleanup & Finalization
# =============================================================================

phase_finalize() {
    info "========================================"
    info "Phase 12: Finalization"
    info "========================================"

    # Clean up Go cache
    go clean -cache 2>/dev/null || true

    # Source bashrc
    source ~/.bashrc 2>/dev/null || true

    # Final PATH setup
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin:$HOME/.cargo/bin
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin:$HOME/.cargo/bin' >> ~/.bashrc

    # Create symlinks for tools
    sudo ln -sf "$HOME/go/bin"/* /usr/local/bin/ 2>/dev/null || true

    success "========================================"
    success "✅ BugBountyOS Installation COMPLETE!"
    success "========================================"
    
    # Final verification
    info "Final verification of key tools:"
    for tool in subfinder httpx nuclei naabu dnsx katana ffuf gospider gau waybackurls bbot; do
        check_version "$tool" "$tool"
    done
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              BugBountyOS Installer v1.0              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""

    START_TIME=$(date +%s)

    phase_system
    phase_languages
    phase_projectdiscovery
    phase_recon
    phase_crawlers
    phase_fuzzers
    phase_jstools
    phase_secrets
    phase_urltools
    phase_bbot
    phase_validation
    phase_wordlists
    phase_finalize

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    success "🎯 Total installation time: ${DURATION} seconds ($((DURATION / 60)) minutes)"
    success "📝 Log file: ${LOG_FILE}"
    echo ""
    echo -e "${GREEN}Run 'source ~/.bashrc' or restart your terminal${NC}"
    echo -e "${GREEN}Then use 'bbos --help' for scanning commands${NC}"
    echo ""
}

main "$@"
