# Сборка

Основной путь этой задачи — GitHub Actions. Push запускает workflow **Dead Rose ISO**:
официальный закреплённый Arch OCI image → makepkg → mkarchiso → ISO validation →
QEMU/OVMF → artifact. На этом Mac сборку и тесты не запускаем по указанию пользователя.

## Одна команда на Arch Linux x86_64

Нужны Arch Linux x86_64, root для mounts mkarchiso, интернет для пакетов,
4 CPU, 8 GiB RAM и ориентировочно 30 GiB свободного пространства.

```sh
sudo pacman -Syu archiso python python-yaml mtools
./scripts/build.sh
```

Скрипт устанавливает build dependencies через pacman и создаёт системного
пользователя `deadrose-builder` только в build environment. Предпочтительна
выделенная VM или CI container. Результаты:

- `out/dead-rose-os-0.1.0-x86_64.iso`
- `out/SHA256SUMS`
- `out/packages.x86_64.txt`

Для повторной сборки требуется новая work directory: mkarchiso сохраняет markers
выполненных шагов, поэтому повторное использование старого work опасно.

```sh
sudo DEAD_ROSE_WORK_DIR=/var/tmp/dead-rose-build-2 ./scripts/build.sh
```

Work должен находиться на Linux filesystem с Unix permissions и mount support.
Нативная сборка на macOS не поддерживается. Тонкая обёртка mkarchiso не заменяет
его ISO builder. Артефакт является кандидатом на acceptance, а не автоматически релизом.

## Воспроизводимость и зависимости

В Git закреплены конфигурации, Calamares revision/checksum и SHA Actions/OCI image.
Arch repositories rolling-release: package versions разрешаются во время сборки
и сохраняются в manifest. Это повторяемый build process, **не гарантия побитово
одинакового ISO в разные дни**. Для release freeze следует закрепить официальный
Arch Linux Archive snapshot и согласованные версии build tools; затем повторить acceptance.

При ошибке сборки скачайте diagnostics artifact. Ошибки пакетов, schema validation,
mkarchiso и QEMU завершают workflow неуспешно; они не замаскированы continue-on-error.
ISO artifact публикуется только после smoke test. Full installation и hardware
acceptance остаются отдельными обязательными проверками перед выпуском 0.1.0.
