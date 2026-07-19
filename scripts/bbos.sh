#!/usr/bin/env bash
# =============================================================================
# BugBountyOS - All-in-One Deep Scan Engine
# Usage: ./bbos.sh -d example.com [options]
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
NC='\033[0m'

# Default values
OUTPUT_DIR="output"
THREADS=50
DEPTH=3
SCAN_MODE="full"
DOMAIN=""

# Parse arguments
usage() {
    echo "Usage: $0 -d <domain> [-m <mode>] [-t <threads>] [-o <output_dir>]"
    echo ""
    echo "Modes:"
    echo "  full      - Complete recon + vuln scan (default)"
    echo "  recon     - Subdomain + URL discovery only"
    echo "  vuln      - Vulnerability scanning only"
    echo "  quick     - Fast scan (subdomains + nuclei critical)"
    echo "  stealth   - Passive only (no direct traffic to target)"
    echo "  js        - JavaScript analysis only"
    echo "  secrets   - Secret discovery only"
    echo ""
    echo "Examples:"
    echo "  $0 -d example.com -m full"
    echo "  $0 -d example.com -m quick -t 100"
    exit 1
}

while getopts "d:m:t:o:h" opt; do
    case $opt in
        d) DOMAIN="$OPTARG" ;;
        m) SCAN_MODE="$OPTARG" ;;
        t) THREADS="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}❌ Error: Domain is required${NC}"
    usage
fi

# Create output directories
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SCAN_DIR="${OUTPUT_DIR}/${DOMAIN}/${TIMESTAMP}"
mkdir -p "${SCAN_DIR}"/{subdomains,urls,js,vulns,secrets,screenshots,reports}
LOG_FILE="${SCAN_DIR}/scan.log"

log()  { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "${LOG_FILE}"; }
success() { echo -e "${GREEN}[✓]${NC} $1" | tee -a "${LOG_FILE}"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1" | tee -a "${LOG_FILE}"; }

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║         BugBountyOS - Deep Scan Engine              ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "Target: ${GREEN}${DOMAIN}${NC}"
    echo -e "Mode:   ${YELLOW}${SCAN_MODE}${NC}"
    echo -e "Output: ${MAGENTA}${SCAN_DIR}${NC}"
    echo ""
}

# =============================================================================
# PHASE 1: Subdomain Enumeration
# =============================================================================

phase_subdomains() {
    log "──────────────────────────────────────────"
    log "📌 Phase 1: Subdomain Enumeration"
    log "──────────────────────────────────────────"

    # Passive subdomain discovery
    log "→ Passive: Subfinder"
    subfinder -d "${DOMAIN}" -silent -all -o "${SCAN_DIR}/subdomains/passive.txt" 2>&1 | tee -a "${LOG_FILE}"
    PASSIVE_COUNT=$(wc -l < "${SCAN_DIR}/subdomains/passive.txt" 2>/dev/null || echo 0)
    success "Subfinder: ${PASSIVE_COUNT} subdomains"

    # Certificate Transparency
    log "→ Passive: crtsh"
    curl -s "https://crt.sh/?q=%25.${DOMAIN}&output=json" 2>/dev/null | jq -r '.[].name_value' 2>/dev/null | sort -u >> "${SCAN_DIR}/subdomains/passive.txt" || true
    success "crtsh: completed"

    # Merge unique subdomains
    sort -u "${SCAN_DIR}/subdomains/passive.txt" -o "${SCAN_DIR}/subdomains/all.txt" 2>/dev/null
    TOTAL_SUBS=$(wc -l < "${SCAN_DIR}/subdomains/all.txt" 2>/dev/null || echo 0)
    success "Total passive subdomains: ${TOTAL_SUBS}"
}

# =============================================================================
# PHASE 2: DNS Resolution & HTTP Probing
# =============================================================================

