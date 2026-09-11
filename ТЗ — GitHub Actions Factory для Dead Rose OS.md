# Dead Rose OS — GitHub Actions Factory

## 1. Цель

Необходимо создать production-quality GitHub Actions factory для проекта **Dead Rose OS**.

Factory должна полностью автоматически:

```text
source
  ↓
validate
  ↓
build custom packages
  ↓
create local Arch repository
  ↓
build Archiso
  ↓
inspect ISO
  ↓
UEFI boot test
  ↓
Plasma/live-session acceptance
  ↓
checksums + manifests
  ↓
GitHub artifact
  ↓
GitHub Release при version tag
```

Результатом каждого успешного полного build должен быть готовый:

```text
dead-rose-os-<version>-g<short-sha>-x86_64.iso
```

который можно:

- скачать;
- подключить к QEMU/VirtualBox;
- записать на USB;
- загрузить на реальном x86_64 UEFI компьютере.

---

# 2. Главный принцип

GitHub Actions **не является build system Dead Rose OS**.

GitHub Actions только вызывает обычные локально запускаемые scripts.

Правильная архитектура:

```text
GitHub Actions
      ↓
ci/*.sh
      ↓
official Arch / Calamares tooling
```

Не:

```text
GitHub Actions YAML
      ↓
500 строк bash
      ↓
магические sed
      ↓
ручные патчи
```

Каждая основная стадия CI должна воспроизводиться локально.

---

# 3. Используемые upstream-компоненты

Factory строится вокруг:

```text
Arch Linux
Archiso
pacman
makepkg
repo-add
Calamares
QEMU
OVMF
systemd
KDE Plasma
```

Не создавать собственные аналоги этих инструментов.

Archiso является единственным механизмом создания ISO.

Основная команда:

```bash
mkarchiso
```

Никаких собственных `xorriso` pipelines поверх результата Archiso.

---

# 4. Build environment

Archiso должен выполняться **в Arch Linux environment**.

GitHub-hosted runner может оставаться Ubuntu, но непосредственно build выполняется внутри официального Arch Linux container.

Схема:

```text
GitHub ubuntu runner
        ↓
official Arch Linux container
        ↓
pacman
makepkg
mkarchiso
```

Container должен запускаться с необходимыми privileges для Archiso filesystem/mount operations.

Не пытаться устанавливать `pacman`/Archiso непосредственно в Ubuntu runner и изображать из Ubuntu Arch build host.

---

# 5. Pinning build environment

Нельзя использовать плавающий:

```text
archlinux:latest
```

без фиксации.

Container image должен быть pinned по immutable digest:

```text
archlinux:<tag>@sha256:<digest>
```

Digest хранить централизованно.

Например:

```text
versions.env
```

или аналогичный declarative version file.

---

# 6. Фиксация Arch repositories

Dead Rose OS не должен неожиданно переставать собираться потому, что утром обновился Arch package.

Использовать **Arch Linux Archive daily snapshot**.

Создать:

```text
versions.env
```

примерной структуры:

```text
DEAD_ROSE_VERSION=0.1.0

ARCH_SNAPSHOT=2026/09/11

CALAMARES_COMMIT=<full commit SHA>

ARCH_CONTAINER_DIGEST=sha256:<digest>
```

Archiso build должен использовать repository:

```text
https://archive.archlinux.org/repos/${ARCH_SNAPSHOT}/$repo/os/$arch
```

Не смешивать Archive snapshot с обычными rolling Arch mirrors.

---

# 7. Обновление Arch snapshot

Обновление package base должно быть осознанным изменением repository.

Например:

```diff
- ARCH_SNAPSHOT=2026/09/11
+ ARCH_SNAPSHOT=2026/09/18
```

После этого factory полностью проверяет новую систему.

Если factory зелёная — snapshot можно merge.

Таким образом:

```text
Arch rolling release
```

не означает:

```text
случайно новые packages на каждом CI run
```

---

# 8. GitHub Actions pinning

Все используемые Actions должны быть pinned **полным commit SHA**.

Запрещено:

```yaml
uses: actions/checkout@main
```

Запрещено:

```yaml
uses: actions/checkout@v4
```

В workflow должно быть:

```yaml
uses: actions/checkout@<FULL_COMMIT_SHA>
```

