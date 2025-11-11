#!/usr/bin/env bash
# run-portal-management.sh
# Reusable script for SwaggerHub Portal Management
# Can be used locally or in CI/CD (including GitHub Actions)

set -euo pipefail

# Usage message
usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --api-key <key>                SwaggerHub API Key (or set SWAGGERHUB_API_KEY)
  --portal-subdomain <subdomain> SwaggerHub Portal subdomain (or set SWAGGERHUB_PORTAL_SUBDOMAIN)
  --org-name <org>               SwaggerHub organization name (or set SWAGGERHUB_ORG_NAME)
  --log-level <level>            Log level (1=DEBUG, 2=INFO, 3=WARNING, 4=ERROR) [default: 2]
  --skip-spell-check             Skip spell check step
  --skip-api-linting             Skip API linting step
  --publish                      Publish content to SwaggerHub Portal
  --product-folder <path>        Path to products folder [default: products]
  --custom-words-file <path>     Path to custom words file for spell checking
  -h, --help                     Show this help message
EOF
}

# Default values
LOG_LEVEL=2
SKIP_SPELL_CHECK=false
SKIP_API_LINTING=false
PUBLISH=false
PRODUCTS_FOLDER="products"
CUSTOM_WORDS_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --api-key)
      export SWAGGERHUB_API_KEY="$2"; shift 2;;
    --portal-subdomain)
      export SWAGGERHUB_PORTAL_SUBDOMAIN="$2"; shift 2;;
    --org-name)
      export SWAGGERHUB_ORG_NAME="$2"; shift 2;;
    --log-level)
      LOG_LEVEL="$2"; shift 2;;
    --skip-spell-check)
      SKIP_SPELL_CHECK=true; shift;;
    --skip-api-linting)
      SKIP_API_LINTING=true; shift;;
    --publish)
      PUBLISH=true; shift;;
    --product-folder)
      PRODUCTS_FOLDER="$2"; shift 2;;
    --custom-words-file)
      CUSTOM_WORDS_FILE="$2"; shift 2;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown option: $1"; usage; exit 1;;
  esac
done

# Validate required env vars
: "${SWAGGERHUB_API_KEY:?Missing --api-key or SWAGGERHUB_API_KEY env var}"
: "${SWAGGERHUB_PORTAL_SUBDOMAIN:?Missing --portal-subdomain or SWAGGERHUB_PORTAL_SUBDOMAIN env var}"
: "${SWAGGERHUB_ORG_NAME:?Missing --org-name or SWAGGERHUB_ORG_NAME env var}"

# Set up environment
export LOG_LEVEL
export PRODUCTS_FOLDER
export CUSTOM_WORDS_FILE

# Validate inputs
if [ ! -d "$PRODUCTS_FOLDER" ]; then
  echo "Product folder not found: $PRODUCTS_FOLDER" >&2
  exit 1
fi
if [ -n "$CUSTOM_WORDS_FILE" ] && [ ! -f "$CUSTOM_WORDS_FILE" ]; then
  echo "Custom words file not found: $CUSTOM_WORDS_FILE" >&2
  exit 1
fi

# Spell check markdown files
if [ "$SKIP_SPELL_CHECK" != "true" ]; then
  if ! command -v cspell >/dev/null; then
    npm install -g cspell
  fi
  CSPELL_CONFIG="$(dirname "$0")/.cspell.json"
  if [ -n "$CUSTOM_WORDS_FILE" ]; then
    echo "Using custom words file: $CUSTOM_WORDS_FILE"
    if [ ! -f "$CUSTOM_WORDS_FILE" ]; then
      echo "Custom words file not found: $CUSTOM_WORDS_FILE" >&2
      exit 1
    fi
    if ! command -v jq >/dev/null; then
      npm install -g jq
    fi
    jq --arg path "$CUSTOM_WORDS_FILE" '
      .dictionaryDefinitions = (.dictionaryDefinitions | map(
        if .name == "custom-words" then .path = $path else . end
      ))
    ' "$CSPELL_CONFIG" > "$CSPELL_CONFIG.tmp"
    mv "$CSPELL_CONFIG.tmp" "$CSPELL_CONFIG"
  fi
  cspell --config "$CSPELL_CONFIG" "$PRODUCTS_FOLDER/**/*.md"