phase_probing() {
    log "──────────────────────────────────────────"
    log "📌 Phase 2: DNS Resolution & HTTP Probing"
    log "──────────────────────────────────────────"

    # DNS Resolution with dnsx
    log "→ DNS Resolution: dnsx"
    dnsx -l "${SCAN_DIR}/subdomains/all.txt" -silent -a -aaaa -cname -o "${SCAN_DIR}/subdomains/resolved.txt" 2>&1 | tee -a "${LOG_FILE}"
    RESOLVED_COUNT=$(wc -l < "${SCAN_DIR}/subdomains/resolved.txt" 2>/dev/null || echo 0)
    success "Resolved: ${RESOLVED_COUNT} records"

    # Extract unique resolved subdomains
    awk '{print $1}' "${SCAN_DIR}/subdomains/resolved.txt" | sort -u > "${SCAN_DIR}/subdomains/alive.txt"

    # HTTP Probing with httpx
    log "→ HTTP Probing: httpx"
    httpx -l "${SCAN_DIR}/subdomains/alive.txt" -silent \
        -title -tech-detect -status-code -content-length \
        -web-server -ip -cdn \
        -o "${SCAN_DIR}/subdomains/live.txt" \
        -csv "${SCAN_DIR}/subdomains/live.csv" \
        -threads "${THREADS}" 2>&1 | tee -a "${LOG_FILE}"
    LIVE_COUNT=$(wc -l < "${SCAN_DIR}/subdomains/live.txt" 2>/dev/null || echo 0)
    success "Live hosts: ${LIVE_COUNT}"

    # Extract just the URLs for later phases
    awk '{print $1}' "${SCAN_DIR}/subdomains/live.txt" > "${SCAN_DIR}/urls/live-urls.txt"
}

# =============================================================================
# PHASE 3: URL Discovery (Archives + Crawling)
# =============================================================================

phase_url_discovery() {
    log "──────────────────────────────────────────"
    log "📌 Phase 3: URL Discovery"
    log "──────────────────────────────────────────"

    # Wayback URLs
    if check_command waybackurls; then
        log "→ Archive: waybackurls"
        cat "${SCAN_DIR}/subdomains/live.txt" | awk '{print $1}' | waybackurls 2>/dev/null | sort -u > "${SCAN_DIR}/urls/wayback.txt" || true
        WB_COUNT=$(wc -l < "${SCAN_DIR}/urls/wayback.txt" 2>/dev/null || echo 0)
        success "Wayback Machine: ${WB_COUNT} URLs"
    fi

    # GAU (getallurls)
    if check_command gau; then
        log "→ Archive: gau"
        gau --subs "${DOMAIN}" --threads "${THREADS}" -o "${SCAN_DIR}/urls/gau.txt" 2>/dev/null || true
        GAU_COUNT=$(wc -l < "${SCAN_DIR}/urls/gau.txt" 2>/dev/null || echo 0)
        success "GAU: ${GAU_COUNT} URLs"
    fi

    # Katana crawling (if not stealth mode)
    if [ "${SCAN_MODE}" != "stealth" ]; then
        log "→ Crawling: Katana"
        katana -u "https://${DOMAIN}" -silent -d "${DEPTH}" \
            -kf all -jc -aff \
            -ef png,jpg,gif,svg,ico,css,woff,woff2,ttf,eot,mp4,mp3,pdf,zip,tar,gz \
            -rl 150 -c 50 -p 30 \
            -o "${SCAN_DIR}/urls/katana.txt" 2>&1 | tee -a "${LOG_FILE}" || true
        KATANA_COUNT=$(wc -l < "${SCAN_DIR}/urls/katana.txt" 2>/dev/null || echo 0)
        success "Katana crawled: ${KATANA_COUNT} URLs"
    fi

    # Merge all URLs
    cat "${SCAN_DIR}/urls/"*.txt 2>/dev/null | sort -u > "${SCAN_DIR}/urls/all-urls.txt"
    TOTAL_URLS=$(wc -l < "${SCAN_DIR}/urls/all-urls.txt" 2>/dev/null || echo 0)
    success "Total unique URLs: ${TOTAL_URLS}"
}

# =============================================================================
# PHASE 4: Parameter Discovery
# =============================================================================

phase_params() {
    log "──────────────────────────────────────────"
    log "📌 Phase 4: Parameter Discovery"
    log "──────────────────────────────────────────"

    # Extract parameters from URLs
    log "→ Extracting parameters from URLs..."
    cat "${SCAN_DIR}/urls/all-urls.txt" 2>/dev/null | grep -E '\?' | sort -u > "${SCAN_DIR}/urls/param-urls.txt"
    PARAM_COUNT=$(wc -l < "${SCAN_DIR}/urls/param-urls.txt" 2>/dev/null || echo 0)
    success "URLs with params: ${PARAM_COUNT}"

    # Extract unique params
    cat "${SCAN_DIR}/urls/param-urls.txt" 2>/dev/null | unfurl -keys 2>/dev/null | sort -u > "${SCAN_DIR}/urls/params.txt" || true
    success "Unique parameters extracted"

    # Arjun parameter bruteforce (if installed)
    if check_command arjun && [ "${SCAN_MODE}" != "stealth" ] && [ "${SCAN_MODE}" != "quick" ]; then
        log "→ Arjun parameter bruteforce (first 10 live hosts)..."
        head -10 "${SCAN_DIR}/urls/live-urls.txt" 2>/dev/null | while read url; do
            arjun -u "${url}" -oJ -oT "${SCAN_DIR}/urls/arjun-$(echo ${url} | md5sum | cut -d' ' -f1).txt" 2>/dev/null || true
        done
        success "Arjun completed"
    fi
}

