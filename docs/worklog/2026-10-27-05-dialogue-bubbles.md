# 2026-10-27: DA-053 — пузырьки NPC и ответы взглядом

Исполнитель: агент DA-053. Ветка: codex/da053-npc-speech-bubbles. База: 2276812, включает DA-032/DA-052, main 7fea832.

## Выполнено

Владелец принял движения и запросил: речь NPC над головой с набором, перенос в угол при отвороте/намёк на голос сзади, ответы взглядом и цифрами/колесом/F, жирные важные слова без новой фиксации в дневник. На старте рабочая копия чистая, других владельцев общих сцен в BACKLOG нет; сцены редактирует один агент.

Добавлен DialogueBubblePanel поверх прежних Session/Runner. Обзор на месте доступен, тело/выход с места заблокированы. Реплика набирается, угловой пузырёк продолжает речь; ответы доступны после набора и при взгляде на видимого говорящего. Первое F раскрывает текст, следующее подтверждает; цифры выбирают сразу, колесо пропускает закрытые варианты; echo/скрытый/устаревший UI не отвечает. Меню/дневник сохраняют набор/выбор, окончание явно расходует время, Backspace отменяет. Выход из разговора возвращает рабочий ракурс, пауза сохраняет взгляд. Длинная речь/ответы ограничены прокруткой.

DialogueText поддерживает только парное **жирное** без исполнения BBCode. В TEST-репликах выделены существующие слова, новых сюжетов/терминов/эффектов нет. CheckpointCodec нормализует только оформление node.text: точный прежний hash plain-каталога сохраняется, версии JSON v1 не меняются. Прежний grant_term независим от bold. Для нормального/жирного явно выбраны системные MSDF-шрифты: первоначальный fallback давал наложение, просмотренное исправление читаемо.

Изменённые файлы: scripts/dialogue/dialogue_text.gd/.uid, scripts/ui/dialogue_bubble_panel.gd/.uid, scenes/ui/dialogue_bubble_panel.tscn; scripts/main/main.gd, scripts/player/free_roam_camera.gd, scripts/save/checkpoint_codec.gd, scenes/main/main.tscn, content/dialogues/test_guest.json; tests/dialogue_bubble_test.gd/.uid/.tscn, tests/playthrough_test.gd, tools/check.ps1/check_windows_export.ps1. Документы: README, STATUS/HANDOFF/BACKLOG/CONCEPT/ROADMAP, DIALOGUE_BUBBLES, DIALOGUE_RUNTIME/DIALOGUE_CONTENT/FREE_ROAM, ARCHITECTURE/CONTRACTS/SAVES/ASSETS/TESTING/BUILD/PLAYTEST, task DA-053, ADR-0021, индексы. Файлы шрифтов не добавлены.

## Проверки

Windows, Godot 4.7.2.stable.official.ed1daf0bf, Compatibility, RTX 5060.

| Команда / сценарий | Фактический результат |
| --- | --- |
| check.ps1 после первой интеграции | PASS: все прежние наборы, включая пеший цикл 63 и checkpoint 51; artifacts/da053-regression.log |
| dialogue_bubble_test headless после возврата камеры | PASS 40/0, artifacts/da053-bubbles-final.log |
| GPU 1280×720 / 960×600 с capture-dir | PASS на промежуточных тестах; 43/40 соответственно, до последних проверок возврата/мыши; artifacts/da053-bubbles-final-graphics.log и da053-bubbles-small.log |
| Визуальный просмотр | Снимки typing/replies/behind/long в обычном/минимальном окне; проверены жирное/перенос/границы, устранено наложение шрифта |

Итоговый код: `6296a807a8e0076aadc1d708c14b9f62ee113e7e`.

- Чистый Git archive без .godot: полный check.ps1 PASS, включая речь 40, пеший цикл 63, checkpoint 51, отдельные процессы 2/5 и прежние наборы; artifacts/da053-clean-source.log.
- tools/build_windows.ps1: PASS, builds/windows-20261027-015238-cdde16e6.zip, manifest source_dirty=false, artifacts/da053-build.log.
- tools/check_windows_export.ps1 -BuildDirectory builds/windows-20261027-015238-cdde16e6 -Graphics: PASS. Речь 40 headless/42 GPU (две дополнительные — захват и реальное движение мыши); пеший цикл 63/64, checkpoint 51/53, процессы 2/5, прежний цикл 50, книга 51, экран 46, лица 22/38, детализация 18. artifacts/da053-export.log, builds/validation-97a24ff6c6474015bbeb19dd1470b812.
- ZIP распакован отдельно: SHA256 всех файлов manifest совпали, EXE стартовал без редактора/ошибок. git diff --check и ссылки новых документов PASS.

Архив локальный, игнорируется Git. После 6296a80 обновлены только документы/статусы/план; новый GitHub-релиз не опубликован. Ветка передаётся на origin для команды.

## Решения и ограничения

[ADR-0021](../decisions/0021-dialogue-bubbles.md), [DIALOGUE_BUBBLES](../DIALOGUE_BUBBLES.md), [CONTRACTS](../CONTRACTS.md). Скорость 38/с и конус 20° — первые параметры для плейтеста. Сейчас один привязанный NPC; несколько одновременно говорящих не реализованы. Новая обработка важных слов дневником отложена по запросу владельца. Кнопки моделей Session сохраняют программный API без ожидания набора, пользовательский ввод проверяет панель. Старые fixtures остаются legacy, новый путь отдельный. Другая ОС/машина и субъективный комфорт не проверены.

## Продолжение

Пользователю пройти DIALOGUE_BUBBLES/PLAYTEST: прочитать, отвернуться, ответить колесом/F и цифрой, открыть книгу посреди набора, закончить смену. Оценить скорость/угловой указатель/удобство клавиш; после этого Q-04/DA-040, без выдумывания канонического сюжета. Новый концепт записей и реалистичные лица остаются отложенными. Для коллег: чистый clone, Godot 4.7.2, check.ps1, отдельный dialogue_bubble_test; пользовательские файлы не нужны. STATUS/BACKLOG обновлены, техническая задача done. Слияния/удаления веток/публикации релиза не выполнялись.
