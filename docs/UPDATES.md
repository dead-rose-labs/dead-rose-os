# Updates

Dead Rose OS is updated as a versioned OCI appliance, not with interactive package installation.

```text
Git tag
  ↓
ghcr.io/dead-rose-labs/dead-rose-os:<VERSION>
  ↓ validated Dead Rose UpdateManager request
kairos-agent upgrade --source oci:<IMAGE>
  ↓
reboot into updated lifecycle slot
```

The ordinary API accepts only pinned tags under `ghcr.io/dead-rose-labs/dead-rose-os`; `latest`, `edge`, other registries, and shell metacharacters are rejected. Passwords and registry secrets are never placed in arguments or logs.

Kairos owns Active, Passive, Recovery, and rollback assessment. Dead Rose does not implement a second slot or rollback engine. Recovery is upgraded separately only after the active system is verified healthy.
