# Сборка и передача Windows

DA-024: Windows x86_64, Godot 4.7.2 Standard, Compatibility. Это текущая тестовая платформа, не утверждённые минимальные требования. Полная проверка другой машины остаётся команде.

## Подготовка

Для повторяемого комплекта GitHub Pre-release после слияния main использовать [RELEASES](RELEASES.md) и `tools/prepare_release.ps1`. Сначала проверка/сборка из точного commit main, затем draft с ZIP/manifest/SHA256 и публикация отдельным шагом.

Установить export templates **точно 4.7.2 stable** через Godot → Editor → Manage Export Templates либо из [официального архива](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable). Для Windows нужны `windows_release_x86_64.exe` и `windows_debug_x86_64.exe` в каталоге шаблонов `4.7.2.stable`. При скачивании полного TPZ сверять SHA512 с `SHA512-SUMS.txt` того же релиза. Шаблоны и движок не входят в Git.

Рабочий источник должен быть закоммичен: архив содержит manifest с source_revision и source_dirty. Для передачи коллегам использовать source_dirty=false, чтобы состояние можно было восстановить из Git.

## Команды

Из корня, с godot в PATH; иначе заменить аргумент на абсолютный путь к console executable:

```powershell
pwsh -NoProfile -File tools/check.ps1 -Godot godot
pwsh -NoProfile -File tools/build_windows.ps1 -Godot godot
pwsh -NoProfile -File tools/check_windows_export.ps1 -Godot godot -BuildDirectory 'builds/windows-<идентификатор из вывода>'
```

Сборщик создаёт новую папку и ZIP в игнорируемой `builds/`, сохраняя предыдущие результаты. Внутри: `Dark Alone.exe`, соседний `Dark Alone.pck`, инструкция `START-HERE.md`, `legal/` с уведомлениями Godot и `build-manifest.json` с SHA256 файлов, UTC-временем, версией движка и состоянием исходников. ZIP включает всю папку; передавать/распаковывать её целиком.

`check_windows_export.ps1` проверяет старт обычной сборки и отдельно экспортирует Windows Validation для сквозного прохода. Это настоящий release template, без редактора. Логи находятся в новой `builds/validation-<id>/`. Каждый запущенный процесс ограничен 45 секундами. Положительный результат требует кода 0, отсутствия ошибок и строки `PASS: full playthrough, N checks, 0 failures` (N — число проверок текущего сценария; DA-033: 50). Проверочная сборка не предназначена игрокам.

Для графического прохода запустить проверочную `.exe` с `--log-file <абсолютный путь>`; опция после `--` вида `--capture-dir=<абсолютный каталог>` сохраняет снимки двух итогов и добавляет две проверки записи. Физические нажатия и комфорт оцениваются отдельно по [PLAYTEST](PLAYTEST.md).

## Что важно не потерять

DA-034: checker дополнительно запускает проверочный EXE с `-- --book-check` и требует строку `PASS: journal book, ...` (51 проверка на этой версии). Лог — `book.log` рядом с playthrough.log. Тот же аргумент без headless проверяет графическую книгу; он доступен только в тестовой стартовой сцене пресета Windows Validation. Обычный игровой Main такой режим не содержит.

- `export_presets.cfg` хранится в Git, секреты и бинарные сборки — нет.
- В обоих пресетах явно включён `content/**/*.json`: без него FileAccess не найдёт диалоги/словарь.
- Обычный пресет исключает docs/tools/tests/artifacts/builds. Только Windows Validation включает тесты и feature `integration_test`, выбирающий тестовую начальную сцену через feature override в project.godot. Основной Main не содержит тестовых веток.
- `editor/export/convert_text_resources_to_binary=false`: при включённом преобразовании в этой среде экспорт терял `AnchorPoint.neighbours`, поэтому перемещения не работали. Решение — [ADR-0007](decisions/0007-windows-export.md); не включать обратно без сквозной проверки экспортированной игры.
- Проверочный и обычный PCK отличаются тестовыми ресурсами и начальной сценой. Автотест проходит реальный Main и его публичные команды через ввод/кнопки; старт обычного PCK проверяется отдельно.
- Лицензия собственного проекта не выбиралась. Уведомления Godot не являются лицензией Dark Alone. Публичная публикация и GitHub Releases этой задачей не выполняются.

Основа команд и фильтров — [официальная документация экспорта Godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html).
