# SwaggerHub Portal Management Script

This script (`run-portal-management.sh`) automates deployment, validation, and publishing of products and content to a SwaggerHub Portal instance. It is designed to be used both locally and in CI/CD pipelines (including GitHub Actions).

## Features

- Spell check Markdown files
- Validate product manifests against a JSON schema
- Lint APIs referenced in manifests
- Publish content to SwaggerHub Portal

## Requirements

- Bash (macOS/Linux)
- Node.js and npm (for installing CLI tools)
- jq (for JSON processing)
- cspell, ajv-cli, swaggerhub-cli (installed automatically if missing)

## Usage

```sh
./run-portal-management.sh [options]
```

### Options

| Option                      | Description                                                        |
|-----------------------------|--------------------------------------------------------------------|
| --api-key <key>             | SwaggerHub API Key (or set SWAGGERHUB_API_KEY env var)              |
| --portal-subdomain <sub>    | SwaggerHub Portal subdomain (or set SWAGGERHUB_PORTAL_SUBDOMAIN)    |
| --org-name <org>            | SwaggerHub organization name (or set SWAGGERHUB_ORG_NAME)           |
| --log-level <level>         | Log level (1=DEBUG, 2=INFO, 3=WARNING, 4=ERROR) [default: 2]        |
| --skip-spell-check          | Skip spell check step                                               |
| --skip-api-linting          | Skip API linting step                                               |
| --publish                   | Publish content to SwaggerHub Portal                                |
| --product-folder <path>     | Path to products folder [default: products]                         |
| --custom-words-file <path>  | Path to custom words file for spell checking                        |
| -h, --help                  | Show help message                                                   |

You can also set the following environment variables instead of passing options:

- `SWAGGERHUB_API_KEY`
- `SWAGGERHUB_PORTAL_SUBDOMAIN`
- `SWAGGERHUB_ORG_NAME`

## Examples

### Basic validation and spell check

```sh
./run-portal-management.sh \
  --api-key <your-api-key> \
  --portal-subdomain mycompany \
  --org-name myorg
```

### Skip spell check and API linting

```sh
./run-portal-management.sh --skip-spell-check --skip-api-linting ...
```

### Publish content

```sh
./run-portal-management.sh --publish ...
```

### Use a custom products folder and custom words file

```sh
./run-portal-management.sh --product-folder path/to/products --custom-words-file path/to/custom-words.txt ...
```

## Exit Codes

- 0: Success
- 1: Error (missing input, validation failure, etc.)

## Notes

- The script will install required npm packages globally if they are not already installed.
- The script sources `scripts/utilities.sh` for logging and helper functions.
- For publishing, the script sources `scripts/publish-portal-content.sh`.

## License

See [LICENSE](./LICENSE).
