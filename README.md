# Dead Rose OS 0.1.0

Минимальный Arch Linux desktop: Plasma Wayland, Calamares, Btrfs,
NetworkManager, PipeWire и собственное оформление Dead Rose.
Архитектура — x86_64, загрузка — UEFI без Secure Boot.

**Статус: реализация подготовлена для первой сборки в GitHub Actions.
Рабочий ISO и полная установка пока не подтверждены.**

На Arch Linux x86_64:

```sh
sudo pacman -Syu archiso python python-yaml mtools
./scripts/build.sh
```

Результат: `out/dead-rose-os-0.1.0-x86_64.iso`.
Workflow **Dead Rose ISO** собирает пакеты и ISO, проверяет образ, запускает
QEMU/OVMF и публикует ISO только после успешного smoke test.
Логи и screenshot доступны отдельным diagnostics artifact даже при ошибке.

[Архитектура](docs/architecture.md) · [Сборка](docs/build.md) · [Acceptance](docs/testing.md)