То же касается:

```text
actions/upload-artifact
actions/download-artifact
actions/cache
и любых других Actions
```

Если используется third-party Action, необходимо:

1. доказать необходимость;
2. проверить repository;
3. pin по SHA.

Предпочитать official GitHub Actions и обычные shell commands.

---

# 9. Permissions

Применить принцип least privilege.

На уровне workflow по умолчанию:

```yaml
permissions:
  contents: read
```

Build jobs не получают `write`.

Release job получает отдельно:

```yaml
permissions:
  contents: write
```

только при release/tag build.

Не выдавать без необходимости:

```text
packages: write
id-token: write
security-events: write
```

---

# 10. Запрещён pull_request_target

Для build/test кода из PR запрещено использовать:

```yaml
pull_request_target
```

Использовать обычный:

```yaml
pull_request
```

PR build:

- не имеет secrets;
- не имеет write permissions;
- не публикует release;
- не может писать в main.

---

# 11. Workflow triggers

Factory должна поддерживать:

```text
pull_request → main
push → main
workflow_dispatch
push tag → v*
```

Поведение:

```text
PR
→ validation
→ packages
→ ISO
→ smoke tests

main
→ полный factory
→ ISO artifact

workflow_dispatch
→ полный factory

v0.1.0
→ полный factory
→ tests
→ release assets
```

Release создаётся **только** после прохождения всех обязательных tests.

---

# 12. Concurrency

Для одной branch не нужно одновременно собирать несколько устаревших commits.

Использовать `concurrency`.

При новом push:

```text
старый unfinished build branch
→ cancel
```

Но release/tag jobs не должны случайно отменяться новым branch build.

---

# 13. Factory stages

Основной pipeline:

```text
preflight
    ↓
calamares-schema
    ↓
build-packages
    ↓
build-iso
    ↓
inspect-iso
    ↓
boot-live
    ↓
artifact
    ↓
release [tag only]
```

Каждая стадия должна иметь отдельную ответственность.

---

# 14. Job: preflight

Назначение:

поймать дешёвые ошибки **до начала огромной сборки ISO**.

Проверить:

```text
repository structure
required files
versions.env
Archiso profile
package lists
PKGBUILD syntax
shell scripts
YAML syntax
Calamares files
branding assets
.desktop files
systemd units
```

Использовать:

```text
bash -n
shellcheck
```

где применимо.

Любой invalid config должен остановить pipeline здесь.

---

# 15. Проверка pinned dependencies

Preflight должен автоматически проверить:

- нет `uses: ...@main`;
- нет Actions с неполным SHA;
- нет `archlinux:latest`;
- Calamares source pinned full commit;
- remote source archives имеют checksum;
- критические downloads не используют `SKIP`.

Factory должна падать, если обнаружена неприкреплённая build dependency.

---

# 16. Calamares package architecture

НЕ смешивать:

```text
Calamares upstream source
```

и:

```text
Dead Rose Calamares configuration
```

в один самодельный tarball.

Использовать два отдельных packages.

## Package 1

```text
calamares
```

Содержит upstream Calamares binary.

Source должен быть pinned:

```text
CALAMARES_COMMIT=<full sha>
```

и иметь проверяемый SHA256 source archive.

## Package 2

```text
dead-rose-calamares-config
```

Содержит только:

```text
/etc/calamares/settings.conf
/etc/calamares/modules/*
/etc/calamares/branding/deadrose/*
```

и другие Dead Rose installer assets.

Изменение theme или `partition.conf` не должно заставлять форкать исходники Calamares.

---

# 17. Calamares schema validation

Это обязательная blocking стадия.

Использовать schema validator **именно той pinned версии Calamares**, которую собирает factory.

Не создавать свою schema.

Не копировать schema из другой версии.

Calamares upstream имеет собственный schema-validation mechanism; использовать его.

Validation должна проверять Dead Rose:

```text
settings.conf
partition.conf
bootloader.conf
users.conf
displaymanager.conf
unpackfs.conf
fstab.conf
packages.conf
finished.conf
```

и все остальные подключённые module configs.

Если schema говорит:

```text
Additional properties are not allowed
```

factory завершается ошибкой.

Запрещено:

- отключать schema validation;
- патчить schema;
- игнорировать exit code;
- удалять validation ради зелёного CI.

---

# 18. Upstream config baseline

Для каждого Calamares module:

1. взять sample/default config из pinned Calamares source;
2. скопировать только необходимые настройки;
3. применить минимальный Dead Rose override.

Не составлять module config «по памяти».

Не брать config из:

- другой версии Calamares;
- random distro;
- старого blog post.

---

# 19. Custom package build

Custom packages собираются в чистой Arch environment.

Не запускать `makepkg` от root.

Создать отдельного build user внутри build environment.

Сборка:

```text
PKGBUILD
↓
makepkg
↓
*.pkg.tar.zst
```

После каждого package:

- проверить exit code;
- сохранить package;
- сохранить build log.

---

# 20. Local Dead Rose repository

После сборки custom packages создать локальный pacman repository:

```text
deadrose.db
deadrose.files

calamares-....pkg.tar.zst
dead-rose-calamares-config-....pkg.tar.zst
...
```

Использовать стандартный:

```bash
repo-add
```

Archiso должен получать наши packages из этого repository.

Не копировать произвольные package files вручную внутрь rootfs после `pacstrap`.

---

# 21. Official packages vs custom packages

Official Arch package:

```text
→ official Arch snapshot repository
```

Dead Rose package:

```text
→ local deadrose repository
```

Не модифицировать official package содержимое после установки.

Если нужен системный override:

```text
→ отдельный dead-rose-* package
```

---

# 22. Job: build-packages

Должен:

```text
prepare Arch builder
↓
sync snapshot repositories
↓
build Calamares
↓
build Dead Rose config packages
↓
repo-add
↓
validate repository
↓
create package manifest
↓
upload repository artifact
```

Artifact например:

```text
deadrose-repo-<sha>
```

---

# 23. Job: build-iso

Получает только проверенный local package repository из предыдущего job.

Затем:

```text
prepare clean Arch builder
↓
restore local deadrose repo
↓
mkarchiso
↓
produce ISO
```

Использовать:

```bash
mkarchiso -v -r \
  -w <work-dir> \
  -o <out-dir> \
  <profile-dir>
```

Не применять после этого ручные modifications ISO.

После завершения `mkarchiso`:

> ISO считается immutable build output.

Никаких:

```text
mount ISO
modify files
xorriso repack
manual EFI patch
```

---

# 24. Archiso profile

Использовать стандартную Archiso structure.

Например:

```text
archiso/
├── profiledef.sh
├── packages.x86_64
├── pacman.conf
├── airootfs/
├── efiboot/
└── grub/
```

Использовать официальный `releng` profile как baseline там, где это полезно.

Удалять ненужные части через profile configuration, а не через post-build manipulation.

---

# 25. UEFI only

Dead Rose OS 0.1 целится в:

```text
x86_64
UEFI
```

Factory обязана проверить наличие корректной UEFI boot structure.

Legacy BIOS не является обязательным acceptance criterion.

---

# 26. Job: inspect-iso

После создания ISO выполнить static inspection.

Проверить:

```text
ISO существует
ISO не пустой
ISO размер разумный
volume label
UEFI boot entry
EFI image
kernel
initramfs
root filesystem image
Dead Rose files
Calamares package
Plasma packages
NetworkManager
SDDM
Plymouth
```

Не ограничиваться проверкой:

```bash
test -f *.iso
```

---

# 27. Package manifest

Из build необходимо сохранять полный package manifest.

Например:

```text
manifest/packages.txt
```

Формат:

```text
package-name version
```

Это позволит сравнивать два ISO и понимать:

> какой package изменился?

---

# 28. Build manifest

Создавать:

```text
manifest/build.json
```

Содержимое:

```json
{
  "dead_rose_version": "...",
  "git_commit": "...",
  "git_short_sha": "...",
  "arch_snapshot": "...",
  "archiso_version": "...",
  "calamares_commit": "...",
  "kernel_version": "...",
  "workflow_run_id": "...",
  "build_timestamp": "...",
  "iso_filename": "...",
  "iso_sha256": "..."
}
```

Значения должны собираться из фактического build.

Не hardcode данные, которые можно определить автоматически.

---

# 29. Checksums

Обязательно создать:

