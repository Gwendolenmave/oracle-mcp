# Virginia control recipes

These are SDK-shaped payloads for the generic `oci-cloud-mcp-server` tools. Replace placeholders at call time; never commit real OCIDs.

The normal workflow is:

1. Call `describe_oci_operation` when the installed OCI SDK contract is uncertain.
2. Call `invoke_oci_api` with the client, operation, and params below.
3. Use `fields` to keep responses compact when only a few values are needed.

## Read the Virginia instance

```json
{
  "client_fqn": "oci.core.ComputeClient",
  "operation": "get_instance",
  "params": {
    "instance_id": "<VIRGINIA_INSTANCE_OCID>"
  },
  "fields": [
    "id",
    "display_name",
    "lifecycle_state",
    "shape",
    "shape_config",
    "time_created",
    "freeform_tags",
    "defined_tags"
  ]
}
```

## Start, soft-stop, or reboot

Use `START`, `SOFTSTOP`, or `SOFTRESET` for the action.

```json
{
  "client_fqn": "oci.core.ComputeClient",
  "operation": "instance_action",
  "params": {
    "instance_id": "<VIRGINIA_INSTANCE_OCID>",
    "action": "START"
  },
  "fields": ["id", "display_name", "lifecycle_state"]
}
```

A remote MCP hosted on this instance disappears during stop/reboot. Use the local stdio recovery path to start it again.

## Check the Run Command plugin

```json
{
  "client_fqn": "oci.compute_instance_agent.PluginClient",
  "operation": "get_instance_agent_plugin",
  "params": {
    "instanceagent_id": "<VIRGINIA_INSTANCE_OCID>",
    "compartment_id": "<COMPARTMENT_OCID>",
    "plugin_name": "Compute Instance Run Command"
  },
  "result_mode": "full"
}
```

If the plugin name differs in the installed SDK/region, call `list_instance_agent_plugins` and inspect the returned names.

## Harmless guest-OS proof

Create the command:

```json
{
  "client_fqn": "oci.compute_instance_agent.ComputeInstanceAgentClient",
  "operation": "create_instance_agent_command",
  "params": {
    "create_instance_agent_command_details": {
      "__model_fqn": "oci.compute_instance_agent.models.CreateInstanceAgentCommandDetails",
      "compartment_id": "<COMPARTMENT_OCID>",
      "display_name": "amelia-proof-of-control",
      "execution_time_out_in_seconds": 300,
      "target": {
        "__model_fqn": "oci.compute_instance_agent.models.InstanceAgentCommandTarget",
        "instance_id": "<VIRGINIA_INSTANCE_OCID>"
      },
      "content": {
        "__model_fqn": "oci.compute_instance_agent.models.InstanceAgentCommandContent",
        "source": {
          "__model_fqn": "oci.compute_instance_agent.models.InstanceAgentCommandSourceViaTextDetails",
          "source_type": "TEXT",
          "text": "id\nhostname\ndate -Is\n"
        },
        "output": {
          "__model_fqn": "oci.compute_instance_agent.models.InstanceAgentCommandOutputViaTextDetails",
          "output_type": "TEXT"
        }
      }
    }
  },
  "fields": ["id", "display_name", "time_created", "is_canceled"],
  "result_mode": "full"
}
```

Retain the returned command OCID and read execution status:

```json
{
  "client_fqn": "oci.compute_instance_agent.ComputeInstanceAgentClient",
  "operation": "get_instance_agent_command_execution",
  "params": {
    "instance_agent_command_id": "<COMMAND_OCID>",
    "instance_id": "<VIRGINIA_INSTANCE_OCID>"
  },
  "result_mode": "full"
}
```

Treat `SUCCEEDED`, `FAILED`, `TIMED_OUT`, and `CANCELED` as terminal outcomes. Do not wait only for `SUCCEEDED`.

## Cancel a command

```json
{
  "client_fqn": "oci.compute_instance_agent.ComputeInstanceAgentClient",
  "operation": "cancel_instance_agent_command",
  "params": {
    "instance_agent_command_id": "<COMMAND_OCID>"
  },
  "result_mode": "full"
}
```

Cancellation is best-effort.

## List recent executions

```json
{
  "client_fqn": "oci.compute_instance_agent.ComputeInstanceAgentClient",
  "operation": "list_instance_agent_command_executions",
  "params": {
    "compartment_id": "<COMPARTMENT_OCID>",
    "instance_id": "<VIRGINIA_INSTANCE_OCID>",
    "sort_by": "TIMECREATED",
    "sort_order": "DESC",
    "limit": 20
  },
  "max_results": 20,
  "result_mode": "full"
}
```

## Query CPU metrics

First call `describe_oci_operation` for:

```text
client_fqn = oci.monitoring.MonitoringClient
operation  = summarize_metrics_data
```

Then invoke it with a `SummarizeMetricsDataDetails` request. A typical query uses the `oci_computeagent` namespace and a query such as `CpuUtilization[1m].mean()`. Exact time fields and query syntax should be generated against the installed SDK contract rather than frozen into this public deployment template.

## Install a persistent service through Run Command

For long work, the command should create files and a systemd unit, call `systemctl daemon-reload`, and enable/start that unit. Do not keep a long-running process attached to one Run Command request.

Before granting root, confirm HTTPS, OAuth, and the local recovery controller. Then intentionally configure the Oracle Cloud Agent Run Command user:

```text
/etc/sudoers.d/101-oracle-cloud-agent-run-command
```

```text
ocarun ALL=(ALL) NOPASSWD:ALL
```

Validate the sudoers file with `visudo -cf` and mode `0440`. This grants remote root authority to the OCI Run Command path and must be treated as such.
