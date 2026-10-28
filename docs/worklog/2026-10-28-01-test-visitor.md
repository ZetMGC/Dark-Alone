# 2026-10-28: CHAR-01 — пробный текстурированный посетитель

Исполнитель: второй участник + Codex. Ветка codex/test-visitor-model, база b64f51a. Поручение: один посетитель после изображений Mouthwashing.

## Результат

visitor_model.tscn/visitor_model.gd: объёмная голова, волосы, куртка, руки с пальцами, обувь; 15 костей, жёсткие BoneAttachment3D, дыхание/голова/жест. GuestArt добавляет D, сохраняет A/B/C и игровые системы; общие .tscn не редактировались. Лицо — встроенный imagegen, полный prompt рядом с PNG, import 256; ткань собственная кодовая. Новые программы/зависимости не устанавливались.

## Проверки

Godot 4.7.2 stable, Windows, OpenGL Compatibility, RTX 4070.

| Команда | Фактический результат |
| --- | --- |
| tools/check.ps1 -Godot <4.7.2-console> | PASS весь прежний набор, включая faces 22, house 99, ink 113, drink core 837, workbench 119, integration 21, playthrough 50 |
| --headless --path . res://tests/visitor_model_test.tscn | PASS 77, 0 failures |
| --path . res://tests/visitor_model_test.tscn | GPU PASS 78, 0 failures; настоящий снимок bar.png |
| --path . --script res://tools/capture_visitor.gd | GPU 0/65/150/лицо; GLB export и обратная загрузка OK, 47 мешей |

Новая строка visitor_model_test добавлена в check.ps1 после полного прогона прежнего набора; новый сценарий отдельно выполнен после последней правки. Исправлены типы GDScript, reset поз скелета, winding поверхностей и неверный индекс кости в тесте. Первый sandbox-запуск редактора не мог писать user-каталог, успешные проверки выполнялись с доступом к нему. Локальные project.godot/Caveat.ttf.import сохранены отдельно.

## Решения и продолжение

ADR-0027, CHARACTER_PROTOTYPE.md. Первый макет: боковые UV/швы кожи, жёсткие суставы и ткань требуют доводки; нет липсинка/моргания/ходьбы/IK. GLB — снимок геометрии/материалов/позы, движения GDScript не запекаются. Исходник — native-код/сцена/текстура. Не закрывает DA-035, не задаёт канон.

Следующий шаг — оценка лица/силуэта участником у стойки, затем боковые текстуры/мягкий скиннинг. Не переносить внешность на остальных NPC до оценки. STATUS/BACKLOG обновлены; нового релиза/слияния нет.

Изменены: scripts/characters/visitor_model.gd (+uid), scenes/characters/visitor_model.tscn, assets/characters/test_visitor/{face.png,face.png.import,PROMPT.md}, scripts/presentation/guest_art.gd, tests/visitor_model_test.{gd,gd.uid,tscn}, tools/capture_visitor.{gd,gd.uid}, tools/check.ps1; docs/{CHARACTER_PROTOTYPE,CHARACTER_DIRECTION,ASSETS,ARCHITECTURE,CONTRACTS,STATUS,HANDOFF,BACKLOG,TESTING}.md, docs/decisions/{0027-test-visitor-model,README}.md и docs/worklog/{2026-10-28-01-test-visitor,README}.md.
