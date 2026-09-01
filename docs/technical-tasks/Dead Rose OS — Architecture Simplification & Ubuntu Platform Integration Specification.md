# Dead Rose OS — Architecture Simplification & Ubuntu Platform Integration Specification

## 0. Цель задачи

Необходимо переработать текущую архитектуру Dead Rose OS так, чтобы проект представлял собой **самостоятельную пользовательскую операционную систему поверх стандартной минимальной Ubuntu Linux**, а не собственную реализацию низкоуровневой Linux-дистрибутивной инфраструктуры.

Главная идея:

> Dead Rose OS должна владеть пользовательским опытом, интерфейсом, системными функциями продукта и интеграцией компонентов, но не должна повторно реализовывать то, что уже надёжно предоставляет Ubuntu/Linux/systemd.

Dead Rose OS — это не Ubuntu Desktop с темой.

Но Dead Rose OS также не является Linux From Scratch, Buildroot-подобным проектом, immutable-дистрибутивом или собственной системой доставки disk images.

Итоговая модель:

```text
Ubuntu Linux = platform
Dead Rose = product
```

Для пользователя система должна выглядеть и ощущаться полностью как Dead Rose.

Внутренняя Linux-инфраструктура должна максимально использовать стандартные компоненты Ubuntu.

---

# 1. Главный архитектурный принцип

Использовать готовую Linux-платформу, а собственный код писать только там, где начинается функциональность Dead Rose.

Правильная граница:

```text
┌─────────────────────────────────────────────┐
│                Dead Rose UI                 │
│          React + TypeScript + Tauri         │
├─────────────────────────────────────────────┤
│             Dead Rose services              │
│ core / auth / settings / future modules     │
├─────────────────────────────────────────────┤
│          Dead Rose system integration       │
│ typed IPC / system APIs / service control   │
├─────────────────────────────────────────────┤
│             Cage + greetd                   │
├─────────────────────────────────────────────┤
│                 systemd                     │
├─────────────────────────────────────────────┤
│          Ubuntu Server 26.04 LTS            │
├─────────────────────────────────────────────┤
│              Linux kernel                   │
└─────────────────────────────────────────────┘
```

Необходимая пользовательская иллюзия:

```text
Power on
↓
Dead Rose boot screen
↓
Dead Rose graphical environment
↓
Dead Rose login
↓
Dead Rose home/dashboard
```

Пользователь не должен попадать в Ubuntu Desktop.

Пользователь не должен видеть GNOME, KDE, стандартный Ubuntu login manager, стандартную панель рабочего стола или терминал.

При этом внутри следует использовать максимально стандартный Ubuntu userspace.

---

# 2. Что Dead Rose OS НЕ является

Dead Rose OS не должна становиться:

- Linux From Scratch;
- Buildroot;
- Yocto;
- собственным init system;
- собственным bootloader;
- собственным login/session framework;
- собственным Wayland compositor;
- собственным package manager;
- собственным partition manager;
- собственным filesystem implementation;
- собственной immutable Linux platform;
- собственной OSTree-подобной системой;
- собственным Ubuntu Core;
- собственной системой block-level OS images;
- собственной системой atomic A/B updates на текущем этапе.

Не реализовывать подобные системы без отдельного будущего ТЗ.

---

# 3. Что Dead Rose OS МОЖЕТ и ДОЛЖНА писать самостоятельно

Собственный код необходим для продуктовых частей Dead Rose.

В частности:

- Dead Rose Shell;
- Dead Rose Installer UI;
- Dead Rose Core;
- Dead Rose authentication;
- Dead Rose settings;
- Dead Rose system API;
- Dead Rose IPC protocol;
- Dead Rose deployment functionality;
- Dead Rose node management;
- Dead Rose rack management;
- Dead Rose Home functionality;
- Dead Rose Security functionality;
- будущая orchestration/business logic;
- собственный UX;
- собственный UI;
- собственный branding;
- собственные системные интеграции.

