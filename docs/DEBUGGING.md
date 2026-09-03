# Debugging

Diagnostics are intentionally separate from the normal product path.

```bash
systemctl status dead-rose-core
journalctl -b -u dead-rose-core
journalctl -b -u greetd
cat /etc/kairos-release
cat /etc/os-release
lsblk
mount
```

Core and the shell emit `DEAD_ROSE_CORE_READY` and `DEAD_ROSE_UI_READY mode=…` markers to the journal and console. Installer and upgrade logs are stored under `/var/lib/dead-rose/logs`.
