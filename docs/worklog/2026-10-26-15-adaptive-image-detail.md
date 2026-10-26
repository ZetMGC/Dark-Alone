# 2026-10-26: DA-042 — детализация под экран

Исполнитель: агент DA-042. Ветка codex/da042-adaptive-graphics, база 5a9ccf7. Рабочая копия до начала чистая. Владелец сообщил о малом числе пикселей/размытости и трудном чтении на большом экране alpha.1; поручил исправить и продолжать план.

## Выполнено

Найдена фиксированная virtual_height=360 в retro_screen.gdshader. Fullscreen уже рисовал native кадр, но эффект убирал дополнительные детали. Теперь default adaptive — блок 2 физических пикселя, native — 1, classic — прежние 360 строк; всё переключается в меню без изменения времени/знаний. Предпочтение хранится между сценами до закрытия процесса. Default font и отдельный SystemFont книги включены в MSDF, без добавления внешних шрифтов. Палитра/материалы/виньетка сохранены, UI остаётся выше эффекта.

Изменены `assets/shaders/retro_screen.gdshader`, `scripts/presentation/presentation_controller.gd`, `scenes/ui/navigation_hud.tscn`, `scenes/ui/book_theme.tres`, `project.godot`; `tests/presentation_test.gd`, `playthrough_test.gd`, новые `image_detail_test.gd`/uid/tscn; `tools/check_windows_export.ps1` (-Graphics). Документы: README, STATUS/BACKLOG/HANDOFF, ARCHITECTURE/CONTRACTS, ART_GUIDE/DISPLAY/PLAYTEST/TESTING/BUILD, IMAGE_DETAIL, карточка DA-042, ADR-0013 и индексы. HUD редактировал один агент, другие общие сцены не менялись.

## Проверки

Windows 11 Pro, Godot 4.7.2.stable.official.ed1daf0bf, Compatibility/RTX 5060, один физический экран 1920×1080.

| Команда / сценарий | Фактический результат |
| --- | --- |
| tools/check.ps1 -Godot godot | PASS: все наборы, presentation 20, book 51, display 46, полный цикл 50, startup |
| godot --path . res://tests/image_detail_test.tscn -- --capture-dir=<path> | PASS: 38 проверок, 20 PNG, реальный renderer |
| Сравнение 720p/1080p/1440p/4K/3440×1440 | Три режима мира и книга сняты, 4K classic/adaptive/кириллица просмотрены; дополнительные детали видны |
| GPU-полосы в 4K | PASS: classic=0, adaptive=575 границ; текст на непрозрачной подложке выше эффекта совпадает побайтово |
| Windows build / check_windows_export -Graphics | PASS: startup, цикл 50, book 51, display 46; графический image detail 18/0 |
| Полный check.ps1 на чистом Git tree без прежнего .godot/ | PASS: все наборы, presentation 20, book 51, display 46, цикл 50 |
| git diff --check / относительные Markdown-ссылки | PASS |

Первоначальная проверка изоляции UI дала FAIL из-за сравнения полупрозрачного HUD вместе с изменившимся фоном. Исправлена мишень: непрозрачная подложка с кириллицей выше эффекта; это ожидаемое смешивание фона, а не баг игрового UI. Повторный графический тест — 38/0. Headless не считается проверкой пикселей.

Снимки `artifacts/da042-compare/da042_*`, логи `artifacts/da042-*.log`. При просмотре 4K использовать исходный масштаб 100%, миниатюры инструмента сами уменьшают изображение.

## Решения и ограничения

[ADR-0013](../decisions/0013-adaptive-image-detail.md), [CONTRACTS](../CONTRACTS.md), [IMAGE_DETAIL](../IMAGE_DETAIL.md). Это выборка уже native кадра, не экономия стоимости 3D; минимальный GPU Q-07 не определён. 4K/ultrawide проверены размерами окна/рендера на одном физическом мониторе, нужен отзыв владельца на его экране. В classic мировые буквы намеренно остаются грубыми. Размер шрифта/модель чтения/канон не менялись; реалистичная подача записей DA-038 ожидает концепт. Alpha.1 и его вложения не подменялись, новый релиз не публиковался.

## Продолжение

Передать исправленный локальный билд владельцу, получить оценку на большом экране; слить ветку перед следующим релизом. Затем DA-035: нейтральные TEST-варианты узнаваемых лиц, без канонического состава до Q-04. STATUS/BACKLOG/HANDOFF обновлены; результаты финальных проверок/сборки дописываются ниже.