Различие принципиально.

Например:

```text
"поменять hostname через Dead Rose UI"
```

требует собственного Dead Rose API.

Но:

```text
"написать собственный механизм хранения hostname"
```

не требуется.

Dead Rose должна вызвать стандартный Linux/systemd mechanism.

---

# 4. Основа системы

Использовать:

```text
Ubuntu Server 26.04 LTS
```

Без полноценной desktop environment.

Не устанавливать:

- GNOME Shell;
- KDE Plasma;
- XFCE;
- Cinnamon;
- Ubuntu Desktop;
- стандартные desktop panels;
- полноценную пользовательскую desktop shell environment.

Использовать стандартные Ubuntu-пакеты для:

- Linux kernel;
- firmware;
- systemd;
- udev;
- networking;
- storage;
- boot;
- PAM;
- logind;
- device access;
- filesystem utilities;
- package management.

Не форкать эти компоненты без крайней необходимости.

---

# 5. Kernel

Использовать стандартное поддерживаемое Ubuntu kernel package.

Ожидаемая модель:

```text
linux-generic
```

Не собирать собственное ядро.

Не поддерживать собственный kernel config.

Не поддерживать собственный набор kernel patches.

Не форкать Linux.

Если в будущем потребуется специфический kernel feature, решать это отдельной задачей.

---

# 6. Init и system services

Использовать:

```text
systemd
```

Systemd отвечает за:

- boot targets;
- daemon lifecycle;
- service supervision;
- mount lifecycle;
- logging integration;
- session dependencies;
- restart policies;
- dependency ordering;
- device-related startup.

Не создавать собственный process supervisor общего назначения.

Dead Rose services должны быть обычными systemd units.

Пример:

```text
dead-rose-core.service
dead-rose-state-init.service
greetd.service
```

---

# 7. Boot

Использовать стандартную поддерживаемую Ubuntu UEFI boot infrastructure.

Основная поддерживаемая конфигурация:

```text
UEFI
↓
GRUB
↓
Linux
↓
initramfs
↓
systemd
```

Использовать Plymouth для Dead Rose splash screen.

Пользователь при нормальной загрузке не должен видеть поток Linux boot logs.

При ошибке должна существовать возможность диагностической загрузки.

Не писать собственный bootloader.

Не писать собственную initramfs framework.

Не реализовывать custom boot protocol.

---

# 8. Disk architecture — критическое изменение

Текущая схема:

```text
EFI
ROOT-A
ROOT-B
STATE
```

должна быть упрощена.

ROOT-A / ROOT-B сейчас не нужны.

Не создавать архитектуру ради будущей функции atomic updates, которой ещё нет.

## Целевая MVP-разметка

Минимальный вариант:

```text
GPT
├── EFI System Partition
└── ROOT
```

ROOT:

```text
ext4
```

EFI использовать стандартным способом.

ROOT занимает доступное пространство диска после EFI.

Допустим swapfile вместо отдельного swap partition, если swap вообще нужен.

Не резервировать ROOT-B.

Не резервировать гигабайты под гипотетические будущие update slots.

---

# 9. STATE

В текущей версии **не нужен отдельный STATE partition только ради будущей A/B архитектуры**.

Использовать:

```text
/var/lib/dead-rose
```

как обычный persistent application/system data directory внутри root filesystem.

Там могут находиться:

```text
/var/lib/dead-rose/auth/
/var/lib/dead-rose/config/
/var/lib/dead-rose/state/
/var/lib/dead-rose/data/
```

Конкретную структуру сохранить/адаптировать по текущему коду.

Права доступа должны быть ограничены.

Отдельный STATE partition может быть введён в будущем, когда появится реальная архитектурная необходимость.

Не создавать его сейчас как speculative infrastructure.

---

# 10. A/B updates

Удалить из текущей обязательной архитектуры:

```text
ROOT-A
ROOT-B
active slot
inactive slot
slot switching
A/B boot state
A/B rollback assumptions
```

