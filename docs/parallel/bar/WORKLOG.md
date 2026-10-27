# 2026-10-27: DA-060 — обслуживание при продолжающемся разговоре

Исполнитель: агент владельца DA-060. Ветка codex/da060-bar-service-dialogue. База 930361663a3739d20c7e54684487fb7b300701a6. На старте чистая main, ветки origin обновлены; общие сцены/файлы дома не редактировались. Разрешённая область — docs/tasks/DA-060.md. Общие STATUS/BACKLOG/индексы намеренно не изменены по исключению AGENTS/PARALLEL_WORK.

## Выполнено

Main разрешает E по задней поверхности в DIALOGUE, фиксирует ракурс/курсор и допускает существующее меню/подачу без закрытия Runner. Только первоначальный старт речи освобождает focus; возврат из сервиса/паузы сохраняет его. Пассивный пузырёк продолжает набор, но F/цифры/колесо/Backspace не выбирают ответы в рабочем ракурсе/сервисе. Escape закрывает выбор, затем отходит; при взгляде на NPC восстанавливает ответ/продолжение той же страницы. Menu/Journal/потеря фокуса ставят набор/тело на паузу.

Session opt-in concurrent_service_enabled включён Main только для free-roam. _service_return хранит прежний режим; can_open_service — запрос доступности без мутации. При активной речи сервис требует >=2 делений, повторяет проверку перед подачей: последнее деление сохраняет возможность закончить разговор, нет скрытой отмены/отрицательных часов. Обычные цены/отмена/legacy/HOME/checkpoint прежние. SERVICE компактно показывает обе кнопки без описаний/разделителей, описание доступно в tooltip, пузырёк выше. Рецепты/физика жидкости/руки/канон не добавлены.

Изменены scripts/main/main.gd, scripts/session/narrative_session.gd, scripts/ui/{dialogue_bubble_panel,service_panel,navigation_hud}.gd. Добавлены tests/bar_service_dialogue_test.gd/.uid/.tscn, tests/parallel/bar/long_service_guest.json, tools/check_bar_service.ps1. Документы: tasks/DA-060; docs/parallel/bar/{STATUS,HANDOFF,WORKLOG,CONTRACTS,DECISIONS}; WORLD_INTERACTION/DIALOGUE_BUBBLES/FREE_ROAM/GUEST_SERVICE/SHIFT_FLOW. FreeRoamCamera, Home, общие runner/сохранения/настройки не изменены.

## Проверки

Godot 4.7.2.stable.official.ed1daf0bf, Windows, Compatibility/RTX 5060.

| Команда / сценарий | Фактический результат |
| --- | --- |
| world_target, dialogue_bubble, free_roam headless | PASS 28/109/67, artifacts/da060-{world_target,dialogue_bubble,free_roam}.log |
| Новый bar_service_dialogue_test headless, первая версия | PASS 51/0, artifacts/da060-bar-service.log |
| tools/check.ps1 -Godot <Godot> | PASS всех прежних наборов, включая HOME 43, пеший цикл 67, речь 109, наведение 28, checkpoint 51 и новые процессы; artifacts/da060-regression.log. До последнего компактного оформления кнопок |
| tools/check_bar_service.ps1 -Godot <Godot> -Graphics, итоговый вариант | PASS 52 headless/56 GPU 1280×720/56 GPU 960×600; artifacts/da060-final-profile.log, детали artifacts/da060-c96acb08e0cc4820a5d00adb421e8419 |
| Визуальный просмотр | PNG выбора рядом с речью просмотрены в обоих размерах; обе кнопки видны без прокрутки, карточка не накрывает пузырёк |

Новый профиль проверяет частично набранное продолжение 2/8, сохранность страницы/выбора, настоящий E/курсор/B/Escape/J/F, фиксированный ракурс, меню/журнал/фокус, пассивные клавиши/колесо, UI-подачу, ошибочные/повторные команды, оба порядка действий, остаток 1 и изменение времени уже после открытия выбора. Сохранения/настройки игрока отключены.

Итоговый игровой коммит cc79a997fd4827d7bbdfd241e0d30dc5c662adc1.

- Чистый Git archive без .godot: полный tools/check.ps1 PASS, artifacts/da060-clean-source.log. Отдельно новый bar_service_dialogue_test.tscn PASS 52/0, artifacts/da060-clean-profile.log. Проверен окончательный компактный интерфейс и все ресурсы/TEST JSON из коммита.
- git diff --check PASS. Python проверил все 21 изменённый файл против разрешённых путей DA-060 и относительные ссылки изменённых документов; вне области изменений нет. git diff по scripts/home/scenes/home/tests/home_test.gd/docs/HOME.md/FreeRoamCamera пустой.
- После проверок меняется только итоговая документация. Задача done, готова к ревью; общий BACKLOG/STATUS обновит координатор.