```text
dead-rose-os-....iso
dead-rose-os-....iso.sha256
```

Использовать:

```bash
sha256sum
```

Проверить checksum перед upload artifact.

---

# 30. UEFI QEMU boot test

После static validation ISO необходимо реально загрузить.

Использовать:

```text
QEMU
+
OVMF
```

То есть настоящий UEFI boot.

Не считать:

```text
файлы внутри ISO существуют
```

доказательством того, что ISO загружается.

---

# 31. QEMU acceleration

Если runner предоставляет `/dev/kvm`:

```text
использовать KVM
```

Если нет:

```text
fallback на TCG
```

Отсутствие KVM не должно делать factory полностью неработоспособной.

---

# 32. Serial diagnostics

QEMU test обязан сохранять serial output:

```text
artifacts/logs/qemu-serial.log
```

Boot test должен иметь timeout.

Например:

```text
3–5 минут
```

Если ready marker не появляется:

```text
FAIL
```

а не бесконечный hang.

---

# 33. Dead Rose readiness markers

Добавить CI-only acceptance instrumentation.

После успешной загрузки live system:

```text
DEAD_ROSE_LIVE_READY
```

После старта display manager:

```text
DEAD_ROSE_SDDM_READY
```

После реального запуска Plasma live session:

```text
DEAD_ROSE_PLASMA_READY
```

Marker должен писать строку в serial console.

Не использовать marker как часть production logic.

---

# 34. Plasma live-session acceptance

Live ISO должен автоматически запускать предусмотренную live session.

Acceptance считается успешным только если factory получает:

```text
DEAD_ROSE_PLASMA_READY
```

То есть недостаточно проверить:

```text
systemd booted
```

Необходимо проверить цепочку:

```text
kernel
↓
systemd
↓
display manager
↓
Wayland/Plasma session
```

---

# 35. Ready marker implementation

Marker должен генерироваться максимально простым стандартным способом.

Например:

- systemd unit;
- Plasma autostart;
- systemd user unit.

Не создавать отдельный daemon.

Marker scripts должны находиться в:

```text
ci/
```

или ясно обозначаться как acceptance instrumentation.

---

# 36. Failure diagnostics

При неудачном QEMU test factory должна загрузить независимо от результата:

```text
qemu-serial.log
QEMU command line
build manifest
package manifest
Archiso logs
Calamares build logs
schema validation logs
```

Диагностика должна сохраняться через:

```text
if: always()
```

Логи не должны теряться только потому, что job красный.

---

# 37. Full installer test

Автоматический Calamares installation test желателен, но **не ценой написания собственного installer automation**.

Сначала исследовать, предоставляет ли используемая pinned версия Calamares официальный/documented unattended или testing mechanism.

Если да:

```text
использовать его.
```

Если нет:

```text
не писать xdotool / random GUI-click automation
```

для v0.1.

До появления upstream-supported варианта полный:

```text
ISO
→ Calamares
→ disk
→ install
→ reboot
```

может оставаться отдельным manual hardware/VM acceptance test.

---

# 38. Никаких runtime fixes в factory

Factory НЕ должна выполнять что-то вроде:

```bash
sed -i ...
```

чтобы «подправить» repository source перед build.

Также запрещено:

```text
скачать исправленный config прямо из workflow
patch generated rootfs
patch Calamares после build
copy missing library manually
replace ISO EFI files после mkarchiso
```

Если build требует файл — этот файл должен находиться в Git repository.

---

# 39. Source-of-truth

Всё, что влияет на результат ISO, должно быть version-controlled:

```text
Archiso profile
package list
PKGBUILD
Calamares configs
systemd units
themes
branding
scripts
versions
```

CI не должен генерировать важную configuration из скрытого heredoc внутри YAML.

---

# 40. Scripts

Предлагаемая структура:

```text
ci/
├── lib.sh
├── preflight.sh
├── validate-calamares.sh
├── build-packages.sh
├── build-iso.sh
├── inspect-iso.sh
├── boot-smoke.sh
├── create-manifest.sh
└── collect-logs.sh
```

Все scripts:

```bash
set -Eeuo pipefail
```

и имеют понятные error messages.

---

# 41. Локальный запуск

Должно быть возможно локально выполнить:

```bash
./ci/preflight.sh
./ci/validate-calamares.sh
./ci/build-packages.sh
./ci/build-iso.sh
./ci/inspect-iso.sh
./ci/boot-smoke.sh
```

или удобную обёртку:

```bash
./dr factory
```

GitHub Actions не должен содержать уникальной логики, которую невозможно вызвать локально.

---

# 42. Workflow file

Основной workflow:

```text
.github/workflows/factory.yml
```

YAML должен быть относительно небольшим.

Его задача:

```text
checkout
↓
invoke script
↓
transfer artifact
↓
set permissions
↓
publish result
```

Не размещать всю build implementation в YAML.

---

# 43. Job timeouts

Каждый job должен иметь `timeout-minutes`.

Примерная логика:

```text
preflight             10
calamares-schema      10
build-packages        30–45
build-iso             45–60
inspect-iso           10
boot-live             10
release               10
```

Конкретные значения подобрать после реальных measurements.

Главное — не иметь jobs, способных висеть бесконечно.

---

# 44. Caching

Для первой стабильной версии factory:

> reliability > speed.

Не кэшировать blindly:

```text
work/
airootfs/
custom repository database
generated rootfs
mounted filesystem state
```

Это особенно важно для Archiso.

Если позже добавляется package-download cache:

- он не является source of truth;
- cache miss всегда должен работать;
- PR из fork не получает cache-write;
- cache contents считаются недоверенными input;
- cache key должен зависеть от Arch snapshot.

Factory должна нормально собираться вообще без cache.

---

# 45. Artifact naming

ISO:

```text
dead-rose-os-0.1.0-g1a2b3c4-x86_64.iso
```

Factory artifact:

```text
dead-rose-os-0.1.0-g1a2b3c4
```

Внутри:

```text
dead-rose-os-....iso
dead-rose-os-....iso.sha256

manifest/
├── build.json
└── packages.txt

logs/
├── archiso.log
├── qemu-serial.log
├── packages/
└── calamares-schema.log
```

---

# 46. Artifact upload

Использовать official GitHub artifact mechanism.

Если expected ISO отсутствует:

```text
upload step должен FAIL
```

Не использовать `warn`.

Retention для обычного CI build:

```text
14–30 дней
```

Release assets хранятся через GitHub Releases.

---

# 47. GitHub step summary

В конце успешной factory вывести GitHub Actions Summary.

Пример:

```text
🌹 Dead Rose OS Factory

Version:       0.1.0
Commit:        1a2b3c4
Arch snapshot: 2026/09/11
Calamares:     <sha>

ISO:
dead-rose-os-0.1.0-g1a2b3c4-x86_64.iso

Size:
3.1 GiB

SHA256:
...

Tests:
✅ Preflight
✅ Calamares schema
✅ Packages
✅ Archiso
✅ UEFI structure
✅ QEMU boot
✅ SDDM
✅ Plasma live session
```

При failure summary должен ясно показывать, какая стадия сломана.

---

# 48. Release flow

При tag:

```text
v0.1.0
```

после успешной factory:

```text
create GitHub Release
```

и приложить:

```text
ISO
SHA256
build.json
packages.txt
```

Не создавать release, если хоть один обязательный test не прошёл.

---

# 49. Release integrity

Tag version должен совпадать с Dead Rose version.

Например:

```text
tag:
v0.1.0

versions.env:
DEAD_ROSE_VERSION=0.1.0
```

Если:

```text
tag != configured version
```

factory должна FAIL.

---

# 50. Build provenance

Для каждого artifact должно быть однозначно понятно:

```text
из какого commit он собран
какой Arch snapshot использован
какой Calamares commit использован
какие packages установлены
какой SHA256 у ISO
```

Не должно существовать файла:

```text
dead-rose-latest.iso
```

без информации о происхождении.

---

# 51. Security rules

Запрещено:

```text
curl URL | bash

wget URL | sh

floating GitHub Action refs

floating Calamares branch

unverified source tarballs

secrets in logs

secrets in artifacts

pull_request_target build

write token in PR builds
```

Remote source должен иметь:

```text
pin
+
checksum
```

где это технически возможно.

---

# 52. Build logs

Каждая серьёзная команда должна иметь полный log.

Не скрывать полезный stderr.