Не реализовывать atomic OS updater сейчас.

Не создавать placeholder implementation.

Не создавать сложную абстракцию «на будущее».

Когда atomic updates действительно станут задачей, они будут спроектированы отдельно.

Future architecture может использовать:

```text
A/B
systemd-sysupdate
OSTree
snapshots
image-based updates
или другую технологию
```

Но решение не принимается сейчас.

---

# 11. systemd-repart

`systemd-repart` не должен быть центральным механизмом установленной Dead Rose OS только потому, что он уже присутствует в проекте.

Если единственная причина его использования — создание:

```text
ROOT-A
ROOT-B
STATE
```

убрать эту зависимость из основной архитектуры.

Стандартная установка Ubuntu может создать обычный GPT layout существующими installer tools.

---

# 12. Raw OS image

Текущий подход:

```text
dead-rose-os.raw
dead-rose-os.raw.zst
```

с последующей block-level записью целого системного диска не должен быть основной моделью установки Dead Rose OS.

Не строить собственную image-based distribution architecture без необходимости.

Не использовать:

```text
dd entire Dead Rose disk image
```

как фундаментальную модель продукта.

Не создавать собственный формат system image.

---

# 13. Допустимые installer primitives

Dead Rose Installer имеет право использовать готовые существующие Linux/Ubuntu installer components.

Предпочтение:

- Canonical installer technologies;
- Curtin;
- стандартные partition/filesystem tools;
- стандартный Ubuntu package/rootfs mechanism;
- GRUB tooling;
- systemd;
- стандартные Linux utilities.

Если текущий Curtin integration можно значительно упростить и использовать для обычной Ubuntu layout installation, Curtin разрешается оставить.

Правило:

> Curtin должен быть инструментом, а не платформой, которую Dead Rose начинает оборачивать собственной image infrastructure.

---

# 14. Dead Rose Installer

Dead Rose Installer остаётся собственным пользовательским приложением.

UI:

```text
Tauri
React
TypeScript
Dead Rose UI components
```

Backend:

```text
Rust
```

Installer должен предоставлять собственный Dead Rose UX.

Пользователь не должен работать со стандартным текстовым Ubuntu installer UI.

Однако реальные disk/filesystem/install operations должны по возможности делегироваться проверенным системным инструментам.

---

# 15. Installer responsibilities

Dead Rose Installer должен:

1. Найти доступные физические install targets.
2. Использовать стабильные device identifiers там, где это разумно.
3. Не позволять выбрать installer media.
4. Проверить размер диска.
5. Показать пользователю выбранный диск.
6. Потребовать явное подтверждение destructive install.
7. Создать стандартный GPT.
8. Создать EFI partition.
9. Создать root partition.
10. Создать ext4 filesystem.
11. Установить Ubuntu base.
12. Установить Dead Rose runtime/components.
13. Установить bootloader.
14. Настроить systemd services.
15. Создать initial Dead Rose administrator.
16. Сохранить hostname.
17. Настроить графическую сессию.
18. Удалить/не активировать installer-specific services на target.
19. Проверить installed system.
20. Выполнить reboot.

---

# 16. Installer root privileges

UI установщика не должен работать как root.

Использовать модель:

```text
dead-rose-installer UI
        ↓
typed IPC
        ↓
dead-rose-installer-agent
        ↓
root operations
```

Installer agent может работать root, потому что ему объективно необходим доступ к:

- block devices;
- partitions;
- filesystems;
- mounts;
- bootloader installation.

API installer agent должен быть ограниченным.

Не предоставлять endpoint:

```text
exec(command: String)
```

или аналогичный arbitrary shell execution API.

Использовать конкретные операции.

---

# 17. Installed graphical session

Целевая схема:

```text
systemd
↓
greetd
↓
dead-rose-session
↓
Cage
↓
dead-rose-shell
```

Использовать:

