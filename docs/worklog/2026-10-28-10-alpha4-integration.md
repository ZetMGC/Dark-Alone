# 2026-10-28: DA-075 — интеграция, установка и alpha.4

Исполнитель: агент интеграции. Ветка main, база b64f51a. Источник новых изменений: codex/da068-closed-journal-reasoning-chains, 6427b97. Прямое поручение владельца: слить все ветки, проверить конфликты, установить билд до публикации и выпустить GitHub Release.

## Выполнено

Ветки origin сверены с GitHub. DA-064/065/067 входят в DA-068, остальные ветки уже входят в прежний main. Merge d547d63 выполнен без конфликтов; все origin-ветки являются предками main. Рабочие ветки и alpha.3 сохранены.

Godot 4.7.2 Standard и Windows export templates установлены из официального godotengine/godot-builds; SHA512 обоих архивов совпал с SHA512-SUMS.txt. Для .import явно закреплён LF: первый импорт шрифта иначе оставлял ложный dirty из-за локального CRLF. prepare_release читает заметки с явным UTF-8 в Windows PowerShell. Вложенная PLAYTEST приведена к текущим дневнику, короткой паузе и поведению TEST checkpoint.

Финальный чистый source/tag: 44cb06cf3aa59bc1981d891851a3d7d46bafd1a5. Комплект windows-20261028-175100-0acf6a53 установлен в отдельный версионный каталог вне репозитория, создан ярлык на рабочем столе. SHA256 всех установленных файлов совпал с manifest, обычный EXE графически запущен и завершился с кодом 0. Установка выполнена до публикации.

[v0.1.0-alpha.4](https://github.com/ZetMGC/Dark-Alone/releases/tag/v0.1.0-alpha.4) опубликован как Pre-release 2026-10-28 в 17:53 МСК. В draft проверены точный source, три вложения, размеры и серверные SHA256 digest. Опубликованный ZIP вместе с manifest/SHA256 скачан, распакован, каждый файл сверён с manifest и установленным комплектом; скачанный EXE также графически запущен вне проекта без ошибок.

ZIP: Dark-Alone-v0.1.0-alpha.4-windows-x86_64.zip, 38673082 байт. SHA256: 1dd14d1c81c7708f5b7cbd9b8a123ff41c32e6e2e420dfc41985b539c02d6e5a.

## Проверки

Godot 4.7.2 stable, Windows, GPU Compatibility / NVIDIA RTX 4060, драйвер 610.88.

| Команда / сценарий | Окружение | Результат |
| --- | --- | --- |
| Все origin-ветки — предки main; git diff --check | Git | PASS, конфликтов нет |
| tools/check.ps1 | source/headless | PASS: полный набор, ядро напитков 837, журнал 244, пузырьки 128, верстак 139, playthrough 50 |
| tools/check_windows_export.ps1 -Graphics | Windows release-template/headless/GPU | PASS: полный набор, верстак 139/151, журнал 244/259, дом 99/104, совместный цикл 21 |
| Windows workbench/journal-ink с --small | GPU 960×600 | PASS: 151/259; снимки журнала и состояний шейкера просмотрены |
| tools/prepare_release.ps1 -Tag v0.1.0-alpha.4 | чистый 44cb06c, совпадающий с origin/main | PASS: повтор source check, сборка, полный Windows headless; source_dirty=false |
| Установка, хеши, ярлык, обычный запуск | вне проекта, до публикации | PASS, графика, exit 0 |
| Draft: source/три вложения/размеры/digest; публикация | GitHub | PASS, isDraft=false, isPrerelease=true |
| Скачивание ZIP/SHA256/manifest, распаковка, сравнение с установкой, запуск | опубликованный комплект | PASS, графика, exit 0 |

Первый GPU world-target прогон дал три отказа в начале. Отдельные source/release повторения прошли. Тест программно направляет камеру, поэтому его ввод отделён от системных событий мыши, способных изменить направление при активации окна; настоящий mouse-look остаётся покрыт dialogue_bubble_test. После изменения полный Windows headless/GPU PASS. Игровой код этим исправлением не менялся.

Фактические логи и снимки локальные/игнорируемые: artifacts/alpha4-source-check.log, alpha4-export-check.log, alpha4-prepare-release.log, alpha4-workbench-small.log, alpha4-journal-ink-small.log, alpha4-installed-startup.log, alpha4-downloaded/; builds/validation-a7715440f0e540bfaf89a74881cd9778 и validation-d458dc5621e64ac48c7388865967bd8a. Сборки и локальные пути инструментов в Git не добавлены.

## Решения и ограничения

Стартовым остаётся вымышленный TEST-разговор «война или кино», игровой checkpoint этой сцены отключён, постоянные настройки включены. Канон, финальные рецепты и оценки напитков не добавлены. Субъективная человеческая оценка и другая машина не заменяются автотестами. Alpha.4 и его вложения неизменяемы; следующий исправленный выпуск — alpha.5.

## Продолжение

Человеческий проход установленного alpha.4: настройки после перезапуска, речь при повороте спиной, обе цепочки дневника, открытый шейкер → закрыть → встряхнуть → снять колпачок → процеживать над стаканом. Затем новые изменения по поручению владельца; техническое направление — TEST-рецепты/допуски и дозировка. Частично выполненных критериев DA-075 нет. STATUS/BACKLOG/HANDOFF/RELEASES и карточка обновлены. Последующий main-коммит только документирует итог и не меняет проверенный source/tag.

## Изменённые файлы интеграции

Merge включает DA-064–074 целиком. Дополнительно: .gitattributes, tests/world_target_test.gd, tools/prepare_release.ps1; AGENTS.md, README.md, docs/STATUS.md, BACKLOG.md, HANDOFF.md, PLAYTEST.md, RELEASES.md, releases/NEXT.md, releases/v0.1.0-alpha.4.md, tasks/DA-075.md, worklog/README.md и этот протокол.
