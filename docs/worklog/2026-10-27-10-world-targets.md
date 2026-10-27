# 2026-10-27: DA-058 — наведение на стойку и посетителя

Исполнитель: агент DA-058. Ветка codex/da058-world-interaction-targets, база 53f3064, включает DA-057. На старте рабочая копия чистая, иных владельцев общих сцен не обнаружено; Main/HUD/guest-сцену редактировал один агент.

## Выполнено

По запросу владельца стойка/посетитель стали реальными целями E вместо необходимости искать метку якоря. Наведение только показывает подсказку. Корпус/столешница/окантовка связываются с WorkstationTarget, посетитель выбирается головой/телом. Разговор рядом доступен без рабочего места и телепорта; обзор/блокировка тела в речи прежние. У занятой стойки курсор различает NPC/дерево, подсказка следует за ним, E разговаривает/открывает прежний список напитков. Барные маркеры скрыты; со стороны зала стойка объясняет подход к рабочему месту.

InteractionController обновляет луч при E, не перескакивает ближайшую стену, хранит слабую привязку поверхности; курсорные координаты сбрасываются при смене режима/размера. Контекст/близость повторно проверяются Main. Дом/сюжет/баланс/прогресс/настройки не расширялись.

Изменены: scripts/interaction/workstation_target.gd/.uid, interaction_controller.gd, interactable_3d.gd, dialogue_trigger.gd; scripts/main/main.gd, scripts/ui/navigation_hud.gd, scenes/characters/test_guest.tscn; tests/world_target_test.gd/.uid/.tscn, free_roam_test.gd, playthrough_test.gd, tools/check.ps1/check_windows_export.ps1. Документы: README, STATUS/HANDOFF/BACKLOG/ARCHITECTURE/CONTRACTS, WORLD_INTERACTION, FREE_ROAM/DIALOGUE_BUBBLES/PLAYTEST/TESTING/BUILD, task DA-058, ADR-0024, индексы. Новых визуальных ассетов нет.

## Проверки

Godot 4.7.2.stable.official.ed1daf0bf, Windows, Compatibility/RTX 5060.

| Команда / сценарий | Фактический результат |
| --- | --- |
| check.ps1 после первой интеграции | PASS прежних наборов, artifacts/da058-regression.log |
| world_target_test headless | PASS 25/0 до проверки корпуса стойки, artifacts/da058-targets.log |
| GPU 1280×720 с capture-dir | PASS 28/0 до проверки корпуса, artifacts/da058-targets-graphics.log |
| GPU --small, 960×600 с capture-dir | PASS 29/0, включая корпус и 3 PNG, artifacts/da058-targets-small.log |
| Визуальный просмотр | Гость/стойка из зала/курсор у стойки просмотрены в обоих размерах, подсказки читаемы, метки не видны |

Итоговые чистые исходники/Windows release-template ещё проверяются; результат будет записан после завершения.

## Решения и ограничения

[ADR-0024](../decisions/0024-world-interaction-targets.md), [WORLD_INTERACTION](../WORLD_INTERACTION.md), [CONTRACTS](../CONTRACTS.md). Радиус взаимодействия в текущем баре 3 м, вход на рабочее место остаётся локальным из прохода за стойкой. T/B пока альтернативные команды; изменения дома — отдельная задача. Код содержит legacy режим для прежних графовых проверок. Другая физическая машина и субъективное удобство не проверены, M3 целиком не закрыт. Сюжет/лица/новые записи остаются отложенными.

## Продолжение

Пользователю пройти WORLD_INTERACTION/PLAYTEST: подойти из зала к гостю, E поговорить, обойти стойку, E по дереву занять место, курсором выбрать посетителя/напиток, Esc выйти. Коллегам: чистый clone/check.ps1 и world_target_test; пользовательские checkpoint/preferences в тесте отключены. STATUS/BACKLOG/HANDOFF обновлены, до итоговых проверок in_progress. Публикация релиза/слияние этой задачей не поручены.
