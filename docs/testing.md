# Проверки и acceptance

## Зафиксированный статус

Реализация подготовлена к первому push. **Сборка ISO, QEMU boot, установка,
визуальная acceptance и реальное оборудование пока не подтверждены.**

До изменения указаний пользователя был выполнен только source check раннего
базового профиля: 55 explicit packages, Bash syntax и основные service links.
Он не относится к последующей полной реализации. После просьбы пользователя
локальные тесты прекращены; дальнейшие результаты проверяет пользователь в Actions.

Фазы ТЗ остаются acceptance gates, а не отметками о написании кода:

| Фаза | Реализация | Подтверждение |
| --- | --- | --- |
| 1. Архитектура | Legacy заменён Archiso-проектом | Code review |
| 2. Live | UEFI, Plasma, SDDM, сеть | Ожидается Actions + визуальный просмотр |
| 3. Installer | Upstream Calamares, Btrfs, GRUB | Полная установка не пройдена |
| 4. Branding | Темы, wallpaper, dock, icons | Визуально не проверено |
| 5. Curated apps | Минимальное меню, upstream apps | Нужна проверка desktop |
| 6. CI | Build, validation, QEMU, artifacts | Ожидается первый запуск |
| 7. Acceptance | Процедура ниже | Не пройдена |

## Автоматические проверки в CI

```sh
./scripts/test.sh --source
./scripts/test.sh --iso out/dead-rose-os-0.1.0-x86_64.iso
python3 scripts/qemu-smoke.py out/dead-rose-os-0.1.0-x86_64.iso
```

Source checks: syntax Bash/Python, package names и дубликаты, обязательные файлы,
Archiso profile invariants, official repositories, service links, XML/SVG/JSON/YAML,
installer ordering, root lock policy, Btrfs и pinned Action SHAs.
Сборка Calamares дополнительно проверяет custom module configs его upstream schemas
и наличие обязательных compiled modules. Реальную валидность профиля проверяет mkarchiso.

ISO checks: файл, volume label, El Torito EFI, kernel/initramfs/SquashFS и
BOOTX64.EFI/loader entry в настоящей appended GPT ESP. Нужны xorriso, mtools,
sfdisk, Python и PyYAML. Отсутствующий ISO — ошибка, а не skipped success.

QEMU запускает неизменённый ISO с OVMF, TCG, virtio graphics/network, 4 GiB RAM
и без writable install disk. Live-only oneshot включается только в QEMU:
проверяет UEFI, каждую systemd unit отдельно, Wayland session file, процессы
KWin/Plasma, подключение NetworkManager, Calamares/modules и assets.
Только после этого выводится `DEAD_ROSE_LIVE_READY` в serial port.
До marker отведён timeout; ранний выход QEMU и guest failure проваливают тест.
Сохраняются serial log, QEMU log, screenshot PPM и JSON result.

Marker **не доказывает** открытие installer UI, успешную установку, визуальное
качество или поддержку оборудования. Screenshot надо посмотреть вручную.
При невозможности screenshot записывается отдельная диагностическая ошибка;
критерий smoke — readiness marker. Не ослаблять критерии ради зелёного CI.

## QEMU / VirtualBox installation acceptance

VM: x86_64, UEFI/OVMF, Secure Boot off, 4 CPU, 6 GiB RAM,
новый пустой виртуальный диск 40 GiB. Не подключать физические диски.

1. Загрузить ISO. Проверить Plymouth и появление live Plasma Wayland desktop.
2. Проверить dock, меню, Browser, Files, Terminal, Settings, network, audio и TTY.
3. Запустить Install Dead Rose; проверить язык, keyboard, timezone и видимость диска.
4. Явно выбрать тестовый диск и Btrfs, создать пользователя и подтвердить установку.
5. Дождаться успешного завершения без ручных shell-команд.
6. Выключить VM, отключить ISO, загрузить установленный диск.
7. Проверить Dead Rose SDDM, пароль пользователя и Plasma Wayland.
8. Проверить wallpaper, colors, iconography, dock и все основные приложения.
9. Проверить sudo; live account, installer и беспарольный live sudo должны отсутствовать.
10. Проверить network, reboot и создание второго пользователя с теми же desktop defaults.
11. Повторить cold boot. Отдельно проверить manual partitioning и LUKS1, если они
    будут объявляться поддерживаемыми в release notes.

Диагностика: `journalctl -b`, `systemctl --failed`, `nmcli`, `ip`, `lsblk`,
`findmnt`, `pacman -Q`, Calamares log. В live debug entry kernel/systemd logs
выводятся на console. В установленной системе можно убрать `quiet splash` через GRUB editor.

## Реальное оборудование

Повторить весь installation flow на выделенном тестовом x86_64 UEFI компьютере.
Записать ISO SHA-256, commit, CPU/GPU, firmware, накопитель, Wi-Fi/Bluetooth,
звук, suspend/resume, подключение внешнего монитора и результаты reboot.
Известные проблемы фиксировать с логами; не объявлять hardware acceptance по VM.

Definition of Done достигнут только после успешного полного flow из ТЗ.
