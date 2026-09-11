# Dead Rose OS 0.1.0

Минимальный Arch Linux desktop: Plasma Wayland, Calamares, Btrfs,
NetworkManager, PipeWire и собственное оформление Dead Rose.
Архитектура — x86_64, загрузка — UEFI без Secure Boot.

**Статус: реализация подготовлена для первой сборки в GitHub Actions.
Рабочий ISO и полная установка пока не подтверждены.**

Весь factory запускается через GitHub Actions после push в `main`.
Локально тот же путь доступен на Linux x86_64 с Docker и QEMU:

```sh
./dr factory
```

Результат: `artifacts/dead-rose-os-0.1.0-g<shortsha>-x86_64.iso`.
Workflow **Factory** собирает пакеты, ISO, проверяет образ, запускает
QEMU/OVMF live session и публикует accepted artifact только после трёх маркеров:
`DEAD_ROSE_LIVE_READY`, `DEAD_ROSE_SDDM_READY`, `DEAD_ROSE_PLASMA_READY`.
Логи и screenshot доступны отдельным diagnostics artifact даже при ошибке.

[Архитектура](docs/architecture.md) · [Сборка](docs/build.md) · [Acceptance](docs/testing.md)
