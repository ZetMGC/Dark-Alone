# 2026-10-28: DA-068 — закрытая книга и цепочки выводов

Исполнитель: агент дневника. Ветка: codex/da068-closed-journal-reasoning-chains. Базовый коммит: 9f695f0. Общая journal_panel.tscn была единолично занята этой задачей, теперь освобождена; main.tscn не изменена.

## Выполнено

J достаёт закрытую книгу, клик раскрывает. До раскрытия блокируются страницы/закладки/чтение; открытие не расходует смену. Full раскрывает обложку между стабильными снимками actual UI, target удерживается до раскладки; full/reduced/off/пауза проверены. Вывод внутри единого обведения, стрелка от границы к границе.

Options могут требовать другие conclusions; words_ready отделён от ready. Source_conclusion-связь ведёт ко второй уже собранной группе после первого вывода; её варианты зависят от версии. Зависимый record хранит premises, restore проверяет их атомарно и принимает обратный порядок. Validator отвергает неизвестные предпосылки/циклы.

По дополнительному прямому поручению владельца создан отдельный вымышленный TEST-разговор про войну/битвы/оружие/ящики. Две основные трактовки и четыре последующих ответа гостя; ответ можно не выбирать и уйти. Наследованная demo-сцена отключает реальные сохранения/настройки. Основной intro и канон не подменены.

## Проверки

Godot 4.7.2 stable, Windows, GPU Compatibility / NVIDIA RTX 5060. Переменная <Godot> ниже — исполняемый файл установленного движка, без локального пути в репозитории.

| Команда / сценарий | Окружение | Фактический результат |
| --- | --- | --- |
| `tools/check.ps1 -Godot <Godot>` | source/headless | PASS: общий набор, journal core 57, ink 236, playthrough 50, запуск; ошибок нет |
| `tools/check_journal_ink.ps1 -Godot <Godot> -Graphics` | source/headless + GPU 1280×720/960×600 | PASS: ink 236/250/250, book 51, checkpoint 51 |
| Windows Validation export + EXE `--journal-ink-check`, затем GPU и `--small` | локальная release-сборка | PASS: 236 headless / 250 / 250, экспорт без ошибок |
| `godot --path . --script res://tools/capture_reasoning_preview.gd` | source/GPU | PASS: отдельная demo-сцена загрузилась, кадры raise/unfold/turn/section/close и notes сняты и просмотрены |
| target/live inner-paper pixel comparison | source/GPU | Для словаря и обложки bad fraction 0.000230 / 0.000337 на двух размерах, ниже порога 0.005 |
| `git diff --check` | исходники/документы | PASS |

Локальные игнорируемые свидетельства: artifacts/da068-common.log, da068-journal.log, da068-export.log, da068-capture.log, da068-motion/; Windows exe — builds/da068-validation-bd34347a721b4eaeb93a8a90f31524a8/. Профили проверяют все четыре цепочки/ответа, блокировку чужой версии, обратный порядок restore/подделку premises, закрытую обложку/фактический клик/паузу/режимы. Исторические проверки страниц теперь явно используют open_journal(true); игровой путь по умолчанию закрытый.

## Решения и ограничения

[ADR-0031](../decisions/0031-closed-book-reasoning-chains.md), [контракт](../JOURNAL_REASONING.md), [демо](../REASONING_DEMO.md). Интерфейс не определяет истину, варианты и связи задаёт сценарист. Одна версия на группу, для другой версии перезапуск TEST-сцены. Автосохранение по-прежнему между сменами; сохранения посреди разговора не добавлены. Новые optional premises не меняют checkpoint v1; обычный main catalog/hash прежний. Слияние/публикация/удаление веток не выполнялись; alpha.3 неизменен.

## Продолжение

Открыть scenes/main/reasoning_demo.tscn в редакторе, F6, пройти разговор, J/клик/«Заметки», проверить две основные цепочки с перезапуском между ними. Записать оценку читаемости/анимации и выбора; сюжетные версии отдельно согласовать. STATUS/BACKLOG/HANDOFF и задача обновлены, DA-068 done. Ничего частично реализованного в пределах задачи не осталось; человеческая оценка художественного качества впереди.

## Изменённые файлы

- `README.md`
- `content/dialogues/test_war_cinema_guest.json`
- `content/glossary/test_war_cinema_terms.json`
- `docs/ARCHITECTURE.md`
- `docs/BACKLOG.md`
- `docs/CONCEPT.md`
- `docs/CONTRACTS.md`
- `docs/DIALOGUE_CONTENT.md`
- `docs/HANDOFF.md`
- `docs/JOURNAL_BOOK.md`
- `docs/JOURNAL_REASONING.md`
- `docs/PLAYTEST.md`
- `docs/REASONING_DEMO.md`
- `docs/SAVES.md`
- `docs/STATUS.md`
- `docs/TESTING.md`
- `docs/decisions/0031-closed-book-reasoning-chains.md`
- `docs/decisions/README.md`
- `docs/tasks/DA-068.md`
- `docs/worklog/2026-10-28-05-closed-book-reasoning-chains.md`
- `scenes/main/reasoning_demo.tscn`
- `scenes/ui/journal_panel.tscn`
- `scripts/journal/journal_reasoning.gd`
- `scripts/session/narrative_session.gd`
- `scripts/ui/book_art.gd`
- `scripts/ui/journal_panel.gd`
- `scripts/ui/journal_paper_pages.gd`
- `tests/book_test.gd`
- `tests/commute_test.gd`
- `tests/display_test.gd`
- `tests/guest_service_test.gd`
- `tests/home_test.gd`
- `tests/image_detail_test.gd`
- `tests/journal_core_test.gd`
- `tests/journal_ink_test.gd`
- `tests/parallel/home/house_layout_test.gd`
- `tests/release_integration_test.gd`
- `tests/shift_clock_test.gd`
- `tools/capture_art_preview.gd`
- `tools/capture_book_preview.gd`
- `tools/capture_commute_preview.gd`
- `tools/capture_journal_preview.gd`
- `tools/capture_narrative_preview.gd`
- `tools/capture_reasoning_preview.gd`
- `tools/capture_shift_preview.gd`
- `tools/validate_content.gd`
