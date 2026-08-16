#!/usr/bin/env bash
set -euo pipefail

env_file="${1:-/etc/oracle-oci-cloud-mcp.env}"
service_file="/etc/systemd/system/oracle-oci-cloud-mcp.service"
project_dir="/opt/oracle-mcp/src/oci-cloud-mcp-server"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -f "${env_file}" ]] || fail "Missing ${env_file}"
[[ "$(stat -c '%a' "${env_file}")" == "600" ]] || fail "${env_file} must have mode 600"
[[ -f "${service_file}" ]] || fail "Missing ${service_file}"
[[ -f "${project_dir}/pyproject.toml" ]] || fail "Missing project at ${project_dir}"

set -a
# shellcheck disable=SC1090
source "${env_file}"
set +a

required=(
  ORACLE_MCP_HOST
  ORACLE_MCP_PORT
  ORACLE_MCP_BASE_URL
  OCI_REGION
  IDCS_DOMAIN
  IDCS_CLIENT_ID
  IDCS_CLIENT_SECRET
  IDCS_AUDIENCE
)

for name in "${required[@]}"; do
  value="${!name:-}"
  [[ -n "${value}" ]] || fail "${name} is empty"
  [[ "${value}" != *"<"* && "${value}" != *">"* ]] || fail "${name} still contains a placeholder"
done

[[ "${ORACLE_MCP_HOST}" == "127.0.0.1" ]] || fail "ORACLE_MCP_HOST must remain 127.0.0.1 behind Caddy"
[[ "${ORACLE_MCP_BASE_URL}" == https://* ]] || fail "ORACLE_MCP_BASE_URL must use HTTPS"
[[ "${ORACLE_MCP_PORT}" =~ ^[0-9]+$ ]] || fail "ORACLE_MCP_PORT must be numeric"

command -v /usr/local/bin/uv >/dev/null 2>&1 || fail "uv is not installed at /usr/local/bin/uv"
/usr/local/bin/uv run \
  --project "${project_dir}" \
  --frozen \
  --no-sync \
  python -c 'import oracle.oci_cloud_mcp_server.server; print("python-import-ok")'

systemd-analyze verify "${service_file}"

echo "Configuration preflight passed."
echo "Callback URI to register: ${ORACLE_MCP_BASE_URL}/auth/callback"
echo "MCP URL for ChatGPT: ${ORACLE_MCP_BASE_URL}/mcp"
