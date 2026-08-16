# OCI Compute Instance Agent MCP Server

## Overview

This server provides tools for interacting with Oracle Cloud Infrastructure (OCI) Compute Instance Agent service.

## Running the server

### STDIO transport mode

```sh
uvx oracle.oci-compute-instance-agent-mcp-server
```

### HTTP streaming transport mode

```sh
ORACLE_MCP_HOST=<bind_host> \
ORACLE_MCP_PORT=<port> \
ORACLE_MCP_BASE_URL=<public_base_url> \
OCI_REGION=<region> \
IDCS_DOMAIN=<idcs_domain> \
IDCS_CLIENT_ID=<client_id> \
IDCS_CLIENT_SECRET=<client_secret> \
IDCS_AUDIENCE=<audience> \
uvx oracle.oci-compute-instance-agent-mcp-server
```

Register `${ORACLE_MCP_BASE_URL}/auth/callback` in the OCI IAM confidential application. If `IDCS_REQUIRED_SCOPES` is unset, the default is `openid profile email oci_mcp.compute_instance_agent.invoke`.

## Tools

| Tool Name | Description |
| --- | --- |
| `run_instance_agent_command` | Create a Run Command for a compute instance and return the execution result |
| `list_instance_agent_command_executions` | List Run Command executions for a compute instance |

The exported tool names above match the current `server.py` implementation.

⚠️ **NOTE**: `stdio` uses the configured OCI CLI profile. HTTP uses the authenticated OCI IAM user and does not use the local OCI CLI profile for request authentication.

## Virginia dual-path deployment

This fork includes a deployment design for running this MCP as a continuously available remote control path on an OCI VPS while keeping an independent local stdio recovery path.

See [`VIRGINIA-CONTROL.md`](./VIRGINIA-CONTROL.md) and the templates under [`deploy/`](./deploy/).

No real OCIDs, private keys, tokens, client secrets, or `.env` files should be committed to this repository.

## Third-Party APIs

Developers choosing to distribute a binary implementation of this project are responsible for obtaining and providing all required licenses and copyright notices for the third-party code used in order to ensure compliance with their respective open source licenses.

## Disclaimer

Users are responsible for their local environment and credential safety. Different language model selections may yield different results and performance.

## License

Copyright (c) 2025 Oracle and/or its affiliates.
 
Released under the Universal Permissive License v1.0 as shown at  
<https://oss.oracle.com/licenses/upl/>.