## Решения и ограничения

CONTRACTS.md и DECISIONS.md этой папки — дополнения для последующей общей интеграции. Проверено поведение исходников на локальной Windows/GPU; новый экспорт/release-template не выполнялся в дорожке, это задача координатора после ревью. Экспортные runner/общий check не менялись; новый тест пока запускается отдельным wrapper. Не считать M3 завершённым. Описание реальных напитков/рецептов ждёт владельца. Требуется человеческая оценка удобства фокуса и ограничения последнего деления.

## Продолжение

Карточка/STATUS/HANDOFF обновлены, результат передаётся только своей веткой. Координатору после ревью подключить новый тест в общий check.ps1 и Windows Validation, свести локальные контракты/решение/результаты в общие документы, затем проверить Windows-сборку. DA-062 не нужна для нашей приёмки; её файлы не менять. Живые статусы и отчёт обновлены в своей области по AGENTS, центральные файлы сохранены для независимой работы коллеги.

## Дополнение: план напитков после DA-060

Прямой запрос владельца 2026-10-27 расширяет барную механику: шоты/коктейли, смешивание/плотность/слои, рецепты, разные реакции/разговорчивость/добавки; дом продолжает коллега. В отдельной ветке codex/drink-system-plan от 1d2fbd0 добавлен DRINKS_PLAN и ссылки в собственных STATUS/HANDOFF. Документ отделяет требования от предложений и отложенных чисел/канона. Игровые файлы не меняются; запуск движка для документации не требуется. Проверки — git diff --check и относительные ссылки. Следующий конкретный шаг — независимая модель состава/объёмов/операций на TEST-данных; полноценная жидкость и эффекты не объявлены готовыми.

## 2026-10-27: DRINK-CORE-01 — модель напитков и TEST-стакан

Исполнитель: агент владельца. Ветка codex/drink-core, база bf7510f. Прямое «да, делаем» владельца запускает первый этап DRINKS_PLAN. Домен дома оставлен коллеге; глобальные реестры/runner не редактируются по прежнему разделению. На старте чистая копия, origin обновлён; новая вершина коллеги только прочитана Git, не включалась в эту реализацию.

Выполнено: новые scripts/service/drinks/drink_material_catalog.gd и drink_preparation.gd с .uid; строгий атомарный каталог, фактические объёмы/слои, условные плотность/темп/вязкость, смешивание/эмульсия/отстаивание, слив/печать результата и защита повторных команд. Самостоятельные tests/parallel/bar/drink_materials.json, drink_core_test.gd/.uid, drink_lab.gd/.uid/.tscn, drink_lab_test.gd/.uid; tools/check_drink_core.ps1. Документы в своей папке: DRINK_CORE_01/DRINK_CORE/DRINKS_PLAN, STATUS/HANDOFF/CONTRACTS/DECISIONS/WORKLOG. Основной игровой путь/сохраняемые схемы/чужие файлы не меняются. Рецепты, реакции и 3D-приготовление ещё следующие этапы.

Проверки Godot 4.7.2.stable.official.ed1daf0bf, Windows/Compatibility/RTX 5060:

- Ядро: 787 проверок, 0 отказов; каталог/некорректные данные/копии, ошибочные/повторные команды, стабильные/разрушенные слои, вязкость/плотность/темп, фазы/эмульсия, слив/печать, точность дозировки, лимит истории. Детерминированная серия из 70 наливов с перемешиванием проверяет сохранение каждого компонента/объёмов на каждом шаге. artifacts/drink-core-test.log.
- Итоговый tools/check_drink_core.ps1 -Graphics PASS: 787 ядро, 5 лаборатория headless, по 7 GPU в 1280×720 и 960×600. artifacts/drink-core-final-profile.log и artifacts/drink-core-370c9587e4c445f1a4f5befb0ba58e78. Снимки 01-layered/02-mixed просмотрены в обоих размерах: все кнопки/статус помещаются, слои/результат смешивания читаемы. Первоначальная вертикальная раскладка подписей исправлена до итогового прогона; типы и форматирование чисел также исправлены, итог без ошибок движка. Wrapper отклоняет логи с SCRIPT ERROR/ERROR даже при наличии PASS.
- Полный прежний tools/check.ps1 PASS, artifacts/drink-core-regression.log. Включая домашний маршрут, полный цикл и проверки сохранений/настроек.

