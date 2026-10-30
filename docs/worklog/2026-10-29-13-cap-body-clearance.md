# 2026-10-29: DA-094 — крышка и падение

Codex; codex/da094-cap-body-collision; база 97a3eca.

## Выполнено

Крышка плавно выходит за поперечный край корпуса бутылки, в том числе после остановки; надевание/захват исключены. Свободное падение быстрее примерно на 16%; опрокидывание немного быстрее, устойчивость прежняя. Файлы: bottle_cap_item, drink_workbench, tabletop_motion, tabletop_test и документы. Общие игровые сцены не менялись.

## Проверки

Tabletop headless 44/0 до дополнительного теста скорости; GPU 47/0 с ним. Регрессия скриншота проверяет отсутствие скачка и конечного пересечения/движения при углах 0/+90/−90. Финальный полный tools/check.ps1 PASS (tabletop 45/0 headless, full playthrough 50/0). Windows Validation GPU: tabletop 47/0, small bottle 34/0, workbench 144/0, всего 225/0. Просмотрен da094-cap-beside-bottle-0.png. Production из чистого a6144ad, builds/windows-20261029-224504-6ec42b91. Прежняя установка обновлена, SHA256 всех файлов и графический startup PASS. Логи artifacts/da094-check.log, da094-export-*.log, da094-installed-startup.log.

## Решения и ограничения

[ADR-0053](../decisions/0053-cap-body-clearance.md). Приближённое разрешение пересечений крышки/бутылок, не полная физика всех предметов. Сохранения прежние.

## Продолжение

Ручной проход владельцем с прежнего ярлыка и затем следующая модель. Merge/push не выполнялись. STATUS/BACKLOG/HANDOFF обновлены, задача done.
