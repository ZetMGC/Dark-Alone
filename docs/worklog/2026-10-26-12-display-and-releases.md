# 2026-10-26: DA-037 — экран и тестовые релизы

Исполнитель: агент DA-037. Ветка: `codex/da037-display-and-releases`. База: `6294b34`. На начало сессии рабочая копия чистая. origin/main при fetch по-прежнему `07bed83`; владелец сообщил о намерении слить ветки, подтверждённого нового main пока нет.

## Выполнено

F11 и меню переключают окно/обычный fullscreen в native разрешении. Доступен список мониторов, возврат восстанавливает окно или развёрнутый режим. UI canvas_items/expand от 1280×720 сохраняет пропорции на широких/высоких экранах, минимум 960×600. Настройки меню в прокрутке, кнопки продолжения/выхода отдельно. Параметры живут в памяти процесса, игровой прогресс не меняется. Обнаружена и исправлена подпись единственного монитора: теперь всегда показано разрешение, даже когда число пунктов совпадает с начальным placeholder.

Для релизов подготовлены RELEASES, шаблон NEXT и prepare_release.ps1: чистый точный origin/main, проверки, Windows ZIP, manifest, SHA256, заметки. Скрипт не публикует и не создаёт тег; порядок draft → pre-release описан отдельно. DA-039 ожидает слияния в main. Более реалистичная подача записей DA-038 ожидает концепт владельца, запрос записан в CONCEPT/JOURNAL_PLAN/BACKLOG без придуманных решений.

Изменённые файлы: `project.godot`, `scenes/main/main.tscn`, `scenes/ui/navigation_hud.tscn`, `scripts/main/main.gd`; новый `scripts/presentation/display_settings.gd`/uid; новый `tests/display_test.gd`/uid/tscn, `tests/playthrough_test.gd`; `tools/check.ps1`, `check_windows_export.ps1`, новый `prepare_release.ps1`. Документы: README, ARCHITECTURE/CONTRACTS/CONCEPT, BACKLOG/STATUS/HANDOFF, JOURNAL_PLAN, BUILD/TESTING/PLAYTEST, DISPLAY/RELEASES/releases/NEXT, DA-037, ADR-0012 и индексы. Main/HUD редактировал один агент, иной локальной работы не было.

## Проверки

Окружение: Windows, Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility/NVIDIA RTX 5060, один физический монитор 1920×1080. Движок/экспортные шаблоны прежние, без обновления.

| Команда / сценарий | Фактический результат |
| --- | --- |
| `pwsh -NoProfile -File tools/check.ps1 -Godot godot` | PASS: все прежние наборы, book 51, полный цикл 50; первоначальный display 32 |
| `godot --headless --path . res://tests/display_test.tscn` после расширения матрицы | PASS: 46 проверок, включая разговор/обслуживание |
| Графический display_test с `-- --capture-dir=<path>` | PASS: первоначально 55 с 15 снимками, затем расширенная матрица проверена в экспортном сценарии ниже |
| `pwsh -NoProfile -File tools/build_windows.ps1 -Godot godot` | PASS: Windows EXE/PCK/ZIP/manifest, предварительная сборка |
| `pwsh -NoProfile -File tools/check_windows_export.ps1 -Godot godot -BuildDirectory builds/windows-<id>` | PASS: штатный старт, полный цикл 50, book 51, display 46 headless на release template |
| PowerShell Parser для prepare_release.ps1 | PASS: синтаксических ошибок нет |
| prepare_release.ps1 на грязном дереве | PASS: отказ до сборки/публикации |
| Полный check.ps1 на чистом Git tree без `.godot/` | PASS: все наборы, display 46, book 51, полный цикл 50 |

Снимки исходного запуска — `artifacts/da037-display-final/`, фактические PNG от 960×600 до 3840×2160 соответствовали запрошенным размерам. Проверены menu/book в 16:10/16:9/4:3/21:9, реальные F11/native fullscreen, режим через меню, повтор клавиши и возврат размера. Логи — игнорируемая artifacts, экспорт — builds/validation-<id>.

Графический Windows Validation `-- --display-check --capture-dir=<path>` прошёл 83 проверки без ошибок, включая 29 снимков меню/книги/разговора/обслуживания и fullscreen. Снимки минимального окна, 4:3, ultrawide и 4K просмотрены; фактические PNG имеют требуемые размеры. Логи: `builds/validation-a9b6c06ae2e64f57813bb96f4da8d105/`, снимки `artifacts/da037-export-display/`. `git diff --check` и относительные Markdown-ссылки — PASS.

## Решения и ограничения

[ADR-0012](../decisions/0012-display-and-test-releases.md), [CONTRACTS](../CONTRACTS.md), [DISPLAY](../DISPLAY.md), [RELEASES](../RELEASES.md). Headless не подтверждает управление окнами и отклоняет его. Доступен один физический экран: перевод на другой монитор/горячее отключение и другие DPI Windows не проверены, 4K/ultrawide проверены размером окна/рендера, не физическим монитором. Физические клавиши посылаются тестом через viewport, не Windows. Производительность на минимальном железе остаётся Q-07.

Полный prepare_release.ps1 и публикация пока не выполнялись: main ещё не содержит слияния. Нет опубликованного GitHub Release/тега, CI и изменений публичности/лицензии. Конкретный первый номер `v0.1.0-alpha.1` предложен для тестов, не создан.

## Продолжение

Первым делом DA-039: после слияния владельцем обновить чистый main, выполнить prepare_release.ps1, дополнить NEXT фактическими графическими результатами, загрузить три артефакта в draft GitHub и выпустить pre-release; скачать/проверить как коллега. Затем TEST-лица DA-035. DA-038 ждёт концепт записей; не придумывать его. STATUS/BACKLOG/HANDOFF обновлены, финальные результаты ниже.
