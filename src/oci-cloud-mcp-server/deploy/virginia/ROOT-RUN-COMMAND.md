# Deliberately granting Run Command root authority

Oracle Cloud Agent's Run Command plugin executes Linux scripts as the `ocarun` user. Use the following only after the MCP endpoint is protected by HTTPS and OCI OAuth, and after the local recovery controller has been proven.

Create a temporary file:

```bash
cat >/tmp/101-oracle-cloud-agent-run-command <<'EOF'
ocarun ALL=(ALL) NOPASSWD:ALL
EOF
```

Validate and install it:

```bash
sudo chown root:root /tmp/101-oracle-cloud-agent-run-command
sudo chmod 0440 /tmp/101-oracle-cloud-agent-run-command
sudo visudo -cf /tmp/101-oracle-cloud-agent-run-command
sudo install -o root -g root -m 0440 \
  /tmp/101-oracle-cloud-agent-run-command \
  /etc/sudoers.d/101-oracle-cloud-agent-run-command
rm -f /tmp/101-oracle-cloud-agent-run-command
```

Proof command after installation:

```bash
sudo -n id
```

Expected effective identity:

```text
uid=0(root)
```

This turns the OCI Run Command path into remote root. The authority can be revoked by removing the sudoers file, disabling the plugin, revoking the operator IAM policy, or disabling the Identity Domains application.