```text
greetd
PAM
systemd-logind
Cage
```

Не писать собственный display manager.

Не писать собственный Wayland compositor.

Не заменять logind.

---

# 18. deadrose-ui system account

Графическое приложение должно запускаться под отдельным системным пользователем, например:

```text
deadrose-ui
```

Он является service/kiosk account.

Это **не пользовательский Dead Rose administrator account**.

Не смешивать Linux account и пользовательскую авторизацию приложения без отдельной причины.

---

# 19. Dead Rose login

Логин, который видит пользователь после запуска Dead Rose, является частью Dead Rose UI.

Пример:

```text
Boot
↓
greetd automatically establishes kiosk session
↓
Cage
↓
Dead Rose Shell
↓
Dead Rose Login Screen
↓
Dead Rose Dashboard
```

Пользователь не должен сначала логиниться через Linux TTY/greetd prompt, а потом ещё раз через Dead Rose.

greetd здесь является session launcher, а не пользовательским UI.

---

# 20. PAM/logind

Использовать существующий Linux session stack.

PAM/logind необходимы для корректного:

- seat handling;
- device access;
- session ownership;
- Wayland session;
- input devices;
- DRM access;
- lifecycle.

Не заменять их собственным session framework.

---

# 21. Cage

Использовать Cage как минимальный kiosk Wayland compositor.

Dead Rose не является desktop environment.

Cage должен запускать только разрешённое приложение:

```text
dead-rose-shell
```

Не добавлять:

- desktop;
- app launcher;
- taskbar;
- generic window manager UX.

---

# 22. dead-rose-session

`dead-rose-session` разрешено оставить.

Но его ответственность должна быть небольшой.

Разрешённые функции:

- подготовка Dead Rose graphical environment;
- запуск Cage;
- запуск Dead Rose Shell;
- restart/recovery policy;
- readiness marker;
- controlled failure handling.

Не превращать его в собственный init system.

Не превращать его в общий process manager.

---

# 23. Dead Rose Shell

Сохранить текущий technological direction:

```text
React 19
TypeScript
Vite
Tailwind
Tauri 2
Rust
WebKitGTK
packages/ui
```

Не переписывать UI без необходимости.

Цель этой задачи — исправить OS architecture, а не уничтожить готовый frontend.

Использовать существующий frontend код, компоненты, branding и UX настолько, насколько возможно.

---

# 24. Tauri security boundary

React не должен иметь прямого доступа к привилегированным system operations.

Запрещены generic operations вида:

```text
shell(command)
exec(command)
sudo(command)
run_arbitrary_process(args)
```

из frontend API.

Правильная модель:

```text
React
↓
Tauri command / IPC
↓
typed request
↓
Dead Rose service
↓
specific system operation
```

---

# 25. Dead Rose Core

`dead-rose-core` остаётся центральным backend системной логики Dead Rose.

Он должен предоставлять бизнес/system API, например:

```text
get_system_info
get_hostname
set_hostname
get_storage
get_network_status
get_dead_rose_version
restart_dead_rose_service
shutdown
reboot
```

Реализовывать только реально необходимые операции.

Не строить заранее огромный abstraction layer для будущих функций.

---

# 26. Privileges Dead Rose Core

Применять least privilege.

Если операция может выполняться без root — выполнять без root.

Не делать весь UI root.

Не делать Tauri root.

Не добавлять `sudo` к frontend.

Если конкретной будущей функции действительно понадобится privilege escalation, использовать минимальный controlled system service/API.

Не создавать универсальный root command proxy.

---

# 27. IPC

Unix sockets разрешены и предпочтительны для локального IPC.

Использовать:

- typed requests;
- typed responses;
- explicit methods;
- filesystem socket permissions;
- request validation;
- bounded inputs.

Можно использовать JSON/Serde, если это соответствует существующему проекту.

Не требуется изобретать бинарный protocol.

Не требуется писать собственный RPC framework.

---

# 28. Authentication

