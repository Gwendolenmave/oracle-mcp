# Local recovery controller

The local controller runs the same `oci-cloud-mcp-server` over stdio from the same fork. It is the independent rescue path when the Virginia-hosted HTTP MCP is unavailable or the VPS is stopped.

## Requirements

- a local clone of `Gwendolenmave/oracle-mcp`;
- `uv` and Python 3.13;
- a private OCI CLI-compatible profile, for example `AMELIA_OPERATOR`;
- its private key or session token outside the repository.

## Sync dependencies

From the repository root:

```bash
uv sync --project src/oci-cloud-mcp-server --frozen
```

## MCP client template

Copy `mcp.local.example.json` into the local MCP client's configuration and replace `<ABSOLUTE_PATH_TO_FORK>`.

For Windows, use an escaped absolute path such as `C:\\Users\\Gwen\\oracle-mcp`.

## Recovery invariant

The local profile must remain independently usable. Do not make its authentication depend on the Virginia VPS, the remote MCP hostname, or a file stored only on that VPS.

Before any self-affecting remote action, prove that the local controller can:

1. read the Virginia instance;
2. call `instance_action` with a harmless or reversible action when appropriate;
3. start the VPS after a controlled soft-stop test.
