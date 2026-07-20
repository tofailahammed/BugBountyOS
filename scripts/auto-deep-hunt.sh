#!/usr/bin/env bash
# =============================================================================
# BugBountyOS - Autonomous Deep Hunting Engine v2.0
# Usage: ./scripts/auto-deep-hunt.sh -d target.com [-o output] [-t threads]
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

DOMAIN="${1:-}"; OUTPUT_DIR="${2:-output}"; THREADS=100; DEPTH=3

usage() { echo "Usage: $0 -d <domain> [-o <dir>] [-t <threads>]"; echo "Ex: $0 -d ipsy.com"; exit 1; }
while getopts "d:o:t:h" opt; do case $opt in d) DOMAIN="$OPTARG";; o) OUTPUT_DIR="$OPTARG";; t) THREADS="$OPTARG";; h) usage;; *) usage;; esac; done
[ -z "$DOMAIN" ] && { echo -e "${RED}Error: Domain required${NC}"; usage; }

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SCAN_DIR="${OUTPUT_DIR}/${DOMAIN}/${TIMESTAMP}"
mkdir -p "${SCAN_DIR}"/{subdomains,urls,js,vulns,secrets,screenshots,reports,exploit,logs}
LOG_FILE="${SCAN_DIR}/logs/master.log"

