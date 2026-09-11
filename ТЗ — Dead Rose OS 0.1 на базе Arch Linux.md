# Dead Rose OS 0.1 — техническое задание

## 1. Цель проекта

Необходимо полностью переработать текущий проект **Dead Rose OS** и получить первую действительно рабочую версию системы.

Dead Rose OS **не является новой операционной системой, написанной с нуля**.

Dead Rose OS 0.1 должна представлять собой:

> **кастомизированный Arch Linux desktop distribution с собственным Dead Rose дизайном, минимальным набором приложений и готовым графическим installer.**

Основная идея:

```text
Arch Linux
    +
KDE Plasma
    +
готовые upstream Linux-компоненты
    +
Dead Rose branding/theme/configuration
    =
Dead Rose OS
```

Мы НЕ разрабатываем самостоятельно:

- Linux kernel;
- init system;
- bootloader;
- ISO format;
- installer backend;
- partitioner;
- desktop environment;
- compositor;
- display server;
- package manager;
- networking stack;
- audio stack;
- update system.

Для всего этого используются существующие upstream-компоненты.

Наша работа:

- Dead Rose visual identity;
- системная конфигурация;
- curated package set;
- desktop layout;
- boot branding;
- login branding;
- installer branding;
- default applications;
- CI/build pipeline;
- automated testing.

---

# 2. Главный архитектурный принцип

При любой технической задаче действует следующий приоритет:

1. официальный механизм Arch Linux;
2. официальный механизм используемого upstream-проекта;
3. стандартная конфигурация;
4. небольшой configuration/drop-in layer;
5. собственный код — только если предыдущие варианты объективно невозможны.

Запрещается создавать собственную реализацию уже существующего системного компонента.

Например:

```text
нужен ISO
→ Archiso

нужен installer
→ Calamares

нужен desktop
→ KDE Plasma

нужен compositor
→ KWin

нужен login manager
→ SDDM

нужна boot animation
→ Plymouth

нужна сеть
→ NetworkManager

нужен terminal
→ Konsole

нужен file manager
→ Dolphin

нужен package manager
→ pacman
```

Нельзя заменять эти компоненты собственным кодом без отдельного технического обоснования.

---

# 3. Что необходимо удалить из старой архитектуры

Текущие/старые реализации, относящиеся к предыдущей архитектуре Dead Rose OS, не должны определять новую систему.

Полностью отказаться от архитектуры, построенной вокруг:

- Ubuntu;
- Kairos;
- AuroraBoot;
- Cage;
- greetd;
- fullscreen Tauri shell как desktop;
- собственного installer backend;
- собственного disk partitioning;
- собственной A/B implementation;
- собственного ISO generator;
- собственного boot lifecycle;
- kiosk-only модели;
- собственного authentication system для системного login;
- собственного graphics/session bootstrap.

Если подобный legacy-код присутствует в репозитории и больше не используется — удалить его.

Не оставлять параллельно две архитектуры.

После миграции репозиторий должен отражать только актуальный подход.

---

# 4. Целевая версия

Версия:

```text
Dead Rose OS 0.1.0
```

Целевая архитектура:

```text
x86_64
```

Firmware:

```text
UEFI
```

Legacy BIOS в версии 0.1 не является обязательным.

Secure Boot в 0.1 не реализовывать.

---

# 5. Базовая ОС

Использовать:

```text
Arch Linux
```

Требования:

- официальный Arch package ecosystem;
- официальные repositories;
- `pacman`;
- `systemd`;
- максимально стандартная структура Arch;
- минимальное количество custom patches.

AUR не использовать для критических компонентов Dead Rose OS, если существует официальный пакет.

Если необходимого пакета нет в официальных репозиториях:

1. проверить официальный upstream;
2. проверить возможность поставки компонента непосредственно из нашего репозитория;
3. только затем рассматривать AUR.

Любое использование AUR в base image должно быть отдельно документировано.

---

# 6. Desktop environment

Использовать:

```text
KDE Plasma 6
KWin
Wayland
```

Основная графическая session:

```text
Plasma Wayland
```

Не писать собственный compositor.