# =============================================================================
# PHASE 5: JavaScript Analysis
# =============================================================================

phase_js() {
    log "──────────────────────────────────────────"
    log "📌 Phase 5: JavaScript Analysis"
    log "──────────────────────────────────────────"

    # Extract JS URLs
    log "→ Extracting JavaScript files..."
    grep -E '\.js' "${SCAN_DIR}/urls/all-urls.txt" 2>/dev/null | grep -vE '\.json|\.css' | sort -u > "${SCAN_DIR}/js/js-urls.txt" || true

    # Use subjs
    if check_command subjs; then
        log "→ subjs: extracting JS URLs from live hosts..."
        subjs -i "${SCAN_DIR}/urls/live-urls.txt" -o "${SCAN_DIR}/js/subjs-urls.txt" 2>/dev/null || true
        cat "${SCAN_DIR}/js/subjs-urls.txt" >> "${SCAN_DIR}/js/js-urls.txt" 2>/dev/null || true
    fi

    sort -u "${SCAN_DIR}/js/js-urls.txt" -o "${SCAN_DIR}/js/js-urls.txt" 2>/dev/null
    JS_COUNT=$(wc -l < "${SCAN_DIR}/js/js-urls.txt" 2>/dev/null || echo 0)
    success "JavaScript files found: ${JS_COUNT}"

    # Download JS files and search for secrets
    if [ "${JS_COUNT}" -gt 0 ] && [ "${SCAN_MODE}" != "stealth" ]; then
        log "→ Downloading JS files & searching for secrets..."
        mkdir -p "${SCAN_DIR}/js/downloaded"
        cat "${SCAN_DIR}/js/js-urls.txt" | head -100 | while read jsurl; do
            filename=$(echo "${jsurl}" | md5sum | cut -d' ' -f1).js
            curl -sL --connect-timeout 5 --max-time 10 "${jsurl}" -o "${SCAN_DIR}/js/downloaded/${filename}" 2>/dev/null || true
            # Search for sensitive patterns
            grep -oP '(?:api[_-]?key|apikey|secret|token|password|aws[_-]?(?:key|secret)|access[_-]?key|auth|jwt|bearer)[=:]["'"'"']?[^\s&"'"'"',;]+' "${SCAN_DIR}/js/downloaded/${filename}" 2>/dev/null | sort -u >> "${SCAN_DIR}/secrets/js-secrets.txt" || true
        done
        JS_SECRETS=$(wc -l < "${SCAN_DIR}/secrets/js-secrets.txt" 2>/dev/null || echo 0)
        success "Secrets found in JS: ${JS_SECRETS}"
    fi
}

# =============================================================================
# PHASE 6: Secret Discovery
# =============================================================================

phase_secrets() {
    log "──────────────────────────────────────────"
    log "📌 Phase 6: Secret Discovery"
    log "──────────────────────────────────────────"

    # TruffleHog
    if check_command trufflehog; then
        log "→ TruffleHog scanning..."
        trufflehog filesystem --directory="${SCAN_DIR}" --no-update --json 2>/dev/null | tee "${SCAN_DIR}/secrets/trufflehog.json" > /dev/null || true
        success "TruffleHog scan completed"
    fi

    # Gitleaks
    if check_command gitleaks; then
        log "→ Gitleaks scanning..."
        gitleaks detect --source="${SCAN_DIR}" --no-git -v 2>/dev/null | tee -a "${LOG_FILE}" || true
        success "Gitleaks scan completed"
    fi

    # GF Patterns
    if check_command gf; then
        log "→ gf pattern matching..."
        for pattern in xss sqli lfi ssti ssrf idor redirect debug-pages interestingparams; do
            cat "${SCAN_DIR}/urls/all-urls.txt" 2>/dev/null | gf "${pattern}" 2>/dev/null | sort -u > "${SCAN_DIR}/vulns/gf-${pattern}.txt" || true
        done
        success "gf patterns matched"
    fi
}

