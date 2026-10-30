# 2026-10-30: DA-097 — alpha.5

Прямое поручение владельца выпустить релиз из актуального main. Новый тег v0.1.0-alpha.5; прежние теги/вложения сохраняются. Подготовлены заметки NEXT. Далее prepare_release, GPU проверки, draft/вложения, публикация и скачивание с проверкой SHA256/запуском. Результаты дополняются.


## Выполнено

Полный prepare_release source/headless PASS для a2009f3. После него исправлена только инструкция PLAYTEST, финальный чистый source/tag 68d0f0314cbe46371480c5fb19395cb557b372d5. Игровой код идентичен проверенному. Production builds/windows-20261030-145015-531ccb35. Финальный tools/check_windows_export.ps1 -Graphics PASS: сквозной проход, настройки, дневник, диалог, дом, верстак, посуда/крышка/перенос. В частности workbench 144/156, journal ink 244/259, tabletop 45/47, shot 16/22. Логи artifacts/alpha5-prepare.log и alpha5-final-windows.log. Полный исходный и финальный экспортный прогоны без ошибок.

Через GitHub API под ZetMGC создан draft с точным source, загружены ZIP 47229434 байта, manifest и SHA256SUMS; состав/размеры сверены до публикации. Релиз опубликован как prerelease, make_latest=false. Старые теги/вложения не менялись.

Опубликованный ZIP скачан в builds/alpha5-downloaded, SHA256 архива и всех файлов manifest совпали. Графический запуск распакованной игры PASS (artifacts/alpha5-downloaded-startup.log). Тем же комплектом обновлена прежняя установка; SHA256 PASS, прежний ярлык сохранён. Тег получен fetch --tags и совпадает с 68d0f03.

## Продолжение

Ручной проход владельцем по опубликованному alpha.5. Следующие исправления выпускать как alpha.6, alpha.5 не подменять. STATUS/HANDOFF/BACKLOG/README/RELEASES обновлены. DA-097 завершена.
