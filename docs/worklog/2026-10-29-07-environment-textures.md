# 2026-10-29: TEX-01 — первые текстуры окружения

Исполнитель: второй участник + Codex. Ветка: codex/environment-textures. База: 104c644.

## Выполнено

Созданы три albedo: орех, штукатурка, обивка. Применены к соответствующим материалам существующих бара и дома. Подобраны цветовой баланс и метрический масштаб; включены mipmaps и отражённое повторение. [Манифест, точные prompts, ограничения и снимки](../ENVIRONMENT_TEXTURES.md). Планировка, мебель, свет и gameplay не изменены.

Файлы: assets/textures/environment/*; assets/shaders/environment_texture.gdshaderinc (+uid), house_surface.gdshader, worn_surface.gdshader; scripts/presentation/environment_textures.gd (+uid); scripts/home/house_dressing.gd; scripts/levels/reference_bar.gd. Документация: ENVIRONMENT_TEXTURES, ASSETS, TEXTURE_DIRECTION, STATUS, HANDOFF, BACKLOG, ADR-0051, этот протокол и два снимка docs/art/textures-v1-*.png.

## Проверки

Godot 4.7.2, Windows, Compatibility/OpenGL, RTX 4070. Команды ниже запускаются из корня проекта; Godot — путь к console executable.

| Команда / сценарий | Фактический результат |
| --- | --- |
| tools/check.ps1 -Godot <Godot> | PASS: весь набор импорта, smoke, navigation, content, dialogue, service, shift, playthrough, startup |
| <Godot> --path . --audio-driver Dummy res://tests/reference_bar_test.tscn | PASS: 27 проверок, 0 ошибок |
| <Godot> --path . --audio-driver Dummy res://tests/house_visual_test.tscn -- --capture-dir=artifacts/textures/house | PASS: 272 исходных элемента, 0 различий |
| Та же сцена с --no-retro и отдельным capture-dir | PASS: 272 исходных элемента, 0 различий |
| Загрузка трёх Texture2D через временный SceneTree probe | Все 512×512, has_mipmaps=true |

Логи в локальных .tools/textures-*.log; временные логи/probe и artifacts не предназначены для Git. Просмотрены игровые кадры дома и бара; интерактивный обход владельцем для окончательной художественной оценки остаётся следующим шагом. Статичные кадры не доказывают отсутствие любой ряби в движении.

## Решения и ограничения

[ADR-0051](../decisions/0051-environment-textures.md). Три материала — первый комплект, остальные поверхности не объявляются готовыми новыми текстурами. Исходные карты сохранены; импорт уменьшает их до 512px. Отдельных normal/AO/roughness PNG нет. Ранее локально изменённые project.godot и content/drinks/test_materials.json не относятся к TEX-01 и сохранены отдельно. Публикация, main и установленный EXE в это поручение не входят.

## Продолжение

Перезапустить F5 из исходников, осмотреть стойку/стулья/пол бара, затем дом после смены. Согласовать контраст древесины и плотность ткани в движении; следующий комплект — окрашенный металл, плитка и керамика по TEXTURE_DIRECTION. STATUS/BACKLOG/HANDOFF обновлены.
