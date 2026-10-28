# 2026-10-28: CHAR-02 — второй художественный проход посетителя

Исполнитель: второй участник + Codex. Ветка codex/test-visitor-model, база b8b138f. Пользователь отметил отличие от Mouthwashing и поручил довести посетителя.

## Выполнено

Перестроен visitor_model.gd: один skinned ArrayMesh, 3 материала, 15 костей/обратные rest-bind, смешанные веса локтей/коленей/талии. Убраны цилиндры/коробки одежды и лицевая маска. Цельный UV-череп с носом/губами/глазницами/ушами, тонкий воротник, изогнутые рукава, текстурные складки/швы/карманы и отдельная кодовая фактура обуви. Поза у стойки с неодинаковой высотой рук и небольшим переносом веса, плавный жест при DIALOGUE.

Оригинальные атласы головы/open/closed и одежды получены встроенным imagegen. Полные prompts и референс идентичности — assets/characters/test_visitor/PROMPT_V2.md. Import 512px, mipmaps/nearest. Моргание 0.13 с каждые 4.8 с: смена diffuse-текстуры, без накладок. Прежний face.png остаётся историческим референсом. Новых программ/зависимостей/сторонних моделей не добавлено.

Визуально проверены студия 0/65/150°, открытые/закрытые глаза и барный ракурс/zoom FOV35. Исправлены UV-шов на границе front/back одежды, выход UV за диапазон на темени, направление поверхностей рукавов/кистей/зеркальных ушей/воротника. Для нормалей обоих рукавов добавлена регрессия. Палитра/свет бара не менялись.

## Фактические проверки

Godot 4.7.2, Windows, OpenGL Compatibility, RTX 4070.

| Команда / сценарий | Результат |
| --- | --- |
| tools/check.ps1 (предварительно, до финальной правки winding) | PASS весь набор; visitor 46, integration 21, workbench 119, ink 113, house 99, playthrough 50 |
| --headless --path . res://tests/visitor_model_test.tscn (финальная геометрия) | PASS 48/0 |
| --path . res://tests/visitor_model_test.tscn | GPU PASS 50/0 |
| --path . --script res://tools/capture_visitor.gd | GPU кадры, включая blink; GLB export/обратная загрузка OK: 1 mesh/3 surfaces/1 skeleton, 15 bones |

2431 вершина, 398 со смешанными весами. Проверяются конечные/unit normals/UV, сумма весов с допуском 0.0001 под квантование Godot, направления наружных нормалей, скрытие/пауза/фактический blink, старые A/B/C и неизменность разговора/подачи/коллизий. Старое требование «>30 отдельных мешей» заменено проверкой реального Skin и геометрии, потому что модель объединена.

## Решения и передача

ADR-0028; текущие контракт/команды/ограничения — CHARACTER_PROTOTYPE.md. Видимая модель — художественная итерация, не автоматическое утверждение «идеально» и не закрытие DA-035. Нет липсинка/IK/ходьбы/взятия стакана; GLB не запекает процедурные движения и blink. Финальный образ других NPC/канон не менялись.

Следующий шаг: человеческая оценка в баре adaptive/native в движении. Source/текстуры/бинарные import-файлы отслеживаются; artifacts воспроизводимы. STATUS/BACKLOG обновлены. Нового релиза/слияния нет. Локальные project.godot и Caveat.ttf.import исключены.

Изменены: scripts/characters/visitor_model.gd; tests/visitor_model_test.gd; tools/capture_visitor.gd; assets/characters/test_visitor/{head_wrap_v2,head_blink_v2,clothing_atlas_v2}.png (+.import), PROMPT_V2.md; docs/CHARACTER_PROTOTYPE,CHARACTER_DIRECTION,ASSETS,ARCHITECTURE,CONTRACTS,STATUS,HANDOFF,BACKLOG,TESTING; ADR-0028/индекс решений; worklog/индекс и документальные PNG в docs/art.
