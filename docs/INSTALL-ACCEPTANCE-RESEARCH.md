# Install acceptance investigation

UI startup is confirmed PASS by run
[33977555113](https://github.com/dead-rose-labs/dead-rose-os/actions/runs/33977555113)
at `d464c225692987d5ecd0211b1977f2880cdf83b3`: the user confirmed
`DEAD_ROSE_UI_READY mode=live_installer` in both QEMU logs. Installation timeout
is a separate failure. No UI or appliance boot configuration changes are part
of this investigation.

## Pinned source findings

- kairos-init `v0.17.2`, commit `a3f70baa57b458c723c4b790683b3782f7c20216`:
  [Makefile](https://github.com/kairos-io/kairos-init/blob/v0.17.2/Makefile)
  bundles kairos-agent `v2.31.3`.
- [52_installer.yaml](https://github.com/kairos-io/kairos-init/blob/v0.17.2/pkg/bundled/cloudconfigs/52_installer.yaml)
  creates and enables `kairos-installer.service` in the `initramfs` stage. It
  runs `/usr/bin/kairos-agent install`, after `multi-user.target`, on `/dev/tty1`.
  The stage requires systemd, `install-mode` (or legacy `nodepair.enable`), and
  `/run/cos/live_mode` or `/run/cos/uki_install_mode`. These are stage conditions,
  not `ConditionKernelCommandLine` entries in the generated unit. Interactive
  mode stages can subsequently disable this unit and enable
  `kairos-interactive.service`.
- [00_datasource.yaml](https://github.com/kairos-io/kairos-init/blob/v0.17.2/pkg/bundled/cloudconfigs/00_datasource.yaml)
  pulls providers during `rootfs.before`, `initramfs.before`, and `network` when
  `/oem/95_userdata` does not exist. UKI installed boots additionally require
  `kairos.pull_datasources`; ordinary live boots do not. Pending datasource work
  is signalled by `/run/.userdata_load`.
- [09_systemd_services.yaml](https://github.com/kairos-io/kairos-init/blob/v0.17.2/pkg/bundled/cloudconfigs/09_systemd_services.yaml)
  creates `cos-setup-fs`, `cos-setup-boot`, `cos-setup-network`, and reconcile
  units and their enablement symlinks during initramfs.
  [02_agent.yaml](https://github.com/kairos-io/kairos-init/blob/v0.17.2/pkg/bundled/cloudconfigs/02_agent.yaml)
  creates/enables `kairos-agent.service` outside recovery; its command is
  `kairos-agent start`, not the automatic installer.
- kairos-init's
  [GetInstallOemCloudConfigs](https://github.com/kairos-io/kairos-init/blob/v0.17.2/pkg/stages/steps_install.go)
  writes these definitions to `/system/oem`. Thus missing generated units in a
  nonbooted OCI is not evidence that installation support is absent. Actual unit
  generation and enablement must also be inspected in the booted guest.
- agent `v2.31.3`, commit `a54345d26ef989ae23790051e8420fcae687a617`, pins SDK
  `v0.25.2` and Yip `v1.25.1` in its
  [go.mod](https://github.com/kairos-io/kairos-agent/blob/v2.31.3/go.mod).
  [Install](https://github.com/kairos-io/kairos-agent/blob/v2.31.3/internal/agent/install.go)
  waits up to five minutes for `/run/.userdata_load`, scans config and boot
  parameters, then calls `RunInstall` when `install.auto` is true.
- Yip's [CDROM provider](https://github.com/mudler/yip/blob/v1.25.1/pkg/plugins/datasourceProviders/provider_cdrom.go)
  prefers devices labelled `cidata`/`CIDATA`, then other `/dev/sr*` devices. It
  reads root `user-data` (fallback `config`) through a read-only filesystem mount.
  The [datasource plugin](https://github.com/mudler/yip/blob/v1.25.1/pkg/plugins/datasource.go)
  tries CDROM providers first and normally writes `userdata.yaml` under the
  configured `/oem/95_userdata` path.
- [GetUserConfigDirs](https://github.com/kairos-io/kairos-agent/blob/v2.31.3/pkg/constants/constants.go)
  orders `/run/initramfs/live`, `/etc/kairos`, `/usr/local/cloud-config`, then
  `/oem`. The SDK recursively merges YAML files with valid cloud-config headers.
  CIDATA config in `/oem` is intended to override embedded ISO config; the
  embedded `install.auto: false` alone does not prove the timeout's cause.

The config-drive creation follows the official
[automated installation workflow](https://kairos.io/docs/installation/automated/).
The install test now verifies the actual ISO label, root entries and extracted
user-data/meta-data bytes before starting QEMU.

## Validation and limits

Ran the exact SDK `v0.25.2` `schema.Validate` function used by the agent's
`validate` CLI against `os/cloud-config/ci-install.yaml` on macOS. Result:
`missing properties: 'users'`. This is a strict schema result, not a proven
installer failure: the normal agent
[scan](https://github.com/kairos-io/kairos-agent/blob/v2.31.3/pkg/config/scan.go)
warns and continues on schema failures unless strict validation is requested.
No account or config workaround was added.

The exact final OCI could not be inspected locally: anonymous GHCR access
returned HTTP 401, GitHub CLI has no authentication, and the local Docker daemon
did not respond. The existing runner image check now records the candidate
digest, actual agent version, bundled definitions, available units/symlinks and
`systemctl --root=/ is-enabled` results, and runs the image's own validator.
Schema validation is reported separately so this diagnostic does not introduce
a stricter parser gate than the installation itself. None of those runner
results, nor actual config ISO inspection, are claimed as already executed.

Local checks: Bash syntax, ShellCheck, repository architecture checks, Python
syntax, and mocked collector handshake (live/install profiles; command echo
does not satisfy the nonce; missing completion fails). A mocked install timeout
also confirmed collection happens while the guest process is alive and still
returns acceptance failure. These are not VM tests.

## Runtime decision after the diagnostic commit

The install timeout invokes the existing serial collector before VM termination.
It collects disk/label/mount evidence, exact units and their journals, the agent
log, `/run/cos`, datasource sentinel and config filenames. `kairos-agent config
get` projects only `device`, `auto`, `bind_mounts`, `reboot`, and `poweroff`; full
config files, account data and credentials are not printed.

- A: no CIDATA device — attachment/config ISO failure.
- B: CIDATA exists but expected userdata is not discovered — datasource failure.
- C: expected config is discovered but auto install does not run — boot/service
  integration failure. Inspect unit generation, enablement and merged config.
- D: installer ran and failed — report its first concrete error.

Current classification is unknown: the existing timeout logs do not establish
any of A–D. Root cause and an applicable upstream-supported fix remain unproven.
Do not change installation or boot configuration until the diagnostic run gives
the failing boundary. Do not wait for or poll the new Actions run; the user will
provide its results.