Сохранить Dead Rose authentication как product-level functionality.

Допустимо:

- Argon2id;
- собственная модель Dead Rose accounts;
- sessions;
- rate limiting;
- credentials storage.

Credentials должны находиться внутри:

```text
/var/lib/dead-rose
```

с корректными filesystem permissions.

Не хранить plaintext passwords.

---

# 29. Debug / rescue path

Хотя production UX не показывает shell, разработчику необходимо иметь надёжный способ диагностики системы.

Добавить контролируемый debug/recovery boot path.

Нормальный boot:

```text
Dead Rose OS
```

Debug boot entry, например:

```text
Dead Rose OS — Recovery / Debug
```

может запускать:

```text
multi-user.target
```

или другую стандартную диагностическую среду.

Это не должно быть default boot mode.

Не показывать debug UI обычному пользователю без необходимости.

Не создавать собственную recovery OS.

Использовать стандартные Linux capabilities.

---

# 30. Virtual terminals

Production mode не должен зависеть от TTY login.

Необходимо исключить ситуацию, когда обычный boot неожиданно оставляет пользователя на:

```text
Ubuntu login:
```

При падении graphical stack system должен:

- логировать ошибку;
- попытаться восстановить session в разумных пределах;
- оставить возможность recovery/debug boot.

---

# 31. Logging

Использовать:

```text
journald
tracing
```

Не писать собственную logging infrastructure.

Каждый Dead Rose daemon должен иметь понятный journal namespace/unit.

Диагностика должна быть возможна командами вида:

```text
journalctl -u dead-rose-core
journalctl -u greetd
journalctl -u dead-rose-session
```

---

# 32. systemd hardening

Продолжить использование systemd sandboxing там, где оно не ломает функциональность.

Рассмотреть/сохранить:

```text
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=
ProtectHome=
ProtectKernelTunables=yes
ProtectKernelModules=yes
RestrictNamespaces=
ReadWritePaths=
```

Настраивать ограничения отдельно для каждого сервиса.

Не копировать максимальный security template вслепую.

Сначала service functionality, потом минимально необходимые permissions.

---

# 33. Package management

Использовать стандартную Ubuntu package infrastructure:

```text
apt
dpkg
```

Dead Rose не должен создавать собственный package manager.

Собственные приложения могут устанавливаться как:

- packaged artifacts;
- binaries deployed during image/ISO build;
- .deb packages;

выбрать самый простой поддерживаемый вариант для текущего репозитория.

Не проектировать новый package format.

---

# 34. Updates

На текущем этапе не реализовывать собственную full-OS atomic update infrastructure.

Допустимо предусмотреть API/UI место для будущего:

```text
Settings → Updates
```

Но backend atomic mechanism не строить без отдельного ТЗ.

Текущая задача — получить надёжно устанавливаемую и загружаемую Dead Rose OS.

---

# 35. Build system

Сохранить удобный единый developer interface:

```text
./dr bootstrap
./dr test
./dr build
./dr iso
./dr installer-vm --smoke
```

Команды можно внутренне изменить при необходимости.

Главное — сохранить простой high-level workflow.

---

# 36. mkosi

mkosi можно использовать, если он реально упрощает создание Ubuntu root filesystem/build environment.

Не использовать mkosi как оправдание для создания собственной disk-image platform.

Если raw A/B image pipeline больше не требуется, соответствующую конфигурацию удалить/упростить.

Не менять mkosi только ради смены инструмента.

Критерий — простота.

---

# 37. ISO

Итоговый artifact остаётся:

```text
dead-rose-os-<version>-amd64.iso
dead-rose-os-<version>-amd64.iso.sha256
```

ISO должен:

- UEFI boot;
- показывать Dead Rose branding;
- автоматически запускать Dead Rose Installer;
- позволять установить систему на чистый диск;
- после reboot запускать Dead Rose Shell.

---

# 38. CI

Сохранить end-to-end проверку.

