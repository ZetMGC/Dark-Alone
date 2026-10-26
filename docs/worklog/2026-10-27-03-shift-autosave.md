# 2026-10-27: DA-032 — автосохранение между сменами

Исполнитель: агент DA-032. Ветка: codex/da032-shift-autosave. Базовый коммит: 7fea832.

## Выполнено

Проверена работа коллег DA-047–DA-051: петля гула, тихое окружение и настройки камеры, исследуемый TEST-дом, ровный горизонт и интеграция в main. Исходный полный check.ps1 PASS, посторонних незавершённых изменений не было. feat/game-improvements сохранена. Отменённые DA-045/046 не возвращались.

Владелец выбрал Q-06: автосохранение между сменами. Реализованы checkpoint v1, строгая атомарная загрузка Journal/HomeState, запись начала новой смены после дома, резервное восстановление, сообщение ошибки и подтверждённый новый старт. При запуске свежие часы/заказ/Runner. Тесты и снимки изолированы от пользовательского файла.

Изменённые файлы: scripts/save/checkpoint_codec.gd и checkpoint_store.gd с UID, scripts/journal/journal.gd, scripts/home/home_state.gd, scripts/main/main.gd, scripts/ui/navigation_hud.gd, scenes/ui/navigation_hud.tscn; tests/checkpoint_test.gd/.uid/.tscn, tests/playthrough_test.gd, все прежние тесты с Main-fixtures; tools/check.ps1/check_windows_export.ps1 и capture_* с Main. Документы: README, STATUS/HANDOFF/BACKLOG/CONCEPT/ROADMAP, SAVES, ARCHITECTURE/CONTRACTS, HOME/JOURNAL_CORE/BUILD/PLAYTEST/TESTING, task DA-032, ADR-0019 и индексы. Новых художественных ресурсов нет.

## Проверки

Окружение: Windows, Godot 4.7.2.stable.official.ed1daf0bf, Compatibility, RTX 5060.

| Команда / сценарий | Фактический результат |
| --- | --- |
| tools/check.ps1 -Godot <Godot 4.7.2> до изменений | PASS, artifacts/da052-baseline.log (имя предварительное, DA-052 не создавалась) |
| Полный check.ps1 после реализации | PASS, artifacts/da032-full-check.log; прежние наборы, checkpoint 47 на промежуточном состоянии |
| checkpoint_test после отрицательных загрузок Main | PASS, 51/0, artifacts/da032-checkpoint-final.log |
| check_windows_export.ps1 -BuildDirectory builds/windows-20261027-005907-9db042fd -Graphics | PASS: startup, цикл 50, книга 51, экран 46, лица 22/38, checkpoint 51/53, процессы write/read 2/5, detail 18; artifacts/da032-export.log |
| Меню/подтверждение на GPU | PASS, снимок artifacts/da032-save/da032_checkpoint_menu.png просмотрен; отмена не меняет checkpoint |
| Итоговый tools/check.ps1 | PASS: checkpoint 51, процессы 2/5 и все прежние наборы; artifacts/da032-final-check.log |
| git diff --check | PASS |

Промежуточная сборка выше имеет source_dirty=true; это локальная проверка, не опубликованный релиз. Итоговый чистый Windows-архив и повторная проверка фиксируются отдельной записью ниже после сборки.

## Решения и ограничения

[ADR-0019](../decisions/0019-shift-checkpoint.md), [SAVES](../SAVES.md), [CONTRACTS](../CONTRACTS.md). Внутри смены/дома запись не выполняется; настройки только в памяти. Формат строгий по контенту, миграций нет. Резервная запись не гарантирует сохранность при отключении питания; одновременные экземпляры не блокируются. Другой компьютер/физические нажатия человеком не проверялись. Персонажи DA-035 и концепт записей DA-038 отложены; M3 целиком не закрыт. Main и опубликованный alpha.2 не менялись этой веткой.

## Продолжение

Команде выполнить ручной сценарий SAVES/PLAYTEST: завершить смену, осмотреть дом, вернуться на работу, закрыть и снова открыть EXE. Следующая содержательная задача — согласовать Q-04 и две истории DA-040; без решения владельца канонический контент не придумывать. Для продолжения достаточно чистого клона и check.ps1; пользовательский checkpoint не нужен. STATUS и BACKLOG обновлены.
