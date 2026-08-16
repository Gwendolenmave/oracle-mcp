#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo $0 /opt/oracle-mcp" >&2
  exit 1
fi

repo_root="${1:-/opt/oracle-mcp}"
project_dir="${repo_root}/src/oci-cloud-mcp-server"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${project_dir}/pyproject.toml" ]]; then
  echo "Could not find ${project_dir}/pyproject.toml" >&2
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required and must be on PATH before installation." >&2
  exit 1
fi

uv_path="$(command -v uv)"
if [[ "${uv_path}" != "/usr/local/bin/uv" ]]; then
  install -m 0755 "${uv_path}" /usr/local/bin/uv
fi

if ! id oracle-mcp >/dev/null 2>&1; then
  useradd --system --home /var/lib/oracle-mcp --create-home --shell /usr/sbin/nologin oracle-mcp
fi

install -d -o oracle-mcp -g oracle-mcp -m 0700 \
  /var/lib/oracle-mcp \
  /var/lib/oracle-mcp/venv \
  /var/cache/oracle-mcp

if [[ ! -f /etc/oracle-oci-cloud-mcp.env ]]; then
  install -o root -g root -m 0600 \
    "${script_dir}/oracle-oci-cloud-mcp.env.example" \
    /etc/oracle-oci-cloud-mcp.env
  echo "Created /etc/oracle-oci-cloud-mcp.env from the public-safe template."
  echo "Fill real values before starting the service."
fi

install -o root -g root -m 0644 \
  "${script_dir}/oracle-oci-cloud-mcp.service" \
  /etc/systemd/system/oracle-oci-cloud-mcp.service

chown -R oracle-mcp:oracle-mcp /var/lib/oracle-mcp /var/cache/oracle-mcp

sudo -u oracle-mcp env \
  HOME=/var/lib/oracle-mcp \
  UV_PROJECT_ENVIRONMENT=/var/lib/oracle-mcp/venv \
  UV_CACHE_DIR=/var/cache/oracle-mcp \
  /usr/local/bin/uv sync --project "${project_dir}" --frozen

systemctl daemon-reload

echo "Installed dependencies and systemd unit."
echo "Next: edit /etc/oracle-oci-cloud-mcp.env, configure Caddy, run validate-config.sh, then enable the service."