# =============================================================================
# PHASE 7: Vulnerability Scanning (Nuclei)
# =============================================================================

phase_vuln_scan() {
    log "──────────────────────────────────────────"
    log "📌 Phase 7: Vulnerability Scanning (Nuclei)"
    log "──────────────────────────────────────────"

    local NUCLEI_FLAGS="-silent -stats -j -o ${SCAN_DIR}/vulns/nuclei-results.json"

    if [ "${SCAN_MODE}" = "quick" ]; then
        log "→ Quick mode: critical + high severity only"
        nuclei -l "${SCAN_DIR}/urls/live-urls.txt" ${NUCLEI_FLAGS} \
            -s critical,high -c "${THREADS}" \
            -rl 150 -stats -o "${SCAN_DIR}/vulns/nuclei-quick.json" 2>&1 | tee -a "${LOG_FILE}" || true
    elif [ "${SCAN_MODE}" = "stealth" ]; then
        log "→ Stealth mode: passive templates only"
        nuclei -l "${SCAN_DIR}/urls/live-urls.txt" ${NUCLEI_FLAGS} \
            -t ~/nuclei-templates/misconfiguration/ \
            -t ~/nuclei-templates/exposures/ \
            -c 10 -rl 30 -o "${SCAN_DIR}/vulns/nuclei-stealth.json" 2>&1 | tee -a "${LOG_FILE}" || true
    else
        log "→ Full scan: all templates"
        nuclei -l "${SCAN_DIR}/urls/live-urls.txt" ${NUCLEI_FLAGS} \
            -s critical,high,medium,low,unknown \
            -c "${THREADS}" -rl 150 \
            -o "${SCAN_DIR}/vulns/nuclei-results.json" 2>&1 | tee -a "${LOG_FILE}" || true
    fi

    # Convert JSON results to readable format
    cat "${SCAN_DIR}/vulns/nuclei-results.json" 2>/dev/null | jq -r '. | "\(.info.severity | ascii_upcase) | \(.matched-at) | \(.info.name)"' 2>/dev/null > "${SCAN_DIR}/vulns/nuclei-summary.txt" || true
    VULN_COUNT=$(wc -l < "${SCAN_DIR}/vulns/nuclei-summary.txt" 2>/dev/null || echo 0)
    success "Vulnerabilities found: ${VULN_COUNT}"
    
    # Show critical findings
    log "Critical findings:"
    cat "${SCAN_DIR}/vulns/nuclei-results.json" 2>/dev/null | jq -r 'select(.info.severity == "critical") | "\(.matched-at) - \(.info.name)"' 2>/dev/null | head -20 || true
}

# =============================================================================
# PHASE 8: Directory Fuzzing
# =============================================================================

phase_fuzzing() {
    log "──────────────────────────────────────────"
    log "📌 Phase 8: Directory Fuzzing"
    log "──────────────────────────────────────────"

    if [ "${SCAN_MODE}" = "stealth" ] || [ "${SCAN_MODE}" = "quick" ]; then
        warn "Skipping fuzzing in ${SCAN_MODE} mode"
        return
    fi

    if check_command ffuf; then
        log "→ FFUF directory fuzzing (top 5 hosts)..."
        head -5 "${SCAN_DIR}/urls/live-urls.txt" 2>/dev/null | while read url; do
            hostname=$(echo "${url}" | unfurl format '%d%:%p%' 2>/dev/null || echo "${DOMAIN}")
            ffuf -u "${url}/FUZZ" -w wordlists/common.txt \
                -t "${THREADS}" -sf -s \
                -mc 200,204,301,302,307,403,401 \
                -o "${SCAN_DIR}/vulns/ffuf-${hostname}.json" \
                -of json 2>/dev/null || true
        done
        success "FFUF fuzzing completed"
    fi
}

# =============================================================================
# PHASE 9: BBOT Deep Scan
# =============================================================================

phase_bbot_scan() {
    log "──────────────────────────────────────────"
    log "📌 Phase 9: BBOT Deep Recon"
    log "──────────────────────────────────────────"

    if check_command bbot && [ "${SCAN_MODE}" != "quick" ]; then
        local BBOT_FLAGS=""
        if [ "${SCAN_MODE}" = "stealth" ]; then
            BBOT_FLAGS="-m passive"
        else
            BBOT_FLAGS="-m subdomain-enum -s -c 50"
        fi

        log "→ Running BBOT (this may take a while)..."
        bbot -t "${DOMAIN}" ${BBOT_FLAGS} \
            -o "${SCAN_DIR}/reports/bbot" \
            --force 2>&1 | tee -a "${LOG_FILE}" || true
        success "BBOT scan completed"
    else
        warn "BBOT not installed or skipped"
    fi
}