GitHub Actions должны как минимум:

1. Checkout.
2. Frontend install.
3. TypeScript check.
4. Frontend build.
5. Rust formatting/check.
6. Clippy.
7. Rust tests.
8. Build OS/install assets.
9. Build ISO.
10. Boot ISO in QEMU.
11. Run installer smoke flow.
12. Install to temporary virtual disk.
13. Reboot from installed disk.
14. Verify Dead Rose graphical stack reaches readiness marker.
15. Produce ISO.
16. Produce SHA-256.
17. Upload artifacts.

Не удалять полезный real-install smoke test ради упрощения архитектуры.

---

# 39. Test marker

Разрешено использовать:

```text
DEAD_ROSE_SHELL_READY
```

или аналогичный marker для CI.

Test-only marker не должен влиять на production behavior.

---

# 40. Production vs test build

Test instrumentation разрешена.

Но release ISO должен быть чистым.

Test-only:

- serial marker;
- additional logs;
- automation helpers;

должны быть явно отделены.

---

# 41. Не переписывать проект с нуля

КРИТИЧЕСКИ ВАЖНО.

Не создавать новый repository.

Не удалять работающие части только потому, что новая архитектура проще.

Сначала выполнить audit существующего проекта.

Для каждого крупного компонента определить:

```text
KEEP
MODIFY
REMOVE
```

Пример:

```text
dead-rose-shell         KEEP
packages/ui             KEEP
dead-rose-core          KEEP/MODIFY
dead-rose-auth          KEEP
dead-rose-ipc           KEEP
dead-rose-session       KEEP/MODIFY
installer UI            KEEP/MODIFY
installer agent         KEEP/MODIFY
ROOT-A/B logic          REMOVE
systemd-repart A/B      REMOVE
raw disk updater logic  REMOVE
```

Предпочитать migration/refactor вместо rewrite.

---

# 42. Что удалить

Найти и удалить либо переписать код, который существует исключительно ради:

- ROOT-A;
- ROOT-B;
- slot switching;
- inactive-root handling;
- future A/B updates;
- custom block-level raw image installation;
- custom disk image payload workflow;
- systemd-repart layout specific to A/B;
- state partition logic, если она больше не нужна;
- dead code вокруг будущей atomic update architecture.

Не оставлять большое количество unused compatibility code «на будущее».

Git history уже сохраняет старую реализацию.

---

# 43. Что сохранить

Максимально сохранить:

- UI;
- installer frontend;
- branding;
- Rust crates;
- IPC types;
- authentication;
- systemd hardening;
- Cage setup;
- greetd setup;
- Plymouth;
- QEMU testing;
- CI;
- `./dr`;
- unit tests;
- integration tests.

---

# 44. Принцип YAGNI

Следовать:

```text
You Aren't Gonna Need It
```

Если функция не нужна для текущей работающей Dead Rose OS, не строить её только потому, что она потенциально понадобится через год.

Особенно это относится к:

- atomic updates;
- rollback;
- cluster support;
- immutable roots;
- alternate system slots;
- snapshot orchestration;
- generalized privilege frameworks;
- generalized installer engines.

---

# 45. Правило выбора Build vs Reuse

Перед реализацией low-level функции проверить:

> Уже предоставляет ли Ubuntu/Linux/systemd готовый поддерживаемый механизм?

Если да — использовать его.

Примеры:

```text
service management → systemd
logging            → journald
sessions           → PAM/logind
boot               → GRUB
filesystem         → ext4
package manager    → apt/dpkg
kiosk compositor   → Cage
device management  → udev
mounting           → systemd/mount
```

Собственный код допускается только для Dead Rose-specific behavior поверх этих компонентов.

---

# 46. Запрещённый паттерн

Не делать:

```text
Existing Linux component
↓
"Maybe Dead Rose could do this better"
↓
Custom replacement
↓
More code
↓
More CI
↓
More bugs
↓
New infrastructure to maintain
```

