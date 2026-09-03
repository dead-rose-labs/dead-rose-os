# Dead Rose OS agent rules

1. Dead Rose OS 0.1 is Ubuntu 26.04 BYOI transformed by pinned `kairos-init`.
2. Kairos owns install, immutable lifecycle, Active/Passive, Recovery, and OCI upgrades.
3. Never add custom bootloader, partitioning, ISO assembly, A/B, or rollback code.
4. React is presentation; privileged behavior belongs to typed Rust Core requests.
5. Never expose generic shell or command execution.
6. The graphical shell runs as the unprivileged `deadrose` account.
7. Persistent product state belongs under `/var/lib/dead-rose` and must survive upgrades.
8. Production installation must always require an explicit disk choice and `ERASE` confirmation.
9. Pin build dependencies and run relevant frontend, Rust, image, and QEMU tests.
10. Do not claim an appliance acceptance check passed unless it actually ran.
