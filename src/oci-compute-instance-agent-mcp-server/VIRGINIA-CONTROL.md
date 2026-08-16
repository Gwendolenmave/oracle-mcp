# Virginia VPS dual-path control

This fork uses Oracle's existing OCI MCP servers as a two-path control plane for one OCI compute instance.

## Goal

- ChatGPT can inspect OCI resources and run maintenance commands on the Virginia VPS while the VPS is online.
- A local MCP path remains available from Gwen's computer for recovery if the Virginia VPS is stopped or its remote endpoint is unavailable.
- Both paths use the same Oracle MCP source tree; secrets and tenancy-specific OCIDs never enter Git.

## Why two paths

A remote MCP hosted on the Virginia VPS can manage the instance while it is running, but it cannot receive a future request after that same VPS has been stopped. The local stdio path is therefore the recovery key that can start or repair the remote host.

```text
                         OCI control plane
                                |
               +----------------+----------------+
               |                                 |
     Virginia remote MCP                 Gwen local MCP
     Streamable HTTP                     stdio
     ChatGPT control path                recovery / Codex path
     systemd + HTTPS                     local OCI profile
               |                                 |
               +------------- same fork ----------+
```

## What already exists upstream

### OCI Cloud MCP

`oci-cloud-mcp-server` is a generic wrapper around OCI Python SDK clients. Its `invoke_oci_api` tool can call OCI SDK operations allowed by the authenticated OCI principal. This is the control-plane path for instance lifecycle, monitoring, networking, volumes, IAM and other OCI services.

### OCI Compute Instance Agent MCP

`oci-compute-instance-agent-mcp-server` exposes `run_instance_agent_command` and `list_instance_agent_command_executions`. `run_instance_agent_command` creates an OCI Compute Instance Agent Run Command and waits for its execution result.

Run Command is the preferred guest-OS maintenance path because it does not require exposing a new shell endpoint from the VPS. Long-running software should still be installed as `systemd` services rather than kept alive by a single Run Command invocation.

## OCI identity model

Use a dedicated OCI user/group for Amelia and Codex rather than reusing the account owner's ordinary console login. If full tenancy authority is intentionally desired, the policy can be:

```text
Allow group AmeliaOperators to manage all-resources in tenancy
```

For a non-default identity domain, qualify the group name with the domain.

The dedicated identity remains independently revocable and auditable even when it has full authority.

## Remote HTTP path

The official HTTP transport expects an OCI IAM Identity Domains confidential application and these environment variables:

- `ORACLE_MCP_HOST`
- `ORACLE_MCP_PORT`
- `ORACLE_MCP_BASE_URL`
- `OCI_REGION`
- `IDCS_DOMAIN`
- `IDCS_CLIENT_ID`
- `IDCS_CLIENT_SECRET`
- `IDCS_AUDIENCE`
- optionally `IDCS_REQUIRED_SCOPES`

Register this redirect URI in the confidential application:

```text
${ORACLE_MCP_BASE_URL}/auth/callback
```

Bind the MCP process to loopback and put an HTTPS reverse proxy in front of it. Real values belong in a root-owned environment file on the VPS, never in this public repository.

## Guest OS control with Run Command

The instance must have Oracle Cloud Agent installed and the Compute Instance Run Command plugin enabled.

A dynamic group should identify the Virginia instance, for example:

```text
instance.id = '<VIRGINIA_INSTANCE_OCID>'
```

The dynamic group needs the permissions required for command execution. The operator identity needs authority to create and inspect instance-agent commands; full `manage all-resources` already includes this.

On Linux, Run Command executes as the `ocarun` user. If unrestricted root maintenance is intentionally desired, configure `/etc/sudoers.d/101-oracle-cloud-agent-run-command` on the instance:

```text
ocarun ALL=(ALL) NOPASSWD:ALL
```

Then validate the file with `visudo -cf` and mode `0440`.

This is remote-root authority. Enable it only after the remote MCP endpoint is protected by HTTPS and authenticated access.

## First control proof

Do not begin with a destructive OCI action. First prove the complete path with a harmless command:

```bash
id
hostname
date -Is
```

Success proves:

1. ChatGPT -> remote MCP
2. MCP -> OCI API
3. OCI Run Command -> Virginia guest OS
4. command output -> ChatGPT

After that, use Run Command to install durable `systemd` services for Delos, Mnemosyne, runners or other long-lived workers.

## Local recovery path

The same server can run over stdio from Gwen's computer using a private OCI CLI-compatible profile. Keep the API private key and OCI config outside this repository.

The local path is required even after remote control works. If the Virginia instance is stopped, the remote MCP disappears with it; the local path can still call OCI to start or repair the instance.

See `deploy/local/mcp.local.example.json`.

## Secret boundary

Safe to commit publicly:

- systemd unit templates
- Caddy/reverse-proxy templates
- environment variable names
- IAM policy templates
- placeholder OCIDs
- architecture and recovery documentation

Never commit:

- `IDCS_CLIENT_SECRET`
- OCI API private keys
- `~/.oci/config`
- session/security tokens
- real `.env` files
- private DNS/API tokens

Recommended remote secret file:

```text
/etc/oracle-oci-compute-agent-mcp.env
```

with owner/mode:

```bash
sudo chown root:root /etc/oracle-oci-compute-agent-mcp.env
sudo chmod 600 /etc/oracle-oci-compute-agent-mcp.env
```

## Deployment order

1. Keep this fork building unchanged.
2. Create the dedicated OCI operator identity/group and intended policy.
3. Create the Identity Domains confidential application.
4. Put real secrets only in `/etc/oracle-oci-compute-agent-mcp.env` on the VPS.
5. Install the systemd unit from `deploy/virginia/`.
6. Put HTTPS in front of the loopback listener.
7. Connect ChatGPT to the remote MCP endpoint.
8. Confirm a read-only OCI operation.
9. Enable/configure Compute Instance Run Command and its IAM/dynamic-group policy.
10. Run the harmless proof command above.
11. Install useful long-running services through `systemd`.
12. Configure and test the independent local stdio recovery path.

## Source hardening still needed

The current `server.py` should be hardened in a later code change before production use:

- migrate duplicated credential/token-exchange logic to `oracle-mcp-common` as required by this repository's `AGENTS.md`;
- handle terminal Run Command failure/cancel/timeout states explicitly instead of waiting only for `SUCCEEDED`;
- separate command creation from long polling for long-running jobs;
- keep the existing 90% unit-test coverage requirement;
- update README tool names to match the actual exported tools.

Those source changes should be implemented with tests rather than mixed into the initial deployment wiring.