# 2026-10-26: DA-034 — дневник-книга

Исполнитель: агент DA-034. Ветка: `codex/da034-journal-book`. Базовый коммит: `209cdd0`. origin/main при fetch — `07bed83`; предыдущие этапы включены в ветку. Внешняя публикация/слияние main не выполнялись.

## Выполнено

2.5D-книга с обложкой, переплётом, бумагой, разворотом и лентой. Анимации открытия/закрытия/листания, сокращённый/выключенный режим и собственный синтезированный шелест с отдельной громкостью. Кириллица остаётся чёткой поверх PS1-эффекта мира. Индекс, поиск, источники и закладки DA-033 сохранены.

BookPaginator разбивает исходный текст по фактическому шрифту/размеру. Journal хранит смещение символа reading_offset, которое переживает обычные смены; resize не переписывает прогресс. Закрытие отменяет незавершённый переход, меню приостанавливает его, быстрый ввод блокируется. Прочитанность выставляется после открытия. Пользовательское закрытие анимировано, прежний close_journal оставлен синхронным.

Изменены: `scripts/journal/journal.gd`, новый `book_paginator.gd`/uid; `scripts/ui/journal_panel.gd`, новый `book_art.gd`/uid; `scripts/session/narrative_session.gd`, `scripts/main/main.gd`; `scenes/ui/journal_panel.tscn`, `navigation_hud.tscn`, новый `book_theme.tres`; новый `tests/book_test.gd`/uid/tscn, journal_core/playthrough и прежние изолированные тесты; `tools/check.ps1`, `check_windows_export.ps1`, новый `capture_book_preview.gd` и прежние команды снимков. Документы: README, STATUS/BACKLOG/HANDOFF, ARCHITECTURE/CONTRACTS, JOURNAL_CORE/PLAN/BOOK, ROADMAP, TESTING/PLAYTEST/SETUP/BUILD/ASSETS, ADR-0011, карточка DA-034 и индексы решений/сессий. Общие сцены редактировал один агент; локальная отметка не резервирует их на общем сервере.

## Проверки

Окружение: Windows, Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility, NVIDIA RTX 5060. Команды ниже предполагают console executable Godot в PATH; локальный путь движка не является настройкой проекта.

| Команда / сценарий | Фактический результат |
| --- | --- |
| `pwsh -NoProfile -File tools/check.ps1 -Godot godot` | PASS: импорт, smoke, навигация, контент, dialogue 70, service 54, shift 63, presentation 12, commute 31, journal core 50, book 51, полный цикл 50, штатный startup |
| `godot --path . --script tools/capture_book_preview.gd --resolution 1280x720` | PASS: cover/open/ribbon/turn/second_entry/settings/closing/home/long_page_1/long_page_2 созданы и просмотрены |
| Та же команда `--resolution 960x600 -- --small` | PASS: минимальное окно, длинные страницы/настройки читаются, снимки просмотрены |
| `pwsh -NoProfile -File tools/build_windows.ps1 -Godot godot` | PASS: обычный EXE/PCK/ZIP/manifest/инструкция/уведомления |
| `pwsh -NoProfile -File tools/check_windows_export.ps1 -Godot godot -BuildDirectory builds/windows-<id>` | PASS: штатный старт, 50 сквозных проверок, 51 проверка книги на release template headless |
| `Dark Alone Validation.exe --log-file <path> -- --book-check` | PASS: 51 проверка книги с реальным renderer Compatibility/RTX 5060, ошибок нет |
| `git diff --check` | PASS: ошибок пробелов нет |
| Полный check.ps1 на чистом Git tree без `.godot/` | PASS: все наборы, включая book 51 и полный цикл 50 |
| Проверка относительных ссылок Markdown | PASS: все цели существуют |

Логи и изображения находятся в игнорируемой `artifacts/`, экспортные логи — `builds/validation-<id>/`. Старые проверки изолируют анимации режимом off, новый book_test проверяет все режимы/прерывания, полный цикл использует full. Перенос смещения проверен в двух настоящих переходах обычной смены journal_core_test.

## Решения и ограничения

[ADR-0011](../decisions/0011-journal-book.md), [CONTRACTS](../CONTRACTS.md), [JOURNAL_BOOK](../JOURNAL_BOOK.md). 2.5D выбран по читаемости и объёму; отдельный 3D-прототип не создавался, физики бумаги нет. Системные шрифты только запрашиваются у ОС, не поставляются; fallback/перепагинация предусмотрены. На другой машине и физическими нажатиями Windows не проверялось. Субъективная оценка убедительности — PLAYTEST. Дисковых сохранений/досье/связей нет, M3 целиком не завершён.

## Продолжение

Следующий независимый шаг — DA-035: занять задачу, сделать нейтральные TEST-варианты лиц и сравнить у стойки с ретро-эффектом, без опоры на одежду/подписи. Канонические персонажи требуют Q-04. DA-032 требует Q-06, досье/связи Q-09. STATUS/BACKLOG обновлены. Начать с JOURNAL_BOOK/CONTRACTS, если дорабатывается книга; не изменять общую сцену параллельно с другим редактором.
