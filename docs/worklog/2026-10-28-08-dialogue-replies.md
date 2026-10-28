# 2026-10-28: DA-071 — меню ответов и нумерация

Исполнитель: агент диалогов. Ветка: codex/da068-closed-journal-reasoning-chains, база 68822d0. Общая scenes/ui/dialogue_bubble_panel.tscn проверена свободной/занята только этой задачей, теперь освобождена.

## Выполнено

По отзыву владельца VoiceReplies стал компактнее и спокойнее: полупрозрачный фон alpha 0.58, слабая тонкая рамка, спокойный цвет выделения, высота по содержимому/ограниченная прокрутка длинного списка, подсказка 13px. Речь над NPC прежняя.

UI сначала фильтрует доступные ответы. Номера, submit_choice, selected_index, реальные цифры/колесо/F используют один видимый список. Когда reasoning.changed вызывает render, выбранный ID сохраняется даже при вставке открытого варианта перед ним; при исчезновении выбирается первый. Runner перепроверяет доступность как раньше.

Пустой список и terminal не показывают окно ответов. Terminal даёт F завершения отдельной подсказкой. Неактивный Runner скрывает старую речь/панель даже если set_open(false) ещё не вызван. Старый модальный fallback не изменён.

## Проверки

| Команда / сценарий | Окружение | Фактический результат |
| --- | --- | --- |
| `tools/check.ps1 -Godot <Godot 4.7.2>` | Windows source/headless | PASS: полный набор, bubbles 123, journal ink 244, drink core 837, bar service dialogue 52, playthrough 50 и startup |
| `godot --headless --path . res://tests/dialogue_bubble_test.tscn` | headless | PASS: 123 checks, 0 failures |
| `godot --path . res://tests/dialogue_bubble_test.tscn -- --capture-dir=res://artifacts/da071-normal` | GPU Compatibility / NVIDIA RTX 5060, 1280×720 | PASS: 132 checks, 0 failures |
| Та же команда с `--small --capture-dir=res://artifacts/da071-small` | GPU 960×600 | PASS: 132 checks, 0 failures |
| `godot --headless --path . res://tests/bar_service_dialogue_test.tscn` | headless | PASS: 52 checks, 0 failures |
| `git diff --check` | исходники | PASS |

Профиль использует настоящий TEST-каталог войны/кино: fallback становится №1 без дыр, после вывода props появляется №1, fallback №2 и остаётся выбранным по ID. Реальные KEY_1/KEY_2/колесо/F передают нужные choice_id. Отдельно проверены полностью закрытые варианты, их последующее открытие, terminal без окна, inactive Runner, длинная речь/прокрутка/пауза/отход/обслуживание. При первом GPU-прогоне тест наблюдения inactive Runner проверял состояние до очередного _process; добавлено ожидание двух process_frame. Повторные оба GPU/headless прогоны PASS, runtime ради этого не менялся.

Логи artifacts/da071-common.log, da071-bubbles-headless.log, da071-normal.log, da071-small.log, da071-service.log. Просмотрены GPU 06-reasoning-replies.png и 07-terminal-no-card.png: спокойный список двух реплик и отсутствие пустой панели на terminal. Новый Windows export не выполнялся, эта локальная UI-правка применяется к проекту с ярлыка после перезапуска.

## Решения и ограничения

[ADR-0033](../decisions/0033-available-dialogue-replies.md), [контракт](../DIALOGUE_BUBBLES.md). selected_index/submit_choice теперь про видимый список; fixtures обновлены. can_answer true у terminal сохраняется для F, видимость ответов считается отдельно. Модель/JSON/save и канон прежние; закрытые подсказки «нужны записи» в списке ответов больше не показаны. Слияния/релиза нет, alpha.3 прежний.

## Продолжение

Перезапустить игру обычным ярлыком, получить четыре слова, сформировать выводы, вернуться к NPC и проверить номера/выбор, затем завершить F. Оценить читаемость приглушённого оформления. STATUS/BACKLOG/HANDOFF и задача обновлены, DA-071 done; частично реализованных пунктов нет.

Изменённые файлы: scripts/ui/dialogue_bubble_panel.gd, scenes/ui/dialogue_bubble_panel.tscn, tests/dialogue_bubble_test.gd, docs/BACKLOG.md, docs/tasks/DA-071.md, docs/STATUS.md, docs/HANDOFF.md, docs/DIALOGUE_BUBBLES.md, docs/CONTRACTS.md, docs/TESTING.md, docs/REASONING_DEMO.md, docs/decisions/0033-available-dialogue-replies.md, docs/decisions/README.md, этот протокол.
