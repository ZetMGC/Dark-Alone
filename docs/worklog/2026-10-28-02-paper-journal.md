# 2026-10-28: DA-065 — личный бумажный дневник

Исполнитель: агент дневника. Ветка: codex/da065-paper-journal от c4ccfcc; включает готовую DA-064. В начале рабочая копия чистая. Прежний параллельный раунд принят DA-063; единственным редактором journal_panel.tscn в этой задаче был агент DA-065. Дом/барные сцены не редактировались.

## Выполнено

По прямому запросу и картинке владельца удалены Search/Section/Count/Matches/InkTool/InkUndo/InkRedo. Три бумажные закладки открывают заметки, рецепты и словарь. Пометки слов остаются, вместо выпадающего списка — предметы письма; углы листов листают, лента у сгиба закрывает, верхняя закладывает словарную запись. Контекст возврата Close перенесён из текста в tooltip_text, потребители обновлены. Оглавление словаря/рецептов по восемь заголовков, длинный текст рецепта — по страницам.

JournalNotebook отделён от UI: личный текст, нормализованные места, овалы, направленные стрелки, тексты рецептов, лимиты/ID/атомарная проверка. Письмо прямо на бумаге, drag/Shift-drag/ПКМ/Delete, Ctrl+Enter/Esc. Большая недопустимая правка не теряется при попытке уйти. При вводе букв не срабатывают J/T/B. Меню блокирует скрытую страницу. Смена сохраняет модель и записи, checkpoint прежнего начала следующей смены принимает необязательный notebook. Старые файлы/пометки читаются.

Внешние изображения в репозиторий не добавлены, английские имена/события из референса не скопированы в канон. На снимках только явно TEST-данные, создаваемые тестом в памяти. Пользовательские записи/реальные настройки не затронуты.

## Проверки

Windows, Godot 4.7.2 stable/Compatibility, NVIDIA RTX 5060. Команды из корня, Godot — закреплённая версия:

| Команда / сценарий | Фактический результат |
| --- | --- |
| tools/check_journal_ink.ps1 -Godot <Godot-4.7.2> -Graphics | PASS: journal ink/notebook 156 headless, 162 GPU в 1280×720 и 960×600; book 51/0, checkpoint 51/0 |
| tools/check.ps1 -Godot <Godot-4.7.2> | PASS полного набора: core 52/0, book 51/0, checkpoint 51/0, ink/notebook 156/0, workbench 127/0, совместный цикл 21/0, playthrough 50/0; остальные профили PASS |
| Godot --headless --path . --export-release "Windows Validation" <папка>/"Dark Alone Validation.exe" | PASS; проверочный EXE собран из текущей рабочей копии, не утверждается source_dirty=false/чистый release build |
| Validation.exe --headless -- --journal-ink-check | PASS 156/0 |
| Validation.exe -- --journal-ink-check --capture-dir=<папка> [--small] | PASS 162/0 в каждом размере, по шесть PNG |
| git diff --check | PASS |

Логи: artifacts/da065-paper-final2.log, artifacts/da065-common-final.log. Windows Validation: builds/da065-validation-b06a89697ff0452dba2ab4d64eb79dfb/, export.log/headless.log/normal.log/small.log. Просмотрены исходниковые и экспортированные notes/recipe кадры, кириллица/бумажные закладки читаются, страницы помещаются. Полноценный новый Desktop ZIP/GitHub-релиз не создавались.

При разработке тест обнаружил неправильную проверку числа ключей заметки (семь вместо шести), фокус при отпускании двойного щелчка и устаревшую проверку надписи Close дома; всё исправлено. Предыдущие failed-логи сохранены в artifacts. Последний полный набор PASS. Проверка модели включает JSON/диск, плохие ссылки/строковые координаты/коллизии ID, старый checkpoint/глубокие копии/предел страницы. Реальный ввод проверяет создание, перемещение, связь, отмену, длинный рецепт/углы и непотерю слишком длинного текста. journal_core_test дополнен переносом личного текста через настоящую смену.

## Решения и ограничения

[ADR-0028](../decisions/0028-personal-paper-journal.md), [контракт](../PERSONAL_JOURNAL.md). Личные связи не являются доказанными фактами, рецепты пока не распознают фактический напиток. Нет произвольного свободного штриха/досье/рук/3D-бумаги. История отмен завершённых личных блоков не добавлена. Координаты нормализованы, не сериализуются Control/пиксели. Сохранение только на прежней границе следующей смены; старый EXE может не прочитать новый notebook. Реальная удобность письма/физические мониторы остаются оценкой людей.

## Изменённые файлы

Новые scripts/journal/journal_notebook.gd, scripts/ui/journal_paper_pages.gd, scripts/ui/journal_writing_tools.gd и их .uid; scripts/journal/journal.gd, scripts/ui/journal_panel.gd, scripts/ui/book_art.gd, scenes/ui/journal_panel.tscn; небольшие guards в scripts/main/main.gd и scripts/session/narrative_session.gd. Потребители: tests/journal_core_test.gd, journal_ink_test.gd, shift_clock_test.gd, commute_test.gd, tools/capture_journal_preview.gd. Общие runner/export-entry не менялись: новый набор встроен в существующий journal-ink-check. Документы: README, STATUS, BACKLOG/DA-065 (DA-038 первый проход done), HANDOFF, CONCEPT, ARCHITECTURE, CONTRACTS, PERSONAL_JOURNAL, JOURNAL_BOOK, JOURNAL_CORE, SAVES, PLAYTEST, TESTING, parallel/journal/CONTRACTS, ADR/индекс, этот worklog/индекс.

## Продолжение

Открыть проект из этой ветки в Godot, J → бумажные вкладки; оценить письмо/наведение/читабельность и референс. Затем отдельной задачей дозировка/TEST-рецепты и распознавание фактической порции, до многогранных реакций гостя. Не трактовать свободный текст игрока как исполняемый рецепт или сюжетную истину. Перед слиянием учесть DA-064 в основании; main/ветки коллег не изменять как побочный эффект. Слияние/публикация выполняются по отдельному поручению; alpha.3 неизменён. STATUS/BACKLOG обновлены.
