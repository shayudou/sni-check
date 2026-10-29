#!/usr/bin/env bash
# onebox SNI checker extracted from install.sh
# Only scans Reality SNI candidates; it does not install or manage onebox.
set -euo pipefail

REGION=all
CATEGORIES=all
CUSTOM_HOSTS=""
SAMPLES=3
TIMEOUT=5
JOBS=8
MANUAL_SNI=""
BEST_ONLY=0

usage() {
    cat <<'USAGE'
用法: sni-check.sh [选项]

选项:
  -r, --region REGION    all/global/us/eu/jp/hk/sg/cn/au/kr
  -c, --category CATS    all 或逗号分隔的 cdn,cloud,tech,fin,edu,media,social,gaming,ecom,region
  --hosts LIST           自定义域名/HTTPS 网址列表，空格或逗号分隔
  --samples N            每站测试次数 1-5，默认 3
  --timeout N            单次请求超时秒数 1-15，默认 5
  --jobs N               并发上限 1-16，默认 8
  --sni DOMAIN           直接输出指定 SNI，不做扫描
  --best-only            只输出排名第一的 SNI
  --quick                等价于 --category cdn,cloud,tech
  -h, --help             显示帮助
USAGE
}

die() {
    printf '[错误] %s\n' "$1" >&2
    exit "${2:-1}"
}

require_number_in_range() {
    local value="$1" name="$2" min="$3" max="$4"
    [[ "$value" =~ ^[1-9][0-9]*$ ]] || die "$name 必须是 1-$max 的整数。"
    [ "$value" -ge "$min" ] && [ "$value" -le "$max" ] || die "$name 必须在 $min-$max 之间。"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -r|--region) [ "$#" -ge 2 ] || die "$1 缺少值。" 2; REGION="$2"; shift 2 ;;
        -c|--category) [ "$#" -ge 2 ] || die "$1 缺少值。" 2; CATEGORIES="$2"; shift 2 ;;
        --hosts) [ "$#" -ge 2 ] || die "$1 缺少值。" 2; CUSTOM_HOSTS="$2"; shift 2 ;;
        --samples) [ "$#" -ge 2 ] || die "$1 缺少值。" 2; SAMPLES="$2"; shift 2 ;;
        --timeout) [ "$#" -ge 2 ] || die "$1 缺少值。" 2; TIMEOUT="$2"; shift 2 ;;
        --jobs) [ "$#" -ge 2 ] || die "$1 缺少值。" 2; JOBS="$2"; shift 2 ;;
        --sni) [ "$#" -ge 2 ] || die "$1 缺少值。" 2; MANUAL_SNI="$2"; shift 2 ;;
        --best-only) BEST_ONLY=1; shift ;;
        --quick) REGION=all; CATEGORIES=cdn,cloud,tech; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "未知参数：$1" 2 ;;
    esac
done

require_number_in_range "$SAMPLES" "--samples" 1 5
require_number_in_range "$TIMEOUT" "--timeout" 1 15
require_number_in_range "$JOBS" "--jobs" 1 16

valid_host() {
    local value="$1"
    [ "${#value}" -le 253 ] || return 1
    [[ "$value" =~ ^[A-Za-z0-9.-]+$ && "$value" != .* && "$value" != *. && "$value" != *..* ]] || return 1
    local -a labels=()
    IFS=. read -r -a labels <<< "$value"
    local label
    for label in "${labels[@]}"; do
        [ "${#label}" -le 63 ] && [[ "$label" != -* && "$label" != *- ]] || return 1
    done
}

reality_sni_allowed_host() {
    valid_host "$1" || return 1
    case "${1,,}" in
        apple.com|*.apple.com|icloud.com|*.icloud.com|mzstatic.com|*.mzstatic.com) return 1 ;;
    esac
}

normalize_reality_sni_hosts() {
    local input="${1//,/ }" host
    local -a entries=()
    local -A seen=()
    input="${input//$'\n'/ }"
    read -r -a entries <<< "$input"
    [ "${#entries[@]}" -ge 1 ] && [ "${#entries[@]}" -le 256 ] || die "自定义列表需要 1-256 个域名。"
    for host in "${entries[@]}"; do
        host="${host,,}"
        host="${host#https://}"; host="${host#http://}"
        host="${host%%[/?#]*}"; host="${host%:443}"; host="${host%.}"
        reality_sni_allowed_host "$host" || die "SNI 格式无效或属于排除的 Apple 域名：$host"
        if [ -z "${seen[$host]:-}" ]; then
            printf '%s\n' "$host"
            seen[$host]=1
        fi
    done
}

