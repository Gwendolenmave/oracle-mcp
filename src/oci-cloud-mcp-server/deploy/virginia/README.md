# Virginia dual-path OCI control

This deployment uses Oracle's existing `oci-cloud-mcp-server` as the single control surface for the Virginia VPS.

The generic server is sufficient: `invoke_oci_api` can call public OCI Python SDK client methods, including Compute lifecycle operations, Monitoring queries, and Compute Instance Agent Run Commands. No separate shell MCP or SSH bridge is required.

## Topology

```text
ChatGPT / Amelia
        |
        | OAuth + HTTPS
        v
Virginia VPS: oci-cloud-mcp-server (HTTP, systemd)
        |
        +--> OCI control plane
              +--> inspect/start/stop/update the instance
              +--> read monitoring and volume/network state
              +--> issue Compute Instance Agent Run Commands

Gwen's computer: same oci-cloud-mcp-server (stdio)
        |
        +--> independent OCI profile used as the recovery controller
```

The local stdio controller is essential. A remote MCP hosted on the Virginia VPS cannot start itself after the instance is stopped. The local controller remains able to call OCI and start or repair the VPS.

## Secret boundary

The files in this directory contain no real OCIDs, private keys, client secrets, tokens, account names, or DNS credentials. Real values belong only in `/etc/oracle-oci-cloud-mcp.env` on the VPS and in the user's private local OCI configuration.

## Deployment gates

The deployment is ready for live setup when all of these are true:

1. `uv sync --frozen` completes for `src/oci-cloud-mcp-server`.
2. The private environment file passes `validate-config.sh`.
3. The OCI Identity Domains confidential application has the callback URI registered.
4. Caddy has a valid certificate for the MCP hostname.
5. An unauthenticated caller cannot invoke MCP tools.
6. ChatGPT can read the Virginia instance through `invoke_oci_api`.
7. A harmless Run Command (`id`, `hostname`, `date -Is`) succeeds.
8. The local stdio recovery controller can read the same instance and perform a reversible lifecycle test.

## Install order

1. Point a DNS name, such as `mcp.example.com`, at the Virginia VPS public IP.
2. Create an OCI Identity Domains confidential application for the remote MCP.
3. Grant the authenticated operator identity the intended OCI IAM permissions.
4. Clone this fork to `/opt/oracle-mcp` on the VPS.
5. Run `sudo deploy/virginia/install.sh /opt/oracle-mcp` from this server directory.
6. Edit `/etc/oracle-oci-cloud-mcp.env` with real values and mode `0600`.
7. Install the adapted Caddy configuration and validate it.
8. Run `sudo deploy/virginia/validate-config.sh`.
9. Enable and start the service.
10. Connect ChatGPT to `https://<hostname>/mcp` and complete OAuth.
11. Run the read-only and harmless write proofs in `CONTROL-RECIPES.md`.
12. Configure the local stdio path from `../local/README.md`.

## Authority model

The MCP's effective authority is the authority of the authenticated OCI principal. A dedicated operator user/group is recommended even when intentionally granting full tenancy control, because its credentials and audit trail remain independently revocable.

Example full-authority policy for the Default identity domain:

```text
Allow group AmeliaOperators to manage all-resources in tenancy
```

For another identity domain:

```text
Allow group <identity-domain-name>/AmeliaOperators to manage all-resources in tenancy
```

Do not put real domain/group names or any OCIDs in this public repository.

## Guest operating-system control

The generic Cloud MCP can call `oci.compute_instance_agent.ComputeInstanceAgentClient`. To execute Linux commands inside the instance:

- Oracle Cloud Agent must be installed and running.
- The Compute Instance Run Command plugin must be enabled.
- OCI IAM must allow the operator to manage the command family.
- The instance/dynamic group must be permitted to poll command executions.
- Commands run as `ocarun`; root control requires a deliberately installed sudoers rule.

Run Command should bootstrap or repair persistent services. Long-running Delos, Mnemosyne, runners, and MCP processes belong in systemd units rather than in one Run Command request.

## Self-affecting actions

Stopping or rebooting the Virginia instance, restarting this MCP service, changing its network, or replacing its certificate can interrupt the active ChatGPT call. That is expected. Use the local recovery path to restore service after a self-affecting action.
