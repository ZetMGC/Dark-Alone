# DA-062: передача

2026-10-27. Исполнители: второй участник и Codex. Ветка codex/da062-home-object-targets, база 9303616. Реализация done, main не объединялся. Итоговый SHA смотреть в `git log -1` этой ветки; данная запись входит в коммит результата.

## Выполнено

HomeExploration связывает физические поверхности мебели с локальным HomeSurfaceTarget через существующий register_surface. В ходьбе метки и старые сферы отключены. E требует свежего попадания/близости/отсутствия преграды; курсор на занятом месте осматривает тот же предмет. Старый граф/legacy fixtures сохранены. Ракурс двери в free-roam смотрит на дверь; тело и место подхода не перемещаются при входе. Menu/Journal/осмотр/fade/неактивная камера блокируют фоновые действия. Прежний прогресс и маршрут сохранены.

Изменённые файлы: scripts/home/home_exploration.gd; новые scripts/home/targets/home_surface_target.gd и .uid; tests/home_target_test.gd/.uid/.tscn; tools/check_home_targets.ps1; docs/HOME.md, docs/tasks/DA-062.md и docs/parallel/home/{STATUS,HANDOFF,WORKLOG,CONTRACTS,DECISIONS}.md. Геометрию сцены и общие модули не меняли. Отдельное старое форматирование project.godot не включать.

## Проверки

Godot 4.7.2 Standard, Windows, Compatibility, RTX 4070. Общий `tools/check.ps1 -Godot <движок>` PASS. Профильный `tools/check_home_targets.ps1 -Godot <движок> -Graphics`: 94/94 headless, старый home 43/43, GPU 106/106 в каждом из 1280×720/960×600. Подробные команды/логи/снимки — [WORKLOG](WORKLOG.md).

## Решения и ограничения

[CONTRACTS](CONTRACTS.md), [DECISIONS](DECISIONS.md). Новая планировка/бытовые предметы из чата ещё не утверждены для реализации. Сюжет/канон/награды/формат сохранений прежние. Windows-экспорт не запускался в этой ветке; выполнить при интеграции с баром. Человеку проверить удобство подхода/курсора. Никаких изменений DA-060 и общих реестров.

## Продолжение

Ревью и ручной HOME-проход; затем координатор интегрирует ветку, добавляет `res://tests/home_target_test.tscn` в общий check.ps1/Windows Validation и сводит контракты/статусы. Выполнить полный цикл бар → дом → новая смена и Windows-сборку после интеграции. Общие STATUS/BACKLOG не обновлены согласно PARALLEL_WORK; актуальный статус в карточке DA-062. Не удалять/не сливать чужую ветку.