# =============================================================================
# PHASE 10: Report Generation
# =============================================================================

phase_report() {
    log "──────────────────────────────────────────"
    log "📌 Phase 10: Report Generation"
    log "──────────────────────────────────────────"

    local REPORT_FILE="${SCAN_DIR}/reports/summary.md"

    {
        echo "# BugBountyOS Scan Report"
        echo "## Target: ${DOMAIN}"
        echo "## Date: $(date)"
        echo "## Mode: ${SCAN_MODE}"
        echo ""
        echo "## Summary"
        echo ""
        
        echo "### Subdomains"
        echo "- Passive: $(wc -l < ${SCAN_DIR}/subdomains/passive.txt 2>/dev/null || echo 0)"
        echo "- Resolved: $(wc -l < ${SCAN_DIR}/subdomains/alive.txt 2>/dev/null || echo 0)"
        echo "- Live HTTP: $(wc -l < ${SCAN_DIR}/urls/live-urls.txt 2>/dev/null || echo 0)"
        echo ""
        
        echo "### URLs"
        echo "- Total URLs: $(wc -l < ${SCAN_DIR}/urls/all-urls.txt 2>/dev/null || echo 0)"
        echo "- With Parameters: $(wc -l < ${SCAN_DIR}/urls/param-urls.txt 2>/dev/null || echo 0)"
        echo "- JS Files: $(wc -l < ${SCAN_DIR}/js/js-urls.txt 2>/dev/null || echo 0)"
        echo ""
        
        echo "### Vulnerabilities"
        if [ -f "${SCAN_DIR}/vulns/nuclei-results.json" ]; then
            echo "- Critical: $(jq 'select(.info.severity == "critical")' ${SCAN_DIR}/vulns/nuclei-results.json 2>/dev/null | grep -c 'severity' || echo 0)"
            echo "- High: $(jq 'select(.info.severity == "high")' ${SCAN_DIR}/vulns/nuclei-results.json 2>/dev/null | grep -c 'severity' || echo 0)"
            echo "- Medium: $(jq 'select(.info.severity == "medium")' ${SCAN_DIR}/vulns/nuclei-results.json 2>/dev/null | grep -c 'severity' || echo 0)"
            echo "- Low: $(jq 'select(.info.severity == "low")' ${SCAN_DIR}/vulns/nuclei-results.json 2>/dev/null | grep -c 'severity' || echo 0)"
        fi
        echo ""
        
        echo "### Top Live Hosts"
        head -20 "${SCAN_DIR}/subdomains/live.txt" 2>/dev/null | while read line; do
            echo "- ${line}"
        done
        
    } > "${REPORT_FILE}"
    
    success "Report generated: ${REPORT_FILE}"
    
    # Also show live hosts with technology
    log "Live hosts with technologies:"
    cat "${SCAN_DIR}/subdomains/live.csv" 2>/dev/null | head -10 || true
}

# =============================================================================
# Main Execution Router
# =============================================================================

main() {
    show_banner
    START_TIME=$(date +%s)

    case "${SCAN_MODE}" in
        recon)
            phase_subdomains
            phase_probing
            phase_url_discovery
            ;;
        vuln)
            phase_url_discovery
            phase_vuln_scan
            ;;
        js)
            phase_url_discovery
            phase_js
            phase_secrets
            ;;
        secrets)
            phase_url_discovery
            phase_js
            phase_secrets
            ;;
        stealth)
            phase_subdomains
            phase_probing
            phase_url_discovery
            phase_vuln_scan
            ;;
        quick)
            phase_subdomains
            phase_probing
            phase_vuln_scan
            ;;
        full|*)
            phase_subdomains
            phase_probing
            phase_url_discovery
            phase_params
            phase_js
            phase_secrets
            phase_vuln_scan
            phase_fuzzing
            phase_bbot_scan
            ;;
    esac

    phase_report

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    echo ""
    success "========================================"
    success "✅ Scan Complete!"
    echo ""
    success "📁 Output Directory: ${SCAN_DIR}"
    success "📄 Report: ${SCAN_DIR}/reports/summary.md"
    success "⏱️  Duration: $((DURATION / 60)) min $((DURATION % 60)) sec"
    success "========================================"
}

# Check for required tools
check_command() { command -v "$1" &>/dev/null; }

main "$@"