Решение/контракт: локальные DECISIONS/DRINK_CORE в этой папке. Состояние только runtime, файл данных содержит определения TEST, а не сохранённый стакан. Новый API не используется домом/старым GuestService. Код 76ff6c6ab4b3e2e2575ff6c883c96b18efca3630: чистый Git archive без .godot прошёл tools/check_drink_core.ps1 (787 ядро/5 стенд) и весь tools/check.ps1. artifacts/drink-core-clean-profile.log и artifacts/drink-core-clean-regression.log. git diff --check и относительные ссылки PASS; 21 изменённый файл проверен против области docs/parallel/bar, scripts/service/drinks, tests/parallel/bar/drink_* и собственного wrapper. После проверки меняется только итоговая документация. Карточка и собственный STATUS/HANDOFF обновлены: done, готово к ревью. Общие реестры намеренно не менялись. Изменения вне своей области не требуются. Следующий шаг после завершения — каталог рецептов и проверка допусков, затем рабочая стойка.

## 2026-10-27: предложения визуального режима

Ветка codex/drink-mode-design от 52cb53b. По запросу владельца подготовлены PREPARATION_DESIGN и три интерактивных эскиза для сравнения, без изменения игровых сцен/ядра/дома. Рекомендация — 3D-выбор с 2D-крупным планом налива и наклоном; альтернативы свободный верстак/простое удержание. Зафиксированы общий вид задней рабочей зоны, читаемость, струя/поверхность, сохранность разговора/стакана и предлагаемый порядок реализации. Макет проверен в браузере: три композиции, изменение уровня при наливе, узкая ширина, отсутствие ошибок скрипта; это эскиз, не проверка игровой физики. Реальные Godot-файлы не изменены, запуск прежних игровых тестов для этой документации не требуется. Следующий шаг — выбор варианта владельцем, затем проход самой стойки.
# WORKBENCH-01 — 2026-10-27, свободное приготовление

Владелец выбрал второй вариант и подтвердил реализацию. Ветка codex/drink-workbench от 457b3b7. Общая сцена бара редактировалась только этим агентом; область дома/журнала/камеры и общие реестры/runner не менялись.

Сделано: оформлена задняя стойка (коврик, бутылки, посуда, инструменты, слив, свет), подняты полки. Новый DrinkWorkbench с перетаскиванием, колесом/ПКМ, баллистической струёй, реальными дозами/слоями, проливом/переполнением, ложкой, шейкером, сливом и подносом. ServicePanel/Main включают его по умолчанию в free-roam; пузырёк продолжается справа сверху. Пауза/resize/focus прекращают удержание без случайной подачи, черновик живёт в сцене. GuestService принимает DrinkPreparation, запечатывает и отдаёт глубокую копию результата, прежний одноразовый service-event списывает время. Исправлено продление верхнего слоя при непрерывных коротких дозах того же ингредиента.

Файлы: content/drinks/test_materials.json; scripts/ui/preparation/drink_workbench.gd (+uid), scripts/service/drinks/back_counter_art.gd (+uid), drink_preparation.gd; Main/GuestService/NarrativeSession/ServicePanel/DialogueBubblePanel; scenes/levels/back_counter.tscn и bar_graybox.tscn; tests/parallel/bar/workbench_test.gd (+uid/tscn), drink_core_test.gd, tests/bar_service_dialogue_test.gd (legacy opt-out), world_target_test.gd (новая высота полки); tools/check_workbench.ps1; свои PREPARATION_DESIGN/WORKBENCH_01/WORKBENCH/STATUS/HANDOFF/WORKLOG/CONTRACTS/DECISIONS.

Проверки Godot 4.7.2:

- tools/check_workbench.ps1 -Graphics: PASS, 50 headless, по 53 GPU 1280×720 и 960×600, artifacts/workbench-ce5aa729d4de406f87c309207a1c2c30. Осмотрены PNG стойки, трёх слоёв и смешанного напитка в малом окне. Мышью проверены бутылки/колесо, ложка, шейкер, сосуд/поднос. Терминальная реплика завершается через реальное F с учётом разного числа страниц.
- tools/check_drink_core.ps1: PASS, ядро 811/0 и лаборатория 5/0, artifacts/workbench-final-core.log.
- tools/check_bar_service.ps1: PASS, прежний профиль 52/0, artifacts/workbench-final-legacy.log.
- tools/check.ps1: полный PASS, artifacts/workbench-final-regression.log.