Правильный подход:

```text
Existing Linux component
↓
Thin Dead Rose integration
↓
Dead Rose UI
```

---

# 47. "OS as one application"

Требование:

> Dead Rose OS ощущается как одно цельное приложение.

НЕ означает:

> вся система должна быть одним process/binary.

Внутри разрешены:

- Linux kernel;
- systemd;
- services;
- dbus;
- greetd;
- Cage;
- multiple Rust daemons.

Пользовательская модель должна оставаться цельной:

```text
Dead Rose is the environment.
```

---

# 48. Definition of Done — boot

После установки VM/physical machine должна:

```text
UEFI
↓
GRUB
↓
Plymouth Dead Rose
↓
systemd
↓
greetd
↓
dead-rose-session
↓
Cage
↓
dead-rose-shell
```

без ручного вмешательства.

Не должен появляться Ubuntu login prompt.

---

# 49. Definition of Done — disk

После установки:

```text
lsblk
```

не должен показывать:

```text
ROOT-A
ROOT-B
```

если отдельным будущим ТЗ A/B не возвращён.

Ожидается простой layout:

```text
EFI
ROOT
```

---

# 50. Definition of Done — user experience

Обычный пользователь:

- не видит Ubuntu Desktop;
- не видит GNOME;
- не видит TTY;
- не выбирает Cage;
- не запускает приложение вручную;
- не взаимодействует с Linux desktop;
- попадает сразу в Dead Rose.

---

# 51. Definition of Done — installer

ISO:

- bootable;
- UEFI;
- запускает graphical Dead Rose Installer;
- видит install disk;
- предупреждает об уничтожении данных;
- выполняет installation;
- после reboot установленный disk bootable;
- Dead Rose Shell запускается автоматически.

---

# 52. Definition of Done — architecture

В repository не должна существовать самостоятельная инфраструктура, единственная цель которой:

```text
"когда-нибудь потом мы сделаем A/B updates"
```

Необходимо оставить минимально достаточную архитектуру.

---

# 53. Definition of Done — security

Frontend:

```text
non-root
```

Installer UI:

```text
non-root
```

Privileged disk operations:

```text
installer agent only
```

Не существует unrestricted shell-execution API.

Passwords:

```text
Argon2id or current secure implementation
```

Permissions:

```text
least privilege
```

---

# 54. Definition of Done — tests

Следующие команды должны успешно проходить:

```text
./dr bootstrap
./dr test
./dr build
./dr iso
./dr installer-vm --smoke
```

Если интерфейс команд необходимо изменить, обеспечить эквивалентный простой workflow и обновить documentation/scripts.

---

# 55. Работа с существующим repository

Перед изменениями:

1. Изучить repository.
2. Найти текущую disk layout implementation.
3. Найти mkosi/repart configs.
4. Найти installer payload generation.
5. Найти raw.zst logic.
6. Найти boot/session stack.
7. Найти CI smoke implementation.
8. Найти code tied to STATE/A/B.
9. Построить dependency map.
10. Только после этого вносить изменения.

Не предполагать устройство проекта по этому документу, если его можно проверить непосредственно по коду.

---

# 56. Порядок реализации

Работать приблизительно такими этапами:

### Phase 1 — Audit

Сформировать внутренний список:

```text
KEEP
MODIFY
REMOVE
```

### Phase 2 — Disk simplification

Удалить A/B-specific layout.

Перевести target installation на простой standard layout.

### Phase 3 — Installer simplification

Удалить block-level raw disk payload architecture.

Использовать standard Ubuntu/Linux installer primitives.

### Phase 4 — Installed system

Проверить:

```text
GRUB
Plymouth
systemd
greetd
Cage
Dead Rose Shell
```

### Phase 5 — Persistent data

Перенести необходимые данные в:

```text
/var/lib/dead-rose
```

без обязательного STATE partition.

### Phase 6 — Security

Проверить ownership, socket permissions, unit hardening.

