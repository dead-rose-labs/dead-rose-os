# Архитектура

Arch Linux → Archiso → Calamares → KDE Plasma → Dead Rose customization.

Legacy Ubuntu/Kairos/Cage/Tauri удалён. Системные компоненты не форкаются:
Linux, systemd, pacman, KWin, SDDM, Plymouth, NetworkManager и Calamares
работают через штатные интерфейсы и конфигурации.

## Образ и пакеты

`archiso/` — releng-derived профиль: UEFI systemd-boot, SquashFS, штатные
archiso hooks и preset mkinitcpio. BIOS, PXE и Secure Boot не включены.
`scripts/build.sh` подготавливает профиль и вызывает mkarchiso.

Большинство пакетов поступают из подписанных официальных core/extra.
Два локальных пакета собираются makepkg непривилегированным пользователем:

- `calamares`: upstream 3.3.14, commit `21ea803527735cfaf54fa6059e71d1ef65004864`,
  SHA-256 архива закреплён в PKGBUILD. Используется поддерживаемый upstream
  Boost.Python backend вместо старого bundled pybind11. Патчей исходников нет.
- `dead-rose-config`: SVG artwork, Global Theme, Plasma Style, color scheme,
  иконки с Breeze fallback, SDDM, Plymouth, Calamares branding, desktop entries
  и дефолты `/etc/skel/.config`.

AUR не используется. Build-only repository `deadrose-local` содержит только
пакеты из текущего checkout; для него отдельно разрешены unsigned packages.
Это исключение не применяется к Arch repositories и не переносится в target.
Архивы локальных assets имеют `SKIP` в makepkg: они создаются из checkout,
а не загружаются по сети. У внешнего Calamares-архива checksum обязателен.

`/etc/os-release` указывает на собственный файл в `/usr/share/dead-rose` через
pacman hook. Сохраняется `ID_LIKE=arch`; upstream `/usr/lib/os-release` не заменяется.
Обновления выполняются обычным pacman. Данные future apps не реализованы.

## Установка

Calamares распаковывает live SquashFS и kernel с ISO. Штатные модули создают
GPT, ESP и Btrfs (`@`, `@home`, `@cache`, `@log`), пользователя, locale, initramfs
и загрузчик. Установка рассчитана на работу без доступа к интернету.

Для установленной системы выбран GRUB — штатный Calamares/Arch путь,
поддерживающий Btrfs и LUKS1. systemd-boot используется для live ISO.
Собственного кода установки bootloader нет. GRUB умеет показывать debug menu;
в live ISO есть отдельный debug entry. Snapper установлен, автоматические
snapshots не включены. Настройку можно позже выполнить штатным Snapper.

`live` существует только в live environment: autologin, sudo без пароля и
Polkit-разрешение только для запуска Calamares локальным активным пользователем.
Root заблокирован. Upstream shellprocess удаляет live-конфигурации из target;
removeuser удаляет live-пользователя перед созданием основного пользователя.
После установки проверяются отсутствие live-привилегий, root lock, sudoers,
initramfs и EFI loader. Нет custom partitioning или installer backend.

## Desktop и приложения

Plasma Wayland запускается SDDM; greeter работает через Xorg. Dock — стандартная
floating Plasma Panel с Icon Tasks, Kickoff и system tray. Первый вход применяет
Global Theme/layout из `/etc/skel`; настройки далее доступны пользователю.

Существующий знак из двух вертикальных wine-линий перенесён из legacy branding
в SVG. Wallpapers и PNG Plymouth детерминированно растеризуются librsvg при сборке.
Breeze остаётся upstream engine и fallback для системных иконок и элементов;
свои цвета, обои, launchers и иконки задают внешний вид Dead Rose.

Меню содержит Dead Rose, Browser, Files, Terminal, Settings и live installer.
Системные utility packages остаются доступными через KRunner/TTY.
NetworkManager, Plasma NM, PipeWire/WirePlumber и BlueZ обеспечивают сеть и звук.

`dead-rose-web-app URL` запускает Chromium через argv, без shell-интерполяции.
Для будущего сервиса скопируйте `apps/web-app/example.desktop.in` в
`~/.local/share/applications/`, задайте настоящий URL и свою иконку.
Категория `X-DeadRose-WebApp` добавляет entry в curated menu. В `.desktop` значения
URL с буквальным `%` требуют `%%` по Desktop Entry specification.
Шаблон не устанавливается как фиктивное приложение. Никаких service backends нет.

## Upstream references

- [Archiso profile](https://github.com/archlinux/archiso/blob/master/docs/README.profile.rst)
- [Releng](https://github.com/archlinux/archiso/tree/master/configs/releng)
- [Calamares release sources](https://github.com/calamares/calamares/tree/v3.3.14)
- [Calamares bootloader configuration](https://github.com/calamares/calamares/blob/v3.3.14/src/modules/bootloader/bootloader.conf)
- [Plasma scripting API](https://develop.kde.org/docs/plasma/scripting/api/)
- [SDDM](https://wiki.archlinux.org/title/SDDM)
- [Plymouth](https://wiki.archlinux.org/title/Plymouth)