reality_sni_catalog() {
    cat <<'EOF'
cdn global addons.mozilla.org
cdn global www.python.org
cloud global aws.amazon.com
cloud global azure.microsoft.com
cloud global www.digitalocean.com
cloud global gitlab.com
cloud global registry.npmjs.org
cloud global www.jsdelivr.com
cloud global www.vercel.com
cloud global www.netlify.com
cloud global www.oracle.com
cloud global www.ibm.com
tech global www.amd.com
tech global www.intel.com
tech global www.nvidia.com
tech global www.qualcomm.com
tech global www.arm.com
tech global www.tesla.com
tech kr www.samsung.com
tech global www.sony.com
tech kr www.lg.com
tech global www.dell.com
tech global www.hp.com
tech global www.lenovo.com
tech global www.cisco.com
tech global www.adobe.com
fin global www.paypal.com
fin global www.visa.com
fin global www.mastercard.com
fin global www.americanexpress.com
fin global www.stripe.com
fin global www.jpmorgan.com
fin global www.goldmansachs.com
fin global www.hsbc.com
fin global www.citi.com
fin global www.blackrock.com
edu us www.mit.edu
edu us www.stanford.edu
edu us www.harvard.edu
edu us www.berkeley.edu
edu us www.cornell.edu
edu us www.princeton.edu
edu us www.yale.edu
edu us www.columbia.edu
edu eu www.ox.ac.uk
edu eu www.cam.ac.uk
edu eu www.imperial.ac.uk
edu eu www.ethz.ch
edu eu www.epfl.ch
edu jp www.u-tokyo.ac.jp
edu jp www.kyoto-u.ac.jp
edu sg www.nus.edu.sg
edu sg www.ntu.edu.sg
edu hk www.hku.hk
edu hk www.hkust.edu.hk
edu cn www.tsinghua.edu.cn
edu cn www.pku.edu.cn
edu au www.unimelb.edu.au
edu us www.utoronto.ca
media global www.imdb.com
social global www.wordpress.com
social global www.snapchat.com
gaming global www.epicgames.com
gaming global www.riotgames.com
gaming global www.ea.com
gaming global www.ubisoft.com
gaming global www.playstation.com
gaming global www.nintendo.com
gaming global www.xbox.com
gaming global www.blizzard.com
ecom global www.ebay.com
ecom global www.walmart.com
ecom global www.target.com
ecom global www.bestbuy.com
ecom global www.shopify.com
ecom cn www.alibaba.com
ecom eu www.ikea.com
ecom global www.nike.com
ecom eu www.adidas.com
ecom eu www.zara.com
region jp www.lovelive-anime.jp
region jp www.yahoo.co.jp
region jp www.ana.co.jp
region eu www.mercedes-benz.com
region eu www.bmw.com
region eu www.audi.com
region eu www.lufthansa.com
region sg www.singaporeair.com
region hk www.cathaypacific.com
region au www.qantas.com
region global www.salesforce.com
EOF
}

valid_reality_sni_region() {
    case "$1" in
        all|global|us|eu|jp|hk|sg|cn|au|kr) return 0 ;;
        *) return 1 ;;
    esac
}

valid_reality_sni_categories() {
    local key input="${1//,/ }"
    local -a keys=()
    input="${input//$'\n'/ }"
    read -r -a keys <<< "$input"
    [ "${#keys[@]}" -gt 0 ] || return 1
    for key in "${keys[@]}"; do
        case "$key" in
            all|cdn|cloud|tech|fin|edu|media|social|gaming|ecom|region) ;;
            *) return 1 ;;
        esac
    done
}

reality_sni_candidates() {
    local area="${1:-all}" categories="${2:-all}" custom="${3:-}"
    valid_reality_sni_region "$area" || die "无效的地区：$area"
    valid_reality_sni_categories "$categories" || die "无效的分类：$categories"
    if [ -n "$custom" ]; then
        normalize_reality_sni_hosts "$custom"
        return
    fi
    reality_sni_catalog | awk -v area="$area" -v cats="${categories//,/ }" '
      BEGIN { n = split(cats, keys, /[[:space:]]+/); for (i = 1; i <= n; i++) selected[keys[i]] = 1 }
      (area == "all" || $2 == "global" || $2 == area) &&
      (selected["all"] || selected[$1]) && !seen[$3]++ { print $3 }'
}

check_curl_features() {
    local line version="" major minor backend="" features=""
    sni_curl_certinfo=0
    command -v curl >/dev/null 2>&1 || die "缺少 curl。"
    CURL_SSL_BACKEND=openssl curl -q --version > "$TMP_DIR/curl-version" 2>/dev/null || die "无法读取 curl 版本。"
    while IFS= read -r line; do
            case "$line" in
                curl\ *) version="${line#curl }"; version="${version%% *}"; backend="$line" ;;
            Features:*) features="${line#Features:}" ;;
        esac
    done < "$TMP_DIR/curl-version"
    IFS=. read -r major minor _ <<< "$version"
    [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]] || die "无法解析 curl 版本。"
    if [ "$major" -lt 7 ] || { [ "$major" -eq 7 ] && [ "$minor" -lt 73 ]; }; then
        die "需要 curl >= 7.73。"
    fi
    [[ "$backend" == *OpenSSL* ]] || die "需要 OpenSSL TLS 后端的 curl。"
    [[ "$features" == *HTTP2* ]] || die "需要支持 HTTP/2 的 curl。"
    if [ "$major" -gt 7 ] || { [ "$major" -eq 7 ] && [ "$minor" -ge 88 ]; }; then
        sni_curl_certinfo=1
    fi
}