log()  { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "${LOG_FILE}"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1" | tee -a "${LOG_FILE}"; }
warn() { echo -e "${YELLOW}[!]${NC} $1" | tee -a "${LOG_FILE}"; }
section() { echo "" | tee -a "${LOG_FILE}"; echo -e "${CYAN}══════════════════════════════════════════════════════${NC}" | tee -a "${LOG_FILE}"; echo -e "${CYAN}  $1${NC}" | tee -a "${LOG_FILE}"; echo -e "${CYAN}══════════════════════════════════════════════════════${NC}" | tee -a "${LOG_FILE}"; echo "" | tee -a "${LOG_FILE}"; }

# ─── PHASE 0: SYSTEM FIX ───
phase_fix() {
    section "PHASE 0: System Fix & Tool Verification"
    pip3 uninstall httpx -y 2>/dev/null || true
    sudo rm -f /usr/local/bin/httpx 2>/dev/null || true
    for tool in httpx dnsx nuclei subfinder katana ffuf; do
        [ -f "$HOME/go/bin/$tool" ] && sudo ln -sf "$HOME/go/bin/$tool" "/usr/local/bin/$tool" 2>/dev/null || true
    done
    if ! command -v gf &>/dev/null; then
        go install github.com/tomnomnom/gf@latest 2>/dev/null
        sudo cp ~/go/bin/gf /usr/local/bin/ 2>/dev/null || true
        git clone --depth 1 https://github.com/1ndianl33t/Gf-Patterns.git /tmp/gf-patterns 2>/dev/null || true
        mkdir -p ~/.gf && cp /tmp/gf-patterns/*.json ~/.gf/ 2>/dev/null || true
    fi
    nuclei -update-templates 2>/dev/null || true
    for t in httpx dnsx nuclei subfinder katana ffuf gf gau waybackurls; do
        command -v "$t" &>/dev/null && ok "$t found" || warn "$t missing"
    done
}

# ─── PHASE 1: SUBDOMAINS ───
phase_subdomains() {
    section "PHASE 1: Subdomain Enumeration"
    subfinder -d "$DOMAIN" -silent -all -recursive -o "$SCAN_DIR/subdomains/subfinder.txt" 2>>"$LOG_FILE" || true
    ok "Subfinder: $(wc -l <$SCAN_DIR/subdomains/subfinder.txt 2>/dev/null||echo 0)"
    curl -s "https://crt.sh/?q=%25.${DOMAIN}&output=json" 2>/dev/null | jq -r '.[].name_value' 2>/dev/null | sort -u > "$SCAN_DIR/subdomains/crtsh.txt" || true
    chaos -d "$DOMAIN" -silent -o "$SCAN_DIR/subdomains/chaos.txt" 2>/dev/null || true
    amass enum -passive -d "$DOMAIN" -o "$SCAN_DIR/subdomains/amass.txt" 2>/dev/null || true
    findomain -t "$DOMAIN" -q -u "$SCAN_DIR/subdomains/findomain.txt" 2>/dev/null || true
    cat "$SCAN_DIR/subdomains/"*.txt 2>/dev/null | sort -u > "$SCAN_DIR/subdomains/all.txt"
    ok "Total subdomains: $(wc -l <$SCAN_DIR/subdomains/all.txt)"
}

# ─── PHASE 2: DNS + HTTP ───
phase_dns_http() {
    section "PHASE 2: DNS Resolution & HTTP Probing"
    dnsx -l "$SCAN_DIR/subdomains/all.txt" -silent -retry 3 -threads "$THREADS" -a -aaaa -cname -o "$SCAN_DIR/subdomains/resolved.txt" 2>>"$LOG_FILE" || true
    awk '{print $1}' "$SCAN_DIR/subdomains/resolved.txt" | sort -u > "$SCAN_DIR/subdomains/alive.txt"
    httpx -l "$SCAN_DIR/subdomains/alive.txt" -silent -title -tech-detect -status-code -web-server -ip -location -o "$SCAN_DIR/subdomains/live.txt" -csv "$SCAN_DIR/subdomains/live.csv" -threads "$THREADS" -retries 3 -timeout 10 2>>"$LOG_FILE" || true
    awk '{print $1}' "$SCAN_DIR/subdomains/live.txt" | sort -u > "$SCAN_DIR/urls/live-urls.txt"
    ok "Live HTTP hosts: $(wc -l <$SCAN_DIR/urls/live-urls.txt 2>/dev/null||echo 0)"
    head -30 "$SCAN_DIR/subdomains/live.txt" 2>/dev/null
}

# ─── PHASE 3: URL DISCOVERY ───
phase_urls() {
    section "PHASE 3: URL Discovery"
    [ -s "$SCAN_DIR/urls/live-urls.txt" ] && cat "$SCAN_DIR/urls/live-urls.txt" | waybackurls 2>/dev/null | sort -u > "$SCAN_DIR/urls/wayback.txt" || true
    gau --subs "$DOMAIN" --threads 50 -o "$SCAN_DIR/urls/gau.txt" 2>/dev/null || true
    head -3 "$SCAN_DIR/urls/live-urls.txt" 2>/dev/null | while read url; do
        katana -u "$url" -silent -d 3 -jc -kf all -ef png,jpg,gif,svg,ico,css,woff,woff2 -rl 200 -c 100 -o "$SCAN_DIR/urls/katana-$(echo $url|md5sum|cut -d' ' -f1).txt" 2>/dev/null || true
    done
    cat "$SCAN_DIR/urls/"*.txt 2>/dev/null | grep -E '^https?://' | sort -u > "$SCAN_DIR/urls/all-urls.txt"
    ok "Total URLs: $(wc -l <$SCAN_DIR/urls/all-urls.txt 2>/dev/null||echo 0)"
}

# ─── PHASE 4: NUCLEI SCAN ───
phase_nuclei() {
    section "PHASE 4: Vulnerability Scanning (Nuclei)"
    [ ! -s "$SCAN_DIR/urls/live-urls.txt" ] && { warn "No targets"; return; }
    nuclei -l "$SCAN_DIR/urls/live-urls.txt" -s critical,high,medium,low -c 100 -rl 300 -j -o "$SCAN_DIR/vulns/nuclei-full.json" 2>&1 | tail -5 || true
    if [ -f "$SCAN_DIR/vulns/nuclei-full.json" ]; then
        cat "$SCAN_DIR/vulns/nuclei-full.json" | jq -r '"\(.info.severity|ascii_upcase) | \(.matched-at) | \(.info.name)"' 2>/dev/null > "$SCAN_DIR/vulns/nuclei-summary.txt"
        cat "$SCAN_DIR/vulns/nuclei-full.json" | jq -r 'select(.info.severity=="critical" or .info.severity=="high") | "\(.info.severity|ascii_upcase) | \(.matched-at) | \(.info.name)"' 2>/dev/null > "$SCAN_DIR/vulns/critical-high.txt"
        ok "Vulns: $(wc -l <$SCAN_DIR/vulns/nuclei-summary.txt)"
        ok "Critical/High: $(wc -l <$SCAN_DIR/vulns/critical-high.txt)"
        [ -s "$SCAN_DIR/vulns/critical-high.txt" ] && cat "$SCAN_DIR/vulns/critical-high.txt"
    fi
}

# ─── PHASE 5: GF PATTERNS ───
phase_gf() {
    section "PHASE 5: GF Pattern Matching"
    [ ! -s "$SCAN_DIR/urls/all-urls.txt" ] && { warn "No URLs"; return; }
    for p in xss sqli lfi ssti ssrf idor redirect debug-pages interestingparams rce; do
        cat "$SCAN_DIR/urls/all-urls.txt" 2>/dev/null | gf "$p" 2>/dev/null | sort -u > "$SCAN_DIR/vulns/gf-$p.txt" || true
        c=$(wc -l <"$SCAN_DIR/vulns/gf-$p.txt" 2>/dev/null||echo 0)
        [ "$c" -gt 0 ] && echo "  [$p] $c"
    done
}

# ─── PHASE 6: JS ANALYSIS ───
phase_js() {
    section "PHASE 6: JavaScript Analysis"
    grep -E '\.js' "$SCAN_DIR/urls/all-urls.txt" 2>/dev/null | grep -vE '\.json|\.css' > "$SCAN_DIR/js/js-urls.txt" || true
    [ -s "$SCAN_DIR/urls/live-urls.txt" ] && subjs -i "$SCAN_DIR/urls/live-urls.txt" -o "$SCAN_DIR/js/subjs-urls.txt" 2>/dev/null || true
    cat "$SCAN_DIR/js/subjs-urls.txt" >> "$SCAN_DIR/js/js-urls.txt" 2>/dev/null || true
    sort -u "$SCAN_DIR/js/js-urls.txt" -o "$SCAN_DIR/js/js-urls.txt" 2>/dev/null
    ok "JS files: $(wc -l <$SCAN_DIR/js/js-urls.txt 2>/dev/null||echo 0)"
    mkdir -p "$SCAN_DIR/js/downloaded"
    cat "$SCAN_DIR/js/js-urls.txt" 2>/dev/null | head -100 | while read jsurl; do
        f=$(echo "$jsurl"|md5sum|cut -d' ' -f1).js
        curl -sL --connect-timeout 10 --max-time 20 "$jsurl" -o "$SCAN_DIR/js/downloaded/$f" 2>/dev/null || true
        grep -oP '(?:api[_-]?key|apikey|secret|token|password|access[_-]?key|auth|jwt|bearer|firebase|aws[_-]?(?:key|secret)|AKIA[0-9A-Z]{16}|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36,}|eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,})[=:][\x27\x22]?[^\s&\x27\x22,;)]+' "$SCAN_DIR/js/downloaded/$f" 2>/dev/null >> "$SCAN_DIR/secrets/js-secrets.txt" || true
    done
    sort -u "$SCAN_DIR/secrets/js-secrets.txt" -o "$SCAN_DIR/secrets/js-secrets.txt" 2>/dev/null
    ok "Secrets: $(wc -l <$SCAN_DIR/secrets/js-secrets.txt 2>/dev/null||echo 0)"
    [ -s "$SCAN_DIR/secrets/js-secrets.txt" ] && cat "$SCAN_DIR/secrets/js-secrets.txt"
}

# ─── PHASE 7: TRUFFLEHOG ───
phase_trufflehog() {
    section "PHASE 7: Secret Scanning"
    command -v trufflehog &>/dev/null && trufflehog filesystem --directory="$SCAN_DIR" --no-update --json --only-verified 2>/dev/null | jq -r '"\(.DetectorName) | \(.SourceMetadata.Data.URL // .SourceMetadata.Data.Filename) | \(.RawV2 // .Raw)"' > "$SCAN_DIR/secrets/trufflehog-results.txt" 2>/dev/null || true
    ok "TruffleHog done"
}

# ─── PHASE 8: FFUF ───
phase_ffuf() {
    section "PHASE 8: Directory Fuzzing"
    [ ! -s "$SCAN_DIR/urls/live-urls.txt" ] && { warn "No targets"; return; }
    WL="wordlists/common.txt"; [ ! -f "$WL" ] && WL="/usr/share/wordlists/dirb/common.txt"; [ ! -f "$WL" ] && { warn "No wordlist"; return; }
    head -5 "$SCAN_DIR/urls/live-urls.txt" | while read url; do
        d=$(echo "$url"|sed 's|https\?://||'|sed 's|/.*||')
        ffuf -u "$url/FUZZ" -w "$WL" -t 100 -sf -mc 200,204,301,302,307,401,403,500 -fc 404 -o "$SCAN_DIR/vulns/ffuf-$d.json" -of json 2>/dev/null || true
        ok "FFUF $d: $(cat $SCAN_DIR/vulns/ffuf-$d.json 2>/dev/null|jq '.results|length' 2>/dev/null||echo 0)"
    done
}

# ─── PHASE 9: BBOT ───
phase_bbot() {
    section "PHASE 9: BBOT Deep Recon"
    command -v bbot &>/dev/null && bbot -t "$DOMAIN" -m subdomain-enum -s -c 100 --force -o "$SCAN_DIR/reports/bbot" 2>&1 | tail -5 || warn "BBOT not installed"
    ok "BBOT done"
}

# ─── PHASE 10: DISCLOSURE PAGE ───
phase_disclosure() {
    section "PHASE 10: Vulnerability Disclosure Page"
    local url="https://www.$DOMAIN/vulnerability-disclosure"
    echo "$url" | httpx -title -tech-detect -status-code -web-server -silent 2>/dev/null
    echo "$url" | nuclei -s critical,high,medium -c 10 -rl 50 -o "$SCAN_DIR/vulns/disclosure-nuclei.txt" 2>/dev/null || true
    ok "Disclosure page scanned"
}

# ─── PHASE 11: REPORT ───
phase_report() {
    section "PHASE 11: Bug Bounty Report"
    local R="$SCAN_DIR/reports/bug-bounty-report.md"
    {
        echo "# Bug Bounty Report: $DOMAIN"; echo "## Date: $(date)"; echo ""
        echo "## Summary"
        echo "| Metric | Count |"
        echo "|--------|-------|"
        echo "| Subdomains | $(wc -l <$SCAN_DIR/subdomains/all.txt 2>/dev/null||echo 0) |"
        echo "| Live Hosts | $(wc -l <$SCAN_DIR/urls/live-urls.txt 2>/dev/null||echo 0) |"
        echo "| URLs | $(wc -l <$SCAN_DIR/urls/all-urls.txt 2>/dev/null||echo 0) |"
        echo "| Nuclei Vulns | $(wc -l <$SCAN_DIR/vulns/nuclei-summary.txt 2>/dev/null||echo 0) |"
        echo "| Secrets | $(wc -l <$SCAN_DIR/secrets/js-secrets.txt 2>/dev/null||echo 0) |"
        echo ""
        echo "## Critical/High Vulnerabilities"
        [ -s "$SCAN_DIR/vulns/critical-high.txt" ] && (echo '```'; cat "$SCAN_DIR/vulns/critical-high.txt"; echo '```') || echo "*None*"
        echo ""
        echo "## Potential XSS Vectors"
        [ -s "$SCAN_DIR/vulns/gf-xss.txt" ] && (echo '```'; head -30 "$SCAN_DIR/vulns/gf-xss.txt"; echo '```') || echo "*None*"
        echo ""
        echo "## Secrets Found"
        [ -s "$SCAN_DIR/secrets/js-secrets.txt" ] && (echo '```'; cat "$SCAN_DIR/secrets/js-secrets.txt"; echo '```') || echo "*None*"
        echo ""
        echo "## Live Hosts"
        echo '```'; head -30 "$SCAN_DIR/subdomains/live.txt" 2>/dev/null; echo '```'
        echo ""
        echo "*BugBountyOS v2.0 Autonomous Engine*"
    } > "$R"
    ok "Report: $R"
}

# ─── MAIN ───
clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  BugBountyOS - Autonomous Deep Hunting Engine v2.0 ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo "Target: $DOMAIN | Output: $SCAN_DIR"
START=$(date +%s)

phase_fix
phase_subdomains
phase_dns_http
phase_urls
phase_nuclei
phase_gf
phase_js
phase_trufflehog
phase_ffuf
phase_bbot
phase_disclosure
phase_report

END=$(date +%s); D=$(( (END-START)/60 ))
echo ""; echo -e "${GREEN}✅ Scan Complete in ${D} min${NC}"
echo -e "${CYAN}📁${NC} $SCAN_DIR"
echo -e "${CYAN}📄${NC} $SCAN_DIR/reports/bug-bounty-report.md"
[ -s "$SCAN_DIR/vulns/critical-high.txt" ] && echo -e "${RED}🔴 Critical Vulns:${NC}" && cat "$SCAN_DIR/vulns/critical-high.txt"