fi

# Validate product manifests
if ! command -v ajv >/dev/null; then
  npm install -g ajv-cli
fi
. "$(dirname "$0")/scripts/utilities.sh"
for product in "$PRODUCTS_FOLDER"/*; do
  if [[ -d "$product" ]]; then
    product_name=${product#$PRODUCTS_FOLDER/}
    manifest="$PRODUCTS_FOLDER/$product_name/manifest.json"
    if [[ -f "$manifest" ]]; then
      log_message $INFO "Validating manifest in product: $product_name"
      log_message $DEBUG "Validating manifest: $manifest"
      ajv validate -s "$(dirname "$0")/schemas/manifest.schema.json" -d "$manifest" --spec=draft2020
    fi
  fi
done

# Lint APIs in manifests
if [ "$SKIP_API_LINTING" != "true" ]; then
  if ! command -v swaggerhub >/dev/null; then
    npm install -g swaggerhub-cli
  fi
  . "$(dirname "$0")/scripts/utilities.sh"
  for product in "$PRODUCTS_FOLDER"/*; do
    if [[ -d "$product" ]]; then
      product_name=${product#$PRODUCTS_FOLDER/}
      manifest="$PRODUCTS_FOLDER/$product_name/manifest.json"
      if [[ -f "$manifest" ]]; then
        validateAPIs=$(jq -r '.productMetadata.validateAPIs' "$manifest")
        if [[ "$validateAPIs" == "true" ]]; then
          log_message $INFO "Validating APIs for product: $product_name"
          contentMetadata=$(jq -c '.contentMetadata[] | select(.type | ascii_downcase == "apiurl")' "$manifest")
          echo "$contentMetadata" | jq -c '.' | while IFS= read -r contentMetadataItem; do
            slug=$(echo "$contentMetadataItem" | jq -r '.slug')
            log_message $INFO "Validating API: $slug"
            swaggerhub api:validate "${SWAGGERHUB_ORG_NAME}/$slug" --fail-on-critical
          done
        else
          log_message $WARNING "API validation is not enabled for product: $product_name"
        fi
      fi
    fi
  done
fi

# Publish content to SwaggerHub Portal
if [ "$PUBLISH" == "true" ]; then
  chmod +x "$(dirname "$0")/scripts/publish-portal-content.sh"
  chmod +x "$(dirname "$0")/scripts/utilities.sh"
  published_urls=()
  portal_domain="https://${SWAGGERHUB_PORTAL_SUBDOMAIN}.portal.swaggerhub.com"
  for product in "$PRODUCTS_FOLDER"/*; do
    echo "Processing: $product"
    if [[ -d "$product" ]]; then
      echo "Product is a directory"
      product_name=${product#$PRODUCTS_FOLDER/}
      echo "Product name: $product_name"
      manifest="$PRODUCTS_FOLDER/$product_name/manifest.json"
      echo "Manifest: $manifest"
      if [[ -f "$manifest" ]]; then
        echo "Manifest is a file"
        . "$(dirname "$0")/scripts/publish-portal-content.sh" && portal_product_upsert "$manifest" "$product_name"
        . "$(dirname "$0")/scripts/publish-portal-content.sh" && load_and_process_product_manifest_content_metadata "$manifest" "$product_name"
        slug=$(jq -r '.productMetadata.slug' "$manifest")
        if [[ -n "$slug" && "$slug" != "null" ]]; then
          url="${portal_domain}/${slug}"
          published_urls+=("$url")
          echo "Published URL: $url"
        fi
      else
        echo "Manifest is not a file"
      fi
    else
      echo "Product is not a directory"
    fi
  done
  # Pretty print the URLs in a table
  if [[ ${#published_urls[@]} -gt 0 ]]; then
    printf "\nPublished Portal URLs:\n"
    printf "%-3s | %-60s\n" "No" "URL"
    printf -- "----|--------------------------------------------------------------\n"
    i=1
    for url in "${published_urls[@]}"; do
      printf "%-3s | %-60s\n" "$i" "$url"
      ((i++))
    done
  else
    echo "No portal URLs were published."
  fi
fi