probe_reality_sni() {
    local host="$1" samples="${2:-3}" limit="${3:-5}"
    local payload verify http elapsed chain
    local round whole fraction current best_chain=0 ms=2147483647 format
    reality_sni_allowed_host "$host" || return 1
    format='%{ssl_verify_result}\t%{http_version}\t%{time_appconnect}\t0'
    [ "${sni_curl_certinfo:-0}" != 1 ] || format='%{ssl_verify_result}\t%{http_version}\t%{time_appconnect}\t%{num_certs}'
    for ((round = 0; round < samples; round++)); do
        if ! payload=$(LC_ALL=C CURL_SSL_BACKEND=openssl exec curl -q --noproxy '*' -sS --connect-timeout "$limit" --max-time "$limit" \
            --http2 --tlsv1.3 --tls-max 1.3 --curves X25519 --head \
            --output /dev/null --write-out "$format" "https://$host/"); then
            [ "$round" -gt 0 ] || return 1
            continue
        fi
        IFS=$'\t' read -r verify http elapsed chain <<< "$payload"
        if [ "$verify" != 0 ] || [ "$http" != 2 ] || ! [[ "$elapsed" =~ ^[0-9]+\.[0-9]+$ && "$chain" =~ ^[0-9]+$ ]] ||
           { [ "${sni_curl_certinfo:-0}" = 1 ] && [ "$chain" = 0 ]; }; then
            [ "$round" -gt 0 ] || return 1
            continue
        fi
        whole="${elapsed%%.*}"
        fraction="${elapsed#*.}0000"
        current=$((10#$whole * 1000 + 10#${fraction:0:3} + (10#${fraction:3:1} >= 5)))
        [ "$current" -gt 0 ] || current=1
        [ "$current" -ge "$ms" ] || ms="$current"
        [ "$chain" -le "$best_chain" ] || best_chain="$chain"
    done
    [ "$ms" != 2147483647 ] || return 1
    printf '%s\t%s\n' "$ms" "$best_chain"
}

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/sni-check.XXXXXX") || die "无法创建临时目录。"
trap 'rm -rf "$TMP_DIR"' EXIT

check_curl_features

if [ -n "$MANUAL_SNI" ]; then
    reality_sni_allowed_host "$MANUAL_SNI" || die "SNI 格式无效或属于排除的 Apple 域名：$MANUAL_SNI"
    printf '%s\n' "$MANUAL_SNI"
    exit 0
fi

mapfile -t candidates < <(reality_sni_candidates "$REGION" "$CATEGORIES" "$CUSTOM_HOSTS")
[ "${#candidates[@]}" -gt 0 ] || die "没有可选 SNI 候选，请调整地区或分类。"

printf '检测 %s 个候选（地区=%s，分类=%s）...\n' \
    "${#candidates[@]}" "$REGION" "$CATEGORIES" >&2

: > "$TMP_DIR/results"
for host in "${candidates[@]}"; do
    while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do
        wait -n || true
    done
    (
        result=$(probe_reality_sni "$host" "$SAMPLES" "$TIMEOUT") || exit 1
        IFS=$'\t' read -r score chain <<< "$result"
        tier=0
        [ "$chain" -le 3 ] || tier=1
        [ "$chain" != 0 ] || tier=2
        printf '%s\t%s\t%s\t%s\n' "$tier" "$score" "$chain" "$host"
    ) >> "$TMP_DIR/results" 2> "$TMP_DIR/error-${host//[^A-Za-z0-9._-]/_}" &
done
wait

matched_count=$(wc -l < "$TMP_DIR/results")
if [ "$matched_count" -eq 0 ]; then
    die "没有候选通过 SNI 检测。"
fi

ranked=$(LC_ALL=C sort -k1,1n -k2,2n -k4,4 "$TMP_DIR/results")
best_host=$(printf '%s\n' "$ranked" | awk -F '\t' 'NR == 1 { print $4 }')

if [ "$BEST_ONLY" = 1 ]; then
    printf '%s\n' "$best_host"
    exit 0
fi

printf '通过 %s/%s。候选 SNI（短证书链优先，同组按多次 TCP/TLS 建连最小耗时排序）：\n' \
    "$matched_count" "${#candidates[@]}"

while IFS=$'\t' read -r tier score chain host; do
    result="约 $score ms"
    [ "$score" != 2147483647 ] || result='耗时未测得'
    answer='短链'
    case "$tier" in
        1) answer='长链备选，需验证兼容性' ;;
        2) answer='链长度未知，需验证兼容性'; chain='未知' ;;
    esac
    printf ' %s) %s（%s，链 %s 层，%s）\n' \
        "$(printf '%s\n' "$ranked" | awk -F '\t' -v h="$host" '$4 == h { print NR; exit }')" \
        "$host" "$result" "$chain" "$answer"
done <<< "$ranked"

printf '\n最佳 SNI：%s\n' "$best_host"
