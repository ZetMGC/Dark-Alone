# 2026-10-28: DA-072/073/074 — речь, шейкер, настройки

Исполнитель: агент UX. Ветка: codex/da068-closed-journal-reasoning-chains, база c25999c. Прямые поручения: плавное перемещение речи позади/понятный шейкер; затем исправить настройки основного запуска и разгрузить Esc. Задачи зарезервированы в BACKLOG; общие navigation_hud/reasoning_demo сцены свободны перед правкой и освобождены сейчас. Барная/домашняя .tscn не менялись.

## Выполнено

DA-072: отображаемая позиция речи приближается к вычисленному target с tau 0.16s, без overshoot/сброса текста. Задний центральный сектор удерживает выбранную сторону до достаточного отклонения, мелкие повороты не вызывают скачки. Работа/пауза/дневник/фокус и can_answer остаются прежними; направление голоса рассчитывается и поверх верстака, хотя его UI-позиция там фиксирована справа.

DA-073: шейкер выглядит как сужающийся металлический корпус с шлифовкой, открытой горловиной, большой крышкой и колпачком. Кнопки Шейкер/Колпачок дают open/sealed/straining. Наполнение/лёд/ложка только open, shake только sealed, непрерывный отток через стрейнер только straining. Налив на крышку тратит бутылку в пролив, не наполняя сосуд; лёд не проходит крышку. Стакан при drop больше не мгновенно телепортирует всю жидкость — нужно держать выше и наклонять колесом. Используется прежний transfer/состав/остатки/лёд/аэрация; крышка — UI/runtime, save не меняется. Металл процедурный, новых зависимостей/текстур извне нет.

DA-074: основная reasoning_demo имела preferences_enabled=false от изолированной TEST-сцены DA-068. После переключения её на default в DA-069 это отключило пользовательские настройки в ярлыке. Исправлено на true, прежний файл/Store не сброшены. Checkpoint тестового разговора остаётся выключен независимо. Esc — только продолжить/настройки/выход, настройки отдельной страницей, Back/Esc возвращает к паузе, второй Esc продолжает. Пути % контролов прежние, новые HUD.show_settings(bool)/close_settings()->bool потребляет Main. Тесты по-прежнему изолируют Store и не пишут реальные настройки игрока.

## Проверки

Godot 4.7.2 stable, Windows; GPU Compatibility / RTX 5060. <Godot> — путь установленного движка.

| Команда / сценарий | Окружение | Фактический результат |
| --- | --- | --- |
| `tools/check.ps1 -Godot <Godot>` | source/headless | PASS: полный набор, пузырьки 128, preferences 37, workbench 139, playthrough 50, startup |
| `tools/check_workbench.ps1 -Godot <Godot> -Graphics` | import/headless/GPU 1280×720/960×600 | PASS: 139/151/151, три новых снимка open/sealed/straining |
| `godot --headless --path . res://tests/dialogue_bubble_test.tscn` | headless | PASS: 128 checks |
| Та же сцена без headless с --capture-dir и затем --small | GPU оба размера | PASS: 137/137, задний сектор/плавное приближение |
| `godot --headless --path . res://tests/bar_service_dialogue_test.tscn` | headless после финальной правки направления поверх верстака | PASS: 52 checks |
| `godot --path . res://tests/preference_test.tscn -- --capture-dir=res://artifacts/da074-graphics` | GPU | PASS: 42 checks, pause-short/settings-page просмотрены |
| preference_test --preference-probe=write/read --default-entry --preference-directory=user://preference_tests/process_<id> | два отдельных headless процесса, actual default entry | PASS: write 2 / read 3, звук/камера/книга/детализация восстановлены |
| `git diff --check` | исходники/документы | PASS |

Профили шейкера проверяют поток из стакана, запрет drop-transfer, невозможность shake открытого, крышку во время удержания, расход на закрытую крышку/запрет льда, sealed без оттока, снятие cap и сохранение состава/техники при процеживании. Пузырьки: фактическая смена взгляда не телепортирует позицию, последовательность малых поворотов сохраняет сторону/текст, движение приближается к target. Настройки: default preferences_enabled, отдельная страница, Esc назад/затем resume, изменение регулятора/файл/повторный запуск.

Свидетельства только локально/игнорируемые: artifacts/da072-074-common.log, da072-headless.log, da072-normal.log, da072-small.log, da072-service.log, da073-headless.log, da073-graphics.log, workbench-2248c827549e4df19bee38388c4c4554/, da074-headless.log, da074-graphics.log, da074-default-write.log/read.log. Визуально просмотрены металлический закрытый шейкер, короткая пауза и экран настроек. Первые тестовые наливы попадали по ложке вместо корпуса стакана; fixture берёт реальный край. Первое тестовое значение громкости 0.37 округлялось шагом 0.05; проверено допустимое 0.4. Запуск probe вне разрешённого process_ namespace был отклонён, повтор в допустимом изолированном пути PASS. Финальные профили без ошибок. Новый Windows export не выполнялся: ярлык запускает текущий проект, прежние показатели экспорта не выдаются за новые.

## Решения и ограничения

[ADR-0034](../decisions/0034-smooth-speech-position.md), [ADR-0035](../decisions/0035-shaker-lid-and-straining.md), [ADR-0036](../decisions/0036-pause-settings-and-persistence.md). [Речь](../DIALOGUE_BUBBLES.md), [шейкер/API](../parallel/bar/CONTRACTS.md), [настройки](../PLAYER_SETTINGS.md). Холод/разбавление и коэффициенты по-прежнему условная игровая модель, не полная гидродинамика. Нельзя менять крышку в руках, поставьте сосуд; UI объясняет последовательность. Параметры книги относятся к её анимации, speech smoothing имеет собственный короткий переход. Слияния/публикации/удаления веток нет, alpha.3 прежний.

## Продолжение

Перезапустить игру тем же ярлыком. Проверить сохранение своих настроек (Esc/настройки/перезапуск), поворот спиной во время речи, затем шейкер: залить открытый → закрыть → встряхнуть → поставить/снять колпачок → наклонить над стаканом. Оценить темп перемещения и понятность визуальных состояний. STATUS/BACKLOG/HANDOFF и задачи обновлены, все три done, общие сцены свободны. Частично реализованных пунктов в рамках поручения нет.

## Изменённые файлы

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/BACKLOG.md`
- `docs/CONTRACTS.md`
- `docs/DIALOGUE_BUBBLES.md`
- `docs/HANDOFF.md`
- `docs/PLAYER_SETTINGS.md`
- `docs/REASONING_DEMO.md`
- `docs/STATUS.md`
- `docs/TESTING.md`
- `docs/decisions/0034-smooth-speech-position.md`
- `docs/decisions/0035-shaker-lid-and-straining.md`
- `docs/decisions/0036-pause-settings-and-persistence.md`
- `docs/decisions/README.md`
- `docs/parallel/bar/CONTRACTS.md`
- `docs/parallel/bar/WORKBENCH.md`
- `docs/tasks/DA-072.md`
- `docs/tasks/DA-073.md`
- `docs/tasks/DA-074.md`
- `docs/worklog/2026-10-28-09-speech-shaker-settings.md`
- `scenes/main/reasoning_demo.tscn`
- `scenes/ui/navigation_hud.tscn`
- `scripts/main/main.gd`
- `scripts/ui/dialogue_bubble_panel.gd`
- `scripts/ui/navigation_hud.gd`
- `scripts/ui/preparation/drink_workbench.gd`
- `tests/dialogue_bubble_test.gd`
- `tests/parallel/bar/workbench_test.gd`
- `tests/preference_test.gd`
