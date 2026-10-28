# 2026-10-28: DA-070 — выбор вывода в пузырьке

Исполнитель: агент дневника. Ветка: codex/da068-closed-journal-reasoning-chains, база 612ffa0.

## Выполнено

По прямому отзыву владельца заменена отдельная область вариантов справа на компактный всплывающий пузырёк у точки группы. Rounded-подложка/мягкая тень/указатель на точку, высота по переносу, сдвиг влево/вверх у границ, hover строк/курсор руки. Мышь подтверждает; снаружи/Esc отменяет. Номера/цифровой выбор убраны. После выбора прежний conclusion остаётся в круге и открывает зависимые версии/ответы. Модель/JSON/save не менялись, общие сцены не заняты/не редактировались. Обычный ярлык использует эти исходники, перезапуск обновляет UI.

## Проверки

| Команда / сценарий | Окружение | Фактический результат |
| --- | --- | --- |
| `tools/check_journal_ink.ps1 -Godot <Godot 4.7.2> -Graphics` | Windows source, headless + Compatibility GPU, 1280×720/960×600 | PASS: ink 244 / 259 / 259, book 51, checkpoint 51 |
| UI-сценарии профиля | реальные mouse input | PASS: popup-строки в границах с обеих сторон, клик снаружи отменяет без закрытия книги, цифра не подтверждает, клик строки пишет версию, после commit повтор не меняет |
| `godot --path . --script res://tools/capture_reasoning_preview.gd -- --capture-dir=res://artifacts/da070-motion` | GPU / TEST-диалог | PASS; popup-first.png и popup-second.png просмотрены, варианты у соответствующей точки, заметки/стрелки сохраняются |
| `git diff --check` | исходники | PASS |

Логи: artifacts/da070-journal.log, artifacts/da070-capture.log, снимки artifacts/journal-ink/normal и small/05-conclusion-options.png, 05b-right-conclusion-options.png. Полный check/новый Windows export не запускались, поскольку меняется локальное отображение/ввод и профиль покрывает затронутые потребители. Старые показатели DA-068/069 не выдаются за повторные проверки.

## Решения и ограничения

[ADR-0032](../decisions/0032-conclusion-popup.md), [контракт](../JOURNAL_REASONING.md). Mouse-only выбор по запросу, Esc оставлен для отмены. Публичный get_option_rect сохраняет локальные координаты, неверный индекс теперь пустой rect; потребители обновлены. Канон, основной стартовый TEST-сценарий, реальные файлы игрока и alpha.3 не менялись. Слияния/публикации нет.

## Продолжение

Перезапустить игру с прежнего ярлыка, получить слова во второй реплике, J/обложка/«Заметки», нажать точку и выбрать мышью. Проверить удобство и читаемость пузырька. STATUS/BACKLOG/HANDOFF обновлены, DA-070 done, частично готовых пунктов нет.

Изменённые файлы: scripts/ui/journal_paper_pages.gd, tests/journal_ink_test.gd, tools/capture_reasoning_preview.gd, docs/BACKLOG.md, docs/tasks/DA-070.md, docs/STATUS.md, docs/HANDOFF.md, docs/JOURNAL_BOOK.md, docs/REASONING_DEMO.md, docs/JOURNAL_REASONING.md, docs/CONTRACTS.md, docs/decisions/0032-conclusion-popup.md, docs/decisions/README.md, этот протокол.
