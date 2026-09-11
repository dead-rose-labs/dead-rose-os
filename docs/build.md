# Сборка

Основной путь этой задачи — GitHub Actions. Push запускает workflow **Factory**:
официальный закреплённый Arch OCI image → preflight → pinned Calamares schema →
makepkg → mkarchiso → ISO inspection → QEMU/OVMF live session → accepted artifact.
На этом Mac сборку и тесты не запускаем по указанию пользователя.

## Одна команда на Linux x86_64

Нужны Linux x86_64, Docker, QEMU/OVMF, интернет для snapshot packages,
4 CPU, 8 GiB RAM и ориентировочно 30 GiB свободного пространства.

```sh
./dr factory
```

`dr` запускает те же `ci/*.sh`, что и workflow. Arch stages выполняются внутри
закреплённого OCI image из `versions.env`; QEMU smoke test запускается на host.
Результаты:

- `artifacts/dead-rose-os-0.1.0-g<shortsha>-x86_64.iso`
- `artifacts/dead-rose-os-0.1.0-g<shortsha>-x86_64.iso.sha256`
- `artifacts/manifest/build.json`
- `artifacts/manifest/packages.txt`
- `artifacts/logs/`

Для повторной сборки требуется новая work directory: stages не переиспользуют
старый `mkarchiso` work/rootfs/cache.

```sh
FACTORY_WORK=/var/tmp/deadrose-factory-2 ./dr factory
```

Work должен находиться на Linux filesystem с Unix permissions и mount support.
Нативная сборка на macOS не поддерживается. Тонкая обёртка mkarchiso не заменяет
его ISO builder. Артефакт является кандидатом на acceptance, а не автоматически релизом.

## Воспроизводимость и зависимости

В `versions.env` закреплены версия Dead Rose, официальный Arch OCI digest,
дата Arch Linux Archive snapshot, Calamares commit и SHA-256 source archive.
Build container и target package mirrors указывают на один daily snapshot.
Версии resolved packages сохраняются в manifest вместе с ISO checksum.

При ошибке сборки скачайте diagnostics artifact. Ошибки пакетов, schema validation,
mkarchiso и QEMU завершают workflow неуспешно; они не замаскированы continue-on-error.
Accepted ISO artifact публикуется только после live QEMU smoke test.
Full installation и hardware acceptance остаются отдельными обязательными
проверками перед выпуском 0.1.0.