Итоговая проверка игрового коммита 05c1f83eedfd66e3b30abbc6956e55bd0f820601:

- Чистый Git archive, без исходного .godot: tools/check.ps1, check_workbench.ps1 (50/0), check_drink_core.ps1 (811/0 и lab 5/0), check_bar_service.ps1 (52/0) PASS. Логи artifacts/workbench-clean-{regression,profile,core,legacy}.log, исходники artifacts/workbench-clean-05c1f83.
- tools/build_windows.ps1: Desktop PASS, builds/windows-20261027-173029-6031d256.zip, manifest source_revision=05c1f83, source_dirty=false. ZIP распакован в artifacts/workbench-windows-unpacked-05c1f83; все SHA256 сверены с manifest, обычный EXE запущен --headless --quit-after 5 без ошибок.
- Первый запуск Validation с переопределением сцены отклонён штатным шаблоном (path overrides disabled). Для проверки приготовлена отдельная временная копия Git archive artifacts/workbench-export-source-05c1f83: единственное изменение — run/main_scene.integration_test указывает на tests/parallel/bar/workbench_test.tscn. Импорт и export-release Windows Validation PASS; профиль EXE без переопределения: 50 headless, 53 GPU 1280×720, 53 GPU 960×600, все 0 failures. Логи/PNG artifacts/workbench-validation-05c1f83; слои в малом экспортированном окне просмотрены. Рабочий project.godot/общие runner не менялись.
- git diff --check и проверка 28 путей относительно 457b3b7: область бара, домашние файлы/журнал/checkpoint/preferences/общие реестры не затронуты. Сгенерированные .uid сохранены. Финальный коммит после игрового — только документация.

WORKBENCH-01 done, готово к ревью. Известные ограничения и следующий конкретный шаг — WORKBENCH.md. Стакан только в памяти текущей смены, шейкер целиком, бесконечные TEST-бутылки, без рецептов/реакций. Общие STATUS/BACKLOG/ADR/TESTING намеренно не менялись по AGENTS/PARALLEL_WORK; сводит координатор. Локальную Windows-сборку не публиковали как релиз; main/чужие ветки не менялись.

# 2026-10-27: WORKBENCH-02 — доработка по игровому отзыву

Исполнитель: агент владельца. Ветка codex/workbench-physics, база 49ab5d5. Карточка WORKBENCH_02.md, статус in_progress до чистой проверки.

Выполнено: затухающая угловая пружина удерживаемой бутылки получает импульс ускорения курсора; реальный угол/скорость руки влияют на струю, жидкость в стекле колеблется. Промах падает на локальную глубину стола и образует цветные расплывающиеся лужи. Подбор стакана раньше зон чистой посуды устраняет недоступность слева, порядок рисования соответствует выбору. Слои в UI требуют ложку/мягкую струю/плотность. Отдельная DrinkBottleStock хранит конечные TEST-запасы 500 мл, расходует всё вышедшее независимо от попадания, не пополняется сменой стакана/закрытием; уровень виден на бутылке. При паузе движение/налив останавливаются. Полной 3D-физики/склада/checkpoint для остатков нет; первая модель шейкера прежняя.

Файлы: scripts/ui/preparation/drink_workbench.gd; scripts/service/drinks/drink_bottle_stock.gd (+uid); tests/parallel/bar/workbench_test.gd; docs/parallel/bar/WORKBENCH_02, WORKBENCH, STATUS, HANDOFF, CONTRACTS, DECISIONS, WORKLOG. Новых зависимостей/сцен и изменений дома нет.

Проверки Godot 4.7.2, Windows:

- tools/check_workbench.ps1 -Graphics: PASS, 78 headless/82 GPU 1280×720/82 GPU 960×600; artifacts/workbench-6d220f41b48040b788006ffd2f1b6fb8. Проверены подбор стакана из обоих левых слотов, прямое смешивание/слои по ложке, импульс/затухание/пауза, разные глубины пролива/растекание/копия, сохранение объёма при попадании/переполнении/промахе, исчерпание запасов, возобновление и полный цикл подачи/разговора. Просмотрены PNG 04-spill-on-surface и малый 02-layered-workbench.
- tools/check.ps1: полный PASS, artifacts/workbench-physics-regression.log.
- git diff --check: PASS. Чистая копия и Windows ещё проверяются, не объявлять промежуточный коммит окончательной приёмкой.

Следующий шаг: после чистой проверки закончить передачу, затем проектировать рецепты/допуски и визуальные подсказки. Общие STATUS/BACKLOG/ADR не менялись согласно исключению AGENTS/PARALLEL_WORK.
