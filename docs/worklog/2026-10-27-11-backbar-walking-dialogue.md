# 2026-10-27: DA-059 — задняя стойка и ходьба в разговоре

Исполнитель: агент DA-059. Ветка codex/da059-backbar-and-walking-dialogue, база e7f2fc4, включает DA-057/058. Старт с чистой рабочей копии; Main редактировал один агент, чужих незавершённых правок не было.

## Выполнено

Исправлена интерпретация владельца: рабочая поверхность за спиной бармена, у полок, а не прилавок перед NPC. Независимая back_counter.tscn с коллизиями, позой WorkPosition и неинтерактивными TEST-бутылками; Main создаёт якорь back_counter и связывает поверхность/полки с прежним WorkstationTarget. Передний прилавок остаётся физическим препятствием. Рабочий ракурс направлен вниз к поверхности; legacy counter/граф/дом прежние.

В DIALOGUE Main разрешает WASD и обзор; при начале из focus возвращает камеру к физическому телу и прежнему взгляду. Реплика/страница/набор продолжаются при отходе, ответы по взгляду/видимости прежние. Отмена/конец сохраняют фактическую позицию. Menu/Journal блокируют тело и речь; ходьба не расходует время. Подготовка напитков одновременно с речью записана будущей DA-060; текущая подача по-прежнему отдельный режим после разговора.

Изменены: scripts/main/main.gd, scripts/ui/navigation_hud.gd, scenes/levels/back_counter.tscn; tests/world_target_test.gd, dialogue_bubble_test.gd, free_roam_test.gd. Документы: README; STATUS/HANDOFF/BACKLOG/ARCHITECTURE/CONTRACTS; WORLD_INTERACTION/FREE_ROAM/DIALOGUE_BUBBLES/PLAYTEST/TESTING/BUILD; task DA-059, ADR-0025 и индексы. Новых зависимостей/JSON-схем/сохранений нет.

## Проверки

Godot 4.7.2.stable.official.ed1daf0bf, Windows, Compatibility/RTX 5060.

| Команда / сценарий | Фактический результат |
| --- | --- |
| Профильные headless после изменения поведения | PASS world_target 26, dialogue_bubble 109, free_roam 67; artifacts/da059-*.log |
| tools/check.ps1 | PASS всех наборов до финального уточнения ракурса; artifacts/da059-regression.log |
| GPU с capture-dir | PASS world_target 29, dialogue_bubble 116; artifacts/da059-*-gpu.log |
| GPU --small | PASS мир 29, пеший цикл 71 до последнего уточнения декоративных бутылок/дальности отхода; artifacts/da059-*-small.log |
| Финальный GPU 1280×720 | PASS мир 31, включая 3 PNG, поверхность/полки/корпус; artifacts/da059-final-target-gpu.log |

Итоговый код d1749eda66e6199707ebc16b201dd7f61c744887.

- Чистый Git archive без .godot: весь tools/check.ps1 PASS, включая мир 28, речь 109, пеший цикл 67; artifacts/da059-clean-source.log.
- tools/build_windows.ps1 PASS: builds/windows-20261027-145926-b50f09db.zip, manifest source_dirty=false; artifacts/da059-build.log.
- tools/check_windows_export.ps1 -BuildDirectory builds/windows-20261027-145926-b50f09db -Graphics PASS: мир 28/28, речь 109/111, пеший цикл 67/68, checkpoint 51/53 + процессы 2/5, настройки 30/34 + процессы 2/3 + GPU read 4, прежний цикл 50, книга 51, экран 46, лица 22/38, детализация 18. artifacts/da059-export.log; builds/validation-2ebd1f51ebf645ef9ca2b26c4bc9ca49.
- Архив распакован в отдельную папку builds/da059-zip-check: все SHA256 совпали, обычный EXE --headless --quit-after 5 завершился без ошибок; artifacts/da059-zip-startup.log.
- Просмотрены PNG задней поверхности в 1280×720/960×600, пузырёк голоса за спиной; исправлена пересекающая полку высота декоративных бутылок. Финальный ракурс показывает рабочую поверхность, подписи читаемы.
- git diff --check и относительные ссылки новых документов PASS. Последующий коммит меняет только итоговую документацию.

## Решения и ограничения

[ADR-0025](../decisions/0025-backbar-walking-dialogue.md), [CONTRACTS](../CONTRACTS.md). Публичные методы прежние, поведенческие потребители обновлены вместе. SERVICE пока исключает речь; DA-060 потребует отдельной модели параллельных состояний, не включать это молча. Субъективное удобство владельцу проверить вручную; другой физический ПК пока не проверялся. M3 не завершён, сюжет отложен.

## Продолжение

Задача завершена. Следующий конкретный шаг — пройти новый билд вручную и согласовать простой процесс DA-060 и изменить контракт Session, чтобы обслуживание не закрывало реплику. Готовить только технический TEST-контент. STATUS и BACKLOG обновлены: да, done для DA-059; DA-060 остаётся todo. В main не вливалось, релиз не публиковался.