### Phase 7 — CI

Вернуть/сохранить полноценный QEMU install smoke test.

### Phase 8 — Cleanup

Удалить obsolete A/B/raw payload code.

### Phase 9 — Final verification

Собрать release ISO с нуля.

---

# 57. Не маскировать ошибки

Не добавлять:

```text
|| true
```

или аналогичные конструкции только ради зелёного CI.

Не отключать failing test, если test обнаруживает реальную проблему.

Не заменять реальную boot/install verification на проверку существования файлов.

Smoke test должен реально загрузить систему.

---

# 58. Не оптимизировать преждевременно

Сначала correctness.

Потом build speed.

Не создавать:

- complex caches;
- parallel image pipelines;
- custom binary installer format;

если это не требуется.

---

# 59. Не ломать physical hardware compatibility ради VM

QEMU является CI test environment.

Production architecture не должна зависеть от QEMU-specific behavior.

Использовать стандартные Linux mechanisms, которые работают и на physical x86_64 UEFI hardware.

---

# 60. Scope

В рамках этой задачи НЕ реализовывать:

- deployment system;
- Kubernetes;
- node orchestration;
- Home Assistant replacement;
- rack management;
- switch integration;
- security dashboard;
- atomic update engine.

Эти функции будут отдельными этапами.

Текущая задача:

> создать простой, стабильный фундамент Dead Rose OS, который устанавливается, загружается и запускает Dead Rose UI.

---

# 61. Самая важная архитектурная формула

Следовать ей при любом спорном решении:

```text
Does Ubuntu/Linux already solve this reliably?
        │
        ├── YES
        │    ↓
        │  reuse it
        │    ↓
        │  integrate it with Dead Rose
        │
        └── NO
             ↓
        Is this Dead Rose-specific functionality?
             │
             ├── YES → implement it
             │
             └── NO  → reconsider why we are building it
```

---

# 62. Итоговая архитектура после refactor

```text
                     DEAD ROSE OS

┌────────────────────────────────────────────┐
│              Dead Rose Shell               │
│          Tauri + React + TypeScript        │
├────────────────────────────────────────────┤
│              Dead Rose Core                │
│       Rust + typed local system API        │
├────────────────────────────────────────────┤
│             Dead Rose Auth                 │
│             Dead Rose State                │
├────────────────────────────────────────────┤
│        Unix socket / system APIs           │
├────────────────────────────────────────────┤
│             Cage + greetd                  │
├────────────────────────────────────────────┤
│ PAM │ logind │ udev │ journald │ networking│
├────────────────────────────────────────────┤
│                  systemd                   │
├────────────────────────────────────────────┤
│            Ubuntu Server 26.04             │
├────────────────────────────────────────────┤
│              Linux kernel                  │
└────────────────────────────────────────────┘
```

Disk:

```text
GPT
├── EFI
└── ROOT ext4
```

Application state:

```text
/var/lib/dead-rose
```

Boot:

```text
Power
→ GRUB
→ Dead Rose Plymouth
→ systemd
→ greetd
→ dead-rose-session
→ Cage
→ Dead Rose Shell
```

Installation:

```text
Dead Rose ISO
→ Dead Rose Installer UI
→ standard Linux/Ubuntu installation primitives
→ Ubuntu base + Dead Rose components
→ GRUB
→ reboot
→ Dead Rose
```

---

# 63. Final instruction

DO NOT interpret this task as a request to rebuild Dead Rose OS from zero.

DO NOT interpret "custom operating system" as "custom implementation of Linux infrastructure".

Refactor the current repository.

Preserve working product code.

Delete unnecessary low-level infrastructure.

Prefer standard Ubuntu components.

Dead Rose must own the experience, not reinvent the platform.

The desired result is:

> **A custom Dead Rose operating system experience built on a boring, reliable Ubuntu Linux foundation.**

"Boring underneath, completely Dead Rose on top" is a feature, not a compromise.