Не писать собственный desktop environment.

Не заменять KWin.

X11 не является основной session.

XWayland допускается для совместимости приложений.

---

# 7. Концепция Dead Rose Desktop

KDE Plasma используется как **desktop engine**.

Пользователь должен воспринимать систему как:

```text
Dead Rose OS
```

а не как:

```text
Arch Linux + KDE theme
```

Это достигается через:

- собственную тему;
- собственный layout;
- собственные иконки;
- собственные wallpapers;
- собственный dock;
- собственный boot splash;
- собственный login screen;
- curated application list;
- Dead Rose branding.

При этом внутренние KDE-компоненты не форкаются без необходимости.

---

# 8. Визуальное направление

Основные цвета:

```text
background:
black / near-black

surface:
dark gray / graphite

primary:
wine / burgundy

text:
white

secondary text:
muted gray
```

Основная визуальная тема:

- минималистичная;
- тёмная;
- современная;
- небольшое количество элементов;
- wine/burgundy accent;
- никаких ярких стандартных KDE цветов;
- минимальное визуальное загрязнение.

Использовать существующий Dead Rose logo/rose branding.

---

# 9. Desktop layout

После login пользователь должен видеть чистый desktop.

Основной layout близок по философии к macOS:

```text
┌───────────────────────────────────────────┐
│                                           │
│                                           │
│           Dead Rose Desktop               │
│                                           │
│                                           │
│                                           │
│        ┌─────────────────────────┐        │
│        │ Apps / Dock             │        │
│        └─────────────────────────┘        │
└───────────────────────────────────────────┘
```

В нижней части экрана:

```text
Dead Rose Dock
```

На первом этапе реализовать его стандартными средствами Plasma Panel.

Не использовать отдельный custom compositor или полноценный собственный dock engine.

Dock должен иметь визуально:

- floating appearance;
- dark translucent background;
- rounded corners;
- wine accent;
- app icons;
- hover feedback;
- active application indicator.

---

# 10. Приложения первой версии

Dead Rose OS должна быть максимально чистой.

Не устанавливать ненужные desktop applications.

В системе по умолчанию оставить только минимально необходимые приложения.

Предварительный список:

```text
Dead Rose
Browser
Files
Terminal
Settings
Install Dead Rose (только live environment)
```

Использовать:

```text
Browser:
Chromium

Files:
Dolphin

Terminal:
Konsole

Settings:
KDE System Settings
```

Не устанавливать без необходимости:

- LibreOffice;
- email client;
- weather;
- calendar;
- games;
- notes;
- maps;
- media production software;
- KDE PIM suite;
- дополнительный пользовательский software.

Если пакет KDE тянет отдельные приложения зависимостями, не удалять системные зависимости искусственно.

Но launcher/menu должен показывать только полезные пользователю приложения.

---

# 11. Будущие Dead Rose приложения

Архитектура desktop должна позволять позже добавить:

```text
Home
Deployments
Monitoring
Nodes
Network
Security
Jarvis
```

В версии 0.1 их backend реализовывать НЕ нужно.

Можно зарезервировать визуальную модель и структуру проекта.

Не добавлять фиктивный функционал.

---

# 12. Web applications

Будущие сервисы вроде:

```text
Dokploy
Home Assistant
Grafana
```

должны иметь возможность запускаться как отдельные приложения.

В первой реализации предусмотреть generic web-app launcher:

```text
Chromium --app=<URL>
```

То есть приложение открывается:

- без обычных browser tabs;
- без address bar;
- как отдельное окно;
- с собственной `.desktop` записью;
- с собственной иконкой.

Не требуется реализовывать Dokploy/Home Assistant сейчас.

Нужно только предусмотреть архитектуру.

---

# 13. Login manager

Использовать:

```text
SDDM
```

Создать:

```text
Dead Rose SDDM Theme
```

Требования:

- Dead Rose branding;
- logo;
- wine accent;
- минималистичный login form;
- пользователь;
- password;
- shutdown/reboot controls;
- keyboard layout indicator при необходимости.

Не создавать собственный login backend.

Authentication остаётся стандартным Linux/PAM.

---

# 14. Boot animation

Использовать:

```text
Plymouth
```

Создать:

```text
Dead Rose Plymouth Theme
```

Boot должен визуально выглядеть примерно:

```text
        rose logo

       DEAD ROSE

           •
```

Минимальная анимация загрузки.

Не показывать лишний verbose boot text при обычной загрузке.

При необходимости debug boot должен позволять получить systemd/kernel logs.

---

# 15. Bootloader

Использовать стандартный upstream bootloader.

Предпочтительно:

```text
systemd-boot
```

для UEFI-only установки.

Если интеграция Calamares с systemd-boot в актуальной версии проблематична, разрешается использовать GRUB, если это стандартный и документированный путь Calamares/Arch.

Важно:

**не писать собственную установку bootloader.**

Выбрать вариант, который наиболее надёжно поддерживается upstream Calamares.

---

# 16. Filesystem

Основной filesystem:

```text
Btrfs
```

При установке предусмотреть стандартную Btrfs-разметку.

Не писать собственный Btrfs manager.

Использовать upstream возможности Calamares.

---

# 17. Snapshots

Предусмотреть возможность использования:

```text
Snapper
```

для Btrfs snapshots.

Для версии 0.1 достаточно:

- пакет присутствует;
- filesystem совместим;
- документирована дальнейшая возможность automatic snapshots.

Не нужно писать собственный rollback UI.

Если clean integration snapshots before/after pacman upgrade можно сделать стандартными готовыми hooks — допускается.

Но это не должно блокировать выпуск 0.1.

---

# 18. Network

Использовать:

```text
NetworkManager
```

Требования:

- Ethernet;
- Wi-Fi;
- standard Plasma integration.

Не создавать собственный network daemon.

---

# 19. Audio

Использовать:

```text
PipeWire
WirePlumber
```

Добавить необходимые Plasma audio integrations.

---

# 20. Bluetooth

Использовать:

```text
BlueZ
```

и стандартную Plasma integration.

---

# 21. ISO Builder

Использовать исключительно:

```text
Archiso
```

Это официальный механизм Arch Linux.

Не создавать собственный ISO builder.

Не использовать собственные xorriso scripts, если Archiso уже решает задачу.

Исходным профилем использовать подходящий официальный Archiso profile.

Рекомендуется начать с:

```text
releng
```

и кастомизировать его.

---

# 22. Live environment

ISO должен загружаться в полноценный:

```text
Dead Rose Live Desktop
```

Live environment должен иметь:

- KDE Plasma;
- Dead Rose branding;
- NetworkManager;
- Browser;
- Terminal;
- Files;
- installer launcher.

На desktop или dock:

```text
Install Dead Rose
```

---

# 23. Installer

Использовать:

```text
Calamares
```

Не писать installer самостоятельно.

Calamares отвечает за:

- language;
- locale;
- timezone;
- keyboard;
- user;
- hostname;
- disk selection;
- partitioning;
- filesystem creation;
- system installation;
- bootloader installation.

Создать:

```text
Dead Rose Calamares Branding
```

Installer должен называться:

```text
Install Dead Rose
```

Визуально использовать Dead Rose style.

---

# 24. Installation flow

Ожидаемый flow:

```text
Boot USB
   ↓
Dead Rose Plymouth
   ↓
Dead Rose Live Desktop
   ↓
Install Dead Rose
   ↓
Calamares
   ↓
Language
   ↓
Keyboard
   ↓
Timezone
   ↓
Disk
   ↓
User
   ↓
Install
   ↓
Finish
   ↓
Reboot
   ↓
Dead Rose login
   ↓
Dead Rose Desktop
```

После установки никаких manual post-install commands быть не должно.

---

# 25. Пользователь

Пользователь создаётся через Calamares.

Использовать обычную Linux user model.

Основной пользователь должен иметь административные права через:

```text
sudo
```

Direct root login должен быть выключен.

Не создавать собственную authentication DB.

---

# 26. Branding

Dead Rose branding должен применяться как минимум к:

```text
ISO name
OS name
/etc/os-release branding where appropriate
Plymouth
SDDM
Plasma theme
wallpaper
icons
Calamares
desktop
application menu
About information where configurable
```

При этом не подделывать package ownership или upstream copyright.

Допустимо отображать информацию вида:

```text
Dead Rose OS
Based on Arch Linux
```

---

# 27. System identity

Настроить корректный `/etc/os-release` или аналогичный branding mechanism.

Пример ожидаемой информации:

```text
NAME="Dead Rose OS"
PRETTY_NAME="Dead Rose OS 0.1"
ID=deadrose
ID_LIKE=arch
VERSION_ID="0.1"
```

Не ломать compatibility tools, которые ожидают Arch lineage.

---

# 28. Desktop theme

Создать отдельные системные assets:

```text
branding/plasma/
branding/colors/
branding/icons/
branding/wallpapers/
branding/plymouth/
branding/sddm/
branding/calamares/
```

Где возможно использовать стандартные механизмы KDE:

- Global Theme;
- Plasma Style;
- Color Scheme;
- Window Decoration;
- Icons;
- Cursor Theme;
- Wallpaper;
- panel config.

Не патчить KDE source code ради styling.

---

# 29. Default configuration

Default Plasma configuration должна применяться новым пользователям автоматически.

После первого login пользователь сразу получает:

- правильный wallpaper;
- правильную тему;
- правильный dock;
- правильные icons;
- правильный color scheme;
- отсутствие ненужных widgets;
- отсутствие лишних launchers.

Не должно требоваться запускать post-install script вручную.

---

# 30. Application launcher

В версии 0.1 можно использовать стандартный Plasma Application Launcher, стилизованный под Dead Rose.

Не писать собственный launcher до появления конкретной UX-причины.

При необходимости скрыть системные utility applications из основной user-facing категории через стандартные `.desktop` mechanisms.

Не удалять критические system tools только ради меню.

---

# 31. Dead Rose placeholder application

Добавить минимальное приложение:

```text
Dead Rose
```

которое пока может показывать:

```text
Dead Rose OS
Version 0.1.0

System ready.
```

Это может быть максимально простое приложение.

Не нужно строить сложный backend.

Задача — иметь системную Dead Rose entry point и место для будущего control-center.

---

# 32. Package policy

Файл:

```text
packages.x86_64
```

должен быть минимальным и понятным.

Разделить комментариями категории:

```text
# Base
# Boot
# Graphics
# KDE
# Network
# Audio
# Bluetooth
# Applications
# Installer
# Filesystem
# Development/debug
```

Не ставить метапакеты, которые притягивают огромное количество ненужного софта, если можно выбрать более точный набор пакетов.

---

# 33. Репозиторий

Предлагаемая структура:

```text
dead-rose-os/
│
├── archiso/
│   ├── profiledef.sh
│   ├── packages.x86_64
│   ├── pacman.conf
│   └── airootfs/
│
├── branding/
│   ├── plymouth/
│   ├── sddm/
│   ├── plasma/
│   ├── colors/
│   ├── icons/
│   ├── wallpapers/
│   └── calamares/
│
├── calamares/
│   ├── settings.conf
│   ├── modules/
│   └── branding/
│
├── config/
│   ├── plasma/
│   ├── systemd/
│   └── system/
│
├── apps/
│   └── dead-rose/
│
├── scripts/
│   ├── build.sh
│   └── test.sh
│
├── docs/
│   ├── architecture.md
│   ├── build.md
│   └── testing.md
│
└── .github/
    └── workflows/
        └── build.yml
```

Разрешается изменить структуру, если это необходимо для стандартной Archiso layout.

Не создавать дополнительную abstraction ради abstraction.

---

# 34. Local build

Должна существовать одна команда:

```bash
./scripts/build.sh
```

или:

```bash
./dr build
```

Результат:

```text
out/dead-rose-os-0.1.0-x86_64.iso
```

Build script должен быть максимально тонкой оболочкой вокруг:

```text
mkarchiso
```

Не реализовывать собственный build system.

---

# 35. Test command

Создать:

```bash
./scripts/test.sh
```

или:

```bash
./dr test
```

Он должен проверять хотя бы:

- shell script syntax;
- required files;
- Archiso profile validity;
- package list sanity;
- branding assets;
- generated ISO existence;
- ISO metadata;
- UEFI boot structure.

---

# 36. GitHub Actions

GitHub Actions должен:

```text
checkout
↓
prepare Arch build environment
↓
build Archiso
↓
validate ISO
↓
QEMU smoke test
↓
upload ISO artifact
```

CI должен собирать:

```text
dead-rose-os-<version>-x86_64.iso
```

как downloadable artifact.

---

# 37. CI security policy

GitHub Actions использовать pinned versions.

Не использовать:

```text
@main
```

для third-party actions.

Предпочитать:

```text
actions/checkout@<commit SHA>
```

и аналогично для других actions.

---

# 38. QEMU smoke test

После сборки CI должен проверить ISO в QEMU.

Минимальные automated checks:

```text
UEFI boot succeeds
systemd reaches graphical target
SDDM starts
Plasma session files exist
NetworkManager active
Calamares present in live environment
```

Если возможно без чрезмерной сложности, добавить serial marker:

```text
DEAD_ROSE_LIVE_READY
```

после успешного выхода системы на graphical target.

Marker может генерироваться простым systemd oneshot service после проверки необходимых units.

Не делать marker частью production application architecture.

Это только acceptance instrumentation.

---

# 39. Installed-system acceptance

Автоматизация полной установки через QEMU желательна, но не должна заставлять писать собственный installer integration.

Минимальная ручная acceptance проверка:

1. ISO boot.
2. Live desktop появляется.
3. Installer запускается.
4. Calamares видит disk.
5. Installation завершается.
6. Reboot.
7. ISO отключается.
8. Installed disk загружается.
9. SDDM появляется.
10. User login работает.
11. Plasma session запускается.
12. Dock отображается.
13. Browser работает.
14. Terminal работает.
15. Files работает.
16. Settings работает.
17. Network работает.

---

# 40. Debug mode

Система должна оставаться нормальным Linux.

При проблеме должны работать:

```text
TTY
journalctl
systemctl
pacman
ip
nmcli
lsblk
mount
```

Не блокировать обычные Linux debugging mechanisms.

Dead Rose branding не должен скрывать возможность диагностики.

---

# 41. Error policy

При любой проблеме:

**НЕ делать workaround первым вариантом.**

Порядок:

```text
1. установить root cause;
2. проверить Arch documentation;
3. проверить upstream documentation;
4. использовать официальный config;
5. использовать upstream-supported solution;
6. только затем небольшой workaround.
```

Каждый workaround должен иметь комментарий:

```text
WHY
root cause
upstream issue/reference if available
conditions for removal
```

Никаких временных костылей вида:

```text
sleep 5
restart until works
copy random binary
patch generated ISO manually
ignore error
```

без доказанной необходимости.

---

# 42. Что категорически запрещено

Не реализовывать:

- custom Linux distribution core;
- custom kernel;
- custom init;
- custom display server;
- custom Wayland compositor;
- custom login backend;
- custom bootloader;
- custom partitioner;
- custom installer backend;
- custom package manager;
- custom ISO format;
- custom update mechanism;
- custom A/B updater;
- custom authentication service;
- собственный networking daemon.

Не использовать Tauri fullscreen app как замену desktop environment в 0.1.

---

# 43. Что НЕ входит в Dead Rose OS 0.1

Не реализовывать пока:

```text
Home Assistant
ESPHome
Dokploy
Prometheus
Grafana
Loki
Kubernetes
RKE2
Rancher
Fleet
Jarvis
AI server
Dead Rose worker agent
SNMP management
Redfish
UPS management
server rack management
```

Это будут следующие версии.

Нельзя затягивать эти компоненты в 0.1 «на будущее».

---

# 44. Definition of Done

Dead Rose OS 0.1 считается готовой, только если выполняется весь следующий flow:

```text
download ISO
↓
write ISO / attach to VM
↓
UEFI boot
↓
Dead Rose Plymouth
↓
Dead Rose Live Desktop
↓
network works
↓
Install Dead Rose
↓
Calamares
↓
choose disk
↓
create user
↓
installation succeeds
↓
reboot
↓
boot from installed disk
↓
Dead Rose SDDM
↓
login
↓
Dead Rose Plasma Desktop
↓
Dock
↓
Browser
↓
Files
↓
Terminal
↓
Settings
↓
system usable
```

Ни на одном этапе не должны требоваться manual shell commands для завершения установки.

---

# 45. Визуальный Definition of Done

После login пользователь не должен ощущать, что это стандартная KDE installation.

Должны быть видимы:

- Dead Rose wallpaper;
- Dead Rose colors;
- Dead Rose iconography;
- Dead Rose dock;
- Dead Rose branding;
- минимальный curated application set.

Не должны доминировать:

```text
Arch logos
default KDE wallpaper
default Breeze appearance
random utility launchers
unnecessary applications
```

При этом upstream attribution должна сохраняться там, где это юридически необходимо.

---

# 46. Документация

Создать:

```text
docs/architecture.md
```

с описанием:

```text
Arch Linux
→ Archiso
→ Calamares
→ KDE Plasma
→ Dead Rose customization
```

Создать:

```text
docs/build.md
```

с одной основной инструкцией сборки.

Создать:

```text
docs/testing.md
```

с QEMU/VirtualBox/hardware acceptance procedure.

README должен быть коротким и актуальным.

Не оставлять README старой архитектуры.

---

# 47. Итоговый принцип проекта

После завершения версии 0.1 Dead Rose OS должна быть технически очень скучной системой.

Это хорошо.

Она должна быть:

```text
обычный Arch
+
обычный KDE
+
обычный Calamares
+
обычный Archiso
+
наш дизайн
+
наша конфигурация
```

Нам не нужно доказывать, что мы умеем писать installer, compositor, bootloader или update system.

Ценность Dead Rose находится выше:

```text
UX
apps
rack management
deployments
home automation
AI
```

Системный фундамент должен просто работать.

---

# 48. Порядок выполнения

Работать строго по этапам.

## Phase 1 — очистка архитектуры

- удалить/изолировать legacy Ubuntu/Kairos/Cage implementation;
- создать новый Archiso profile;
- минимальный package set.

## Phase 2 — базовый live ISO

Добиться:

```text
Archiso
→ UEFI boot
→ KDE Plasma Live session
```

Без branding.

Не переходить дальше до стабильной загрузки.

## Phase 3 — installer

Добавить Calamares.

Добиться:

```text
Live
→ Install
→ Reboot
→ installed Arch KDE
```

Без сложного branding.

## Phase 4 — Dead Rose branding

Только после рабочего installer:

- Plymouth;
- SDDM;
- Plasma;
- wallpaper;
- dock;
- icons;
- Calamares branding.

## Phase 5 — cleanup

Удалить ненужные apps.

Оставить curated environment.

## Phase 6 — CI

Добавить:

```text
build
test
QEMU smoke
artifact
```

## Phase 7 — final acceptance

Проверить:

```text
VM
+
реальный x86_64 UEFI компьютер
```

---

# 49. Правило выполнения для Codex

Не завершать задачу на состоянии:

```text
“код написан”
```

Необходимо довести проект до:

```text
ISO реально собирается.
```

Если среда позволяет — реально запустить automated QEMU smoke test.

Если обнаружена ошибка:

```text
investigate
→ root cause
→ upstream-supported fix
→ test again
```

Не маскировать ошибку.

Не ослаблять тесты только для получения зелёного CI.

---

# 50. Ожидаемый конечный результат

В GitHub repository должен находиться reproducible проект, из которого:

```text
git clone
↓
build
↓
dead-rose-os.iso
```

ISO должен быть самостоятельным установочным образом.

Пользователь устанавливает его на обычный современный x86_64 UEFI компьютер и получает:

> **Dead Rose OS 0.1 — минимальный Arch Linux desktop с полностью кастомизированным Dead Rose интерфейсом и готовым фундаментом для будущих Home, Deployments, Monitoring, Nodes и Jarvis приложений.**

Это и является целью текущего этапа.