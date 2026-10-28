# 2026-10-28: DA-066 — слова, выводы и бумажная анимация

Исполнитель: агент дневника. Ветка codex/da066-journal-deductions от 2e2b3af, включает DA-064/065. В начале рабочая копия чистая. Единственный редактор journal_panel.tscn/BookArt — агент DA-066; назначений коллег на незавершённую сцену нет. Дом/барная физика не изменялись.

## Выполнено

Признана и исправлена неверная трактовка DA-065: пользователь не разрешал свободное письмо как механику. Из игрового PaperPages полностью удалены TextEdit, собственные блоки, перетаскивание/свободные стрелки/редактирование рецептов. Вместо них авторский набор групп уже известных слов, расположенных рядом внутри группы и отдельно от других. Замкнутый жест мышью по границам настоящего текста выбирает достаточно слов одной группы; неполный контур/нехватка слов/чужая смесь не создают вывод. Несколько вариантов без оценки истинности, подтверждение записывает ID версии и evidence. Подтверждённая версия не переписывается; Esc после меню сначала отменяет незавершённый выбор.

JournalReasoning независим от UI, определения валидирует Catalogue. Journal добавляет optional conclusions и строгий restore до мутации. Исходные факты не подменяются выводом. Runner получает required_conclusions/missing_conclusions и проверяет условие повторно, UI сообщает нехватку вывода, Session обновляет ответы. Отдельный TEST-диалог test_reasoning_guest_intro демонстрирует разные версии и узлы; основной intro не менялся, сюжет не придумывался. Непустой notebook DA-065 читается/сохраняется архивом без игрового редактора. Добавление метаданных групп не меняет старый content_hash, это проверено.

Анимации: подъём/небольшой поворот/оседание всей книги, раскрытие обложки, 32 изгибающиеся полосы листа с освещением/движущейся тенью/просвечиванием оборота. GPU переносит снимок реального текста. Следующая словарная страница показывается под листом без дублирования старого текста и без ранней мутации прогресса. Пауза/serial cancellation/reduced/off сохранены. tools/capture_reasoning_preview записывает настоящие кадры открытия/листа/смены раздела/закрытия.

## Проверки

Windows, Godot 4.7.2 stable, Compatibility, NVIDIA RTX 5060. Команды из корня:

| Команда / сценарий | Фактический результат |
| --- | --- |
| tools/check.ps1 -Godot <Godot-4.7.2> | PASS полного набора: journal core 57/0, book 51/0, checkpoint 51/0, ink/reasoning 156/0, drink core 837/0, workbench 127/0, совместный цикл 21/0, playthrough 50/0; остальные профили PASS |
| tools/check_journal_ink.ps1 -Godot <Godot-4.7.2> -Graphics | Финальный профиль после уточнения геометрии жеста: 156 headless, 165 GPU в 1280×720 и 960×600, по 8 PNG и проверка текстуры листа |
| Godot --headless --path . --export-release "Windows Validation" <папка>/"Dark Alone Validation.exe" | PASS, текущая рабочая копия; не утверждается чистый source_dirty=false релиз |
| Validation.exe --headless -- --journal-ink-check | PASS 156/0 |
| Validation.exe -- --journal-ink-check --capture-dir=<папка> [--small] | PASS 165/0 в каждом размере |
| Godot --path . --script res://tools/capture_reasoning_preview.gd | PASS, кадры open/turn/section/close просмотрены; нет Script Error |
| git diff --check | PASS |

Логи: artifacts/da066-all-final.log (общий набор), artifacts/da066-final-ink.log (финальная геометрия), artifacts/da066-motion-final.log (открытие/перелистывание), artifacts/journal-ink/{normal,small}/ (PNG). Финальный Windows-профиль: builds/da066-validation-f5203e6749be465ca279d5437ab19c54/ с export/headless/normal/small.log и PNG. Последняя небольшая правка охвата по реальной ширине надписей дополнительно покрыта профильными source/GPU/Windows прогонами после полного набора. Финальный Desktop ZIP/публикация не создавались.

Проверены: неполные знания/скрытые варианты, несколько групп, открытый/закрытый/тесный жест, неработающий скрытый/stale выбор, отмена после меню, запись без редактора, обе версии → разные узлы диалога, прежний hash/файл без conclusions/legacy archive, JSON/диск/реальная следующая смена, подделка evidence/варианта/повтор группы и атомарность, пауза/commit анимации и снимок текста на GPU. В UI-тесте дополнительные TEST-слова/три группы только в памяти, не новый контент мира.

При разработке исправлены типы GDScript/typed Array, дублирующий ID отдельного TEST-диалога, дублирование старого текста под листом, фокус после меню и сравнение архивных float-координат с допуском вместо точного double/Vector2 float32 равенства. Ранние failed-логи сохранены; итоговые прогоны выше PASS.

## Решения/ограничения

[ADR-0029](../decisions/0029-journal-conclusions-and-paper-motion.md), [контракт](../JOURNAL_REASONING.md). Правильность/конкретные сюжетные последствия — задача автора веток, а не зелёная/красная отметка движка. Подготовлен механизм условий и TEST-развилка, основной сценарий не написан. Один вывод на группу, без свободного переписывания; опоры не расходуются. Нет новой стоимости времени/общего сюжетного графа/досье/свободных штрихов. Рецепты — авторские страницы, не распознавание порции. Группы/места задаёт автор; термин без группы остаётся в словаре. Это 2.5D, не физическая 3D-бумага. Реальные мониторы/субъективная удобность остаются оценкой людей.

Сохранение — по прежней границе следующей смены. Старые данные не удаляются, notebook не превращается в факты. ID групп/версий сохранять по смыслу либо готовить миграцию. Дополнения only metadata не изменили прежние термины/intro/hash, но реальная смена сценария требует обычной проверки совместимости.

## Изменённые файлы и продолжение

Новые scripts/journal/journal_reasoning.gd/.uid, content/dialogues/test_reasoning_guest.json, tools/capture_reasoning_preview.gd (CLI-инструмент без созданного движком .uid). Изменены content/glossary/test_terms.json; scripts/dialogue/{dialogue_catalog,dialogue_content_validator,dialogue_runner}.gd; scripts/journal/journal.gd; scripts/session/narrative_session.gd; scripts/ui/{journal_paper_pages,journal_panel,book_art,dialogue_panel,dialogue_bubble_panel}.gd; scenes/ui/journal_panel.tscn; tests/journal_core_test.gd/journal_ink_test.gd. Ранний notebook.gd не удалён, используется только чтением старых данных. Общие runner/Validation-entry уже вызывают этот профиль, новых флагов не потребовалось.

Документы: README, STATUS, BACKLOG/DA-066/будущее DA-036, HANDOFF, CONCEPT, ARCHITECTURE, CONTRACTS, DIALOGUE_CONTENT, JOURNAL_BOOK, JOURNAL_CORE, JOURNAL_PLAN, JOURNAL_REASONING (новый), PERSONAL_JOURNAL (помечен superseded), SAVES, PLAYTEST, TESTING, parallel/journal/CONTRACTS, ADR-0029/индекс/отметка в ADR-0028, worklog/индекс.

Следующий шаг: пройти новый журнал человеком (получить два TEST-термина, обвести слова, выбрать версию, проверить анимации). Затем автор согласует реальные группы/выводы и подключает required_conclusions к утверждённым ответам; не восстанавливать ошибочный редактор DA-065. Физическая общая сцена свободна после завершения. Слияние/публикация не поручались, main и alpha.3 не изменены; тег не подменять. STATUS/BACKLOG обновлены.