Не использовать огромное количество `>/dev/null`.

При ошибке пользователь должен из artifact logs понять:

```text
что конкретно упало
```

без необходимости повторной ручной сборки.

---

# 53. Fail-fast philosophy

Factory должна останавливаться на первой настоящей ошибке.

Например:

```text
invalid partition.conf
```

означает:

```text
STOP AT SCHEMA
```

а не:

```text
попытаться собрать ещё 3GB ISO
```

Точно так же:

```text
custom package failed
```

→ ISO job не запускается.

---

# 54. Нельзя ослаблять tests

При проблеме запрещено:

```text
continue-on-error: true
```

на обязательных stages.

Не менять:

```text
required test
```

на:

```text
warning
```

только ради зелёного build.

Report-only допускается только для явно необязательных анализаторов.

---

# 55. Branch protection compatibility

Factory jobs должны иметь стабильные names, чтобы их потом можно было сделать required checks.

Например:

```text
Factory / Preflight
Factory / Calamares Schema
Factory / Packages
Factory / ISO
Factory / Inspect
Factory / UEFI Boot
Factory / Plasma
```

Не генерировать случайные names.

---

# 56. Что считается обязательным CI acceptance

Для merge в `main` должны пройти:

```text
Preflight                    ✅
Calamares schema             ✅
Custom package build         ✅
Archiso build                ✅
ISO static inspection        ✅
UEFI QEMU boot               ✅
Dead Rose live ready         ✅
SDDM ready                   ✅
Plasma session ready         ✅
SHA256 generation            ✅
Manifest generation          ✅
```

---

# 57. Что пока НЕ является обязательным

В factory v1 не блокировать build отсутствием:

```text
Secure Boot
BIOS boot
NVIDIA proprietary test
full Calamares automated installation
VirtualBox automation
real hardware test
Home Assistant
Dokploy
Docker
Kubernetes
AI
```

Factory строит **Dead Rose OS 0.1 foundation**.

---

# 58. Manual acceptance checklist

После successful factory периодически выполнять вручную на скачанном **том же ISO artifact**:

```text
VirtualBox/QEMU
↓
Live boot
↓
Dead Rose desktop
↓
Calamares
↓
Erase test disk
↓
Install
↓
Reboot
↓
boot installed system
↓
SDDM
↓
login
↓
Plasma
```

Не пересобирать отдельный ISO локально для manual acceptance.

Проверяется именно CI artifact.

---

# 59. Никаких исправлений исключительно в CI

Если CI нашёл проблему:

```text
исправить repository source
```

а не:

```text
добавить workaround только в .github/workflows/factory.yml
```

Локальный build и GitHub build должны использовать одинаковую implementation.

---

# 60. Root-cause policy

При любом failure Codex обязан действовать:

```text
1. определить конкретно падающий upstream component
2. прочитать его ошибку
3. проверить exact pinned version
4. проверить upstream config/schema/docs
5. исправить source configuration
6. запустить самый маленький affected test
7. только затем полный factory
```

Пример:

```text
partition.conf invalid
```

правильный путь:

```text
validate Calamares config
```

а не:

```text
full Archiso rebuild × 8
```

---

# 61. Definition of Done

GitHub Actions Factory считается готовой, когда clean commit может пройти:

```text
git push
    ↓
GitHub Actions
    ↓
preflight
    ↓
schema validation
    ↓
package build
    ↓
Archiso
    ↓
ISO inspection
    ↓
QEMU UEFI
    ↓
Plasma live
    ↓
artifact
```

без каких-либо ручных действий.

На странице GitHub Actions пользователь получает готовый:

```text
dead-rose-os-<version>-g<sha>-x86_64.iso
```

с:

```text
SHA256
package manifest
build manifest
diagnostic logs
```

---

# 62. Итоговое архитектурное правило

Factory должна быть **скучной**.

Она не должна:

```text
чинить Linux
чинить Archiso
чинить Calamares
редактировать ISO
эмулировать installer
```

Она должна просто доказать:

```text
наш source
+
зафиксированные upstream versions
+
официальные build tools
=
рабочий Dead Rose ISO
```

Если это равенство перестало выполняться — factory должна красным показать **где именно**, а не пытаться замаскировать проблему.