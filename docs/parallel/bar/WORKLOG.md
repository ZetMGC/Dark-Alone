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

## WORKBENCH-02: итоговая проверка и передача

Код 5c41a2b8bf260a1639699dacf231487b86010248, done. Чистый git archive распакован без .godot в artifacts/workbench-physics-clean-5c41a2b. В нём tools/check.ps1 и tools/check_workbench.ps1 прошли (78/0); логи artifacts/workbench-physics-clean-regression.log и workbench-physics-clean-profile.log.

Desktop tools/build_windows.ps1: builds/windows-20261027-175232-28b58ab1.zip, source_revision=5c41a2b, source_dirty=false. Распаковка artifacts/workbench-physics-unpacked-5c41a2b: все SHA256 сверены с manifest; обычный EXE --headless --quit-after 5 завершился без ошибок.

После чистых проверок только в временной копии изменён run/main_scene.integration_test на res://tests/parallel/bar/workbench_test.tscn и выполнен export-release Windows Validation. Причина — штатный release-template запрещает path overrides, общий project.godot/runner не менялись. EXE запущен с --headless, затем с -- --capture-dir=<папка> в обычном окне, затем с --small: PASS 78/82/82, все 0 failures. Логи и PNG artifacts/workbench-physics-validation-5c41a2b. Изображение пролива/уровня из малой экспортированной версии просмотрено.

git diff --check PASS. Все 11 изменённых путей внутри барной области; центральные документы/runner, Main/сцены, камера, дом, журнал, checkpoint/preferences не менялись. Новый .uid включён. Финальный коммит — только карточка/статусы/передача/результаты. Ветка отправляется для ревью, main и релизы не меняются.

Известные ограничения: физика 2.5D с пружиной/плоскостью, не rigid-body/гидродинамика; TEST-запас возобновляется с новой сменой и не хранится на диске; шейкер по-прежнему переносит всю порцию. Рецепты/допуски/реакции/склад и пополнение ещё впереди. Следующий конкретный шаг — TEST-рецепты поверх запечатанного состава и истории приготовления; WORKBENCH.md объясняет управление/границы, CONTRACTS/DECISIONS фиксируют изменение правил.

# 2026-10-27: WORKBENCH-03 — предметы, пятна и выдача

Исполнитель: агент владельца, ветка codex/workbench-interactions от 0f6d6f6. Карточка WORKBENCH_03, in_progress до чистой/Windows проверки.

Выполнено: инерция всех предметов с разной отзывчивостью, ложка наследует движение стакана; лёгкие безопасные импульсы стоящих бутылок от горизонтальных/вертикальных касаний. При отпускании бутылки не перекрывают друг друга. DrinkSpillSurface хранит реальные компоненты/объём/цвет, объединяет пятна при попадании и последующем растекании. Явные кнопки чистой посуды показывают текущий тип, отказ из-за наполненной порции объясняется. Большая подсвеченная зона выдачи готовит стакан без списания; кнопка отправляет модель в прежний GuestService. При отказе стадия/состав сохраняются. Успех выводит реальный шот/стакан/цвет/слои на столешнице перед гостем и сообщение о месте результата.

Файлы: scripts/ui/preparation/drink_workbench.gd, новый scripts/service/drinks/drink_spill_surface.gd (+uid), scripts/main/main.gd, scripts/characters/service_guest.gd; tests/parallel/bar/workbench_test.gd; свои WORKBENCH_03/WORKBENCH/STATUS/HANDOFF/CONTRACTS/DECISIONS/WORKLOG. Сцены, дом/журнал/сохранения/настройки и общие runner не менялись.

Проверки Godot 4.7.2 Windows:

- tools/check_workbench.ps1 -Graphics: PASS 103 headless/109 GPU 1280×720/109 GPU 960×600, artifacts/workbench-105ef420a0e94e6bbbdac9477e2832af. Новые проверки: инерция/затухание каждого предмета, безопасные касания в обоих направлениях, кнопки посуды и сохранность полной порции, компоненты/цвет/контакт растущих пятен, постановка в выдачу без события, отказ/возврат без печати, успешная native-кнопка/точное одноразовое списание, реальный сосуд с дном на столешнице. PNG готовой выдачи и напитка у гостя просмотрены (предыдущий визуально равнозначный профиль ac98ac945c7347c985055d0f734e0547; последний дополняет касание по вертикали/наследование ложки).
- tools/check.ps1: PASS, artifacts/workbench-interactions-regression.log. Последние адреса подачи/вертикальный импульс ещё раз проверяются общим набором из чистого коммита.
- При проверке места подачи первоначально не учтён yaw 180 гостя; окончательно Main передаёт мировую точку поверхности CounterTop, проверка дна сосуда PASS. Исходная старая точка не была вне стойки; вывод в промежуточном комментарии исправлен. Старая подача show_served сохранена.
- git diff --check PASS. Новых зависимостей и runtime-файлов игрока нет. Профиль использует отключённые checkpoint/preferences.

Известные ограничения: физика 2.5D, визуальные касания без звука/разрушения; для смены заполненного сосуда сначала слив, независимых двух порций пока нет; пятна смешивают цвет и несовместимых компонентов без отдельных фаз; уборка/склад/рецепты/реакции следующие этапы. Следующий конкретный шаг — рецепты/допуски по реальному составу, сохраняя свободное приготовление. Новые API и решение записаны в собственных CONTRACTS/DECISIONS, общие реестры сведёт координатор.

## WORKBENCH-03: итоговая проверка и передача

Код c2b0f4eaa8e1c8ce2bac52ac677534734199c95e. Статус done. Из чистого Git archive artifacts/workbench-interactions-clean-c2b0f4e без исходного .godot: tools/check.ps1 и tools/check_workbench.ps1 PASS (103/0). Логи artifacts/workbench-interactions-clean-regression.log и workbench-interactions-clean-profile.log. Весь текущий код, включая привязку точки подачи/наследование ложки/вертикальное касание, проверен этим набором.

Windows Desktop: tools/build_windows.ps1 PASS, builds/windows-20261027-181941-170f84a5.zip, source_revision=c2b0f4e, source_dirty=false. Распакован в artifacts/workbench-interactions-unpacked-c2b0f4e, все SHA256 по manifest совпадают; обычный EXE --headless --quit-after 5 без ошибок.

После чистой проверки только во временной копии integration_test main_scene заменена на res://tests/parallel/bar/workbench_test.tscn, export-release Windows Validation PASS. Это прежний способ изолированной проверки без изменения общих runner/project.godot, так как штатный release-template не поддерживает path overrides. EXE: headless 103/0, GPU 1280×720 109/0, GPU 960×600 109/0, логи/PNG artifacts/workbench-interactions-validation-c2b0f4e. Готовая выдача в малом экспортированном окне просмотрена. Рабочая проектная конфигурация и старый Windows Validation runner не менялись.

Все 13 путей относительно 0f6d6f6 внутри новой карточки. Сцены, домашняя дорожка, журнал, checkpoint/preferences, центральные реестры/runner не менялись; новый .uid сохранён. git diff --check PASS. Последующий коммит — только итоговые документы, игровой SHA остаётся источником сборки/чистой проверки. Ветка передаётся в GitHub, main/релиз не публикуются.

Продолжение: TEST-рецепты/допуски и обратная связь по реальному составу. Не считать реализованными склад, покупку/пополнение, уборку, реактивную химию, разделение фаз пятен, звуковой стук или перенос напитка в новый сосуд без слива. Управление и стабильные API — WORKBENCH.md/CONTRACTS. Общие STATUS/BACKLOG/ADR сводит координатор по исключению AGENTS/PARALLEL_WORK.

# 2026-10-27: WORKBENCH-04 — исследование техник и отдельные смеси

Исполнитель: агент владельца, codex/mixing-vessels от e351a9a. Карточка WORKBENCH_04, in_progress до чистой/Windows проверки.

Исследованы собственные материалы Simon Difford/Difford’s Guide и учебная страница American Bartenders School: stir/shake/build/layer, роль льда/разбавления/аэрации, смешивающая тара/процеживание, плотность и мягкая струя, газированные компоненты, контроль пропорций. Точные ссылки/краткие пересказы и явные игровые допущения — BARTENDING_RESEARCH.md. Прежний абсолютный запрет слоя без ложки исправлен: ложка расширяет допуск, допустим тихий налив у стенки.

Сделано: три независимые DrinkPreparation, составные дозы/атомарный частичный transfer/extract, настоящие остатки и пролив, продление одного слоя из смеси, сохранение фаз/техники. Лёд добавляется мышью, при обработке даёт реальную воду/разбавление/охлаждение; shake отличается аэрацией и мощностью, без льда нет воды/холода. Газированный TEST-компонент не встряхивается. Стрейнер встроен в перелив, лёд остаётся в источнике. Лёгкое представление get_view не копирует растущий operations каждый кадр. Струя идёт из настоящего носика смешивающего сосуда, пакеты по 0.1 с ограничивают рост журнала. Подаётся только стакан подачи; source-модели/пауза/смена посуды независимы. У гостя свежий лёд при его наличии виден в посуде.

Файлы: content/drinks/test_materials.json; scripts/service/drinks/drink_preparation.gd; scripts/ui/preparation/drink_workbench.gd; scripts/characters/service_guest.gd; tests/parallel/bar/drink_core_test.gd и workbench_test.gd; docs/parallel/bar/WORKBENCH_04, BARTENDING_RESEARCH, WORKBENCH, CONTRACTS, DECISIONS, STATUS, HANDOFF, WORKLOG. Новых зависимостей/общих сцен нет; Main/дом/журнал/checkpoint/preferences/общие runner не менялись.

Проверки Godot 4.7.2 Windows:

- tools/check_drink_core.ps1: PASS, ядро 837/0 и прежняя лаборатория 5/0; artifacts/drink-core-106efec78e7e4feba6c819de5b8b2e19 (mixing-core-verified.log). Проверены составной слой/продление, атомарность обоих сосудов при отказе/переполнении/дублях/печати, настоящее таяние/разбавление/крепость, dry shake, различие stir/shake, остающийся лёд при процеживании, газировка, раздельные фазы/эмульсия, перенос талой воды из слоёв, независимость лёгкого view.
- tools/check_workbench.ps1 -Graphics: PASS, 119 headless/126 GPU 1280×720/126 GPU 960×600; artifacts/workbench-6b7bb4e15adc44c0b5f9e058623dcdef (mixing-workbench-verified.log). Мышью проверены отдельная смесь из двух материалов, лёд, stir, частичный налив по ложке поверх плотной основы, три компонента верхнего слоя (включая воду), сохранение остатка/льда/двух черновиков/запасов при возврате, пролив смеси. Прежний путь подачи и диалога также PASS. PNG новой тары/07-premix-layer просмотрены на графическом прогоне 32956ae6d4254e67b7944fe29ccf12c7; последний прогон проверяет то же отображение с финальными граничными проверками.
- tools/check.ps1: общий PASS, artifacts/mixing-regression.log. Последние граничные исправления ядра ещё проверяются полным набором из чистого коммита.
- git diff --check PASS. Тесты отключают реальные checkpoint/preferences; пользовательские файлы не меняются.

Границы: коэффициенты температуры/таяния/аэрации TEST, обработка жестами ускорена, passive melting/heat/diffusion не моделируются; стрейнер/крышка автоматические, ведёрко льда бесконечное, тепловая масса и точная физика пены не считаются. Рецепты/джиггер/гарниши/растирание/реакции/склад и сохранение приготовления следующие этапы. Контракты и решения записаны локально; общие реестры сведёт координатор. Следующий конкретный шаг — TEST-рецепты/допуски и дозировка поверх независимых составов и технологии, без изменения домашнего модуля.

## WORKBENCH-04: итоговая проверка и передача

Код 83f3cedc52837873bc8f8816371ca1a0354427c8, done. Чистый git archive без исходного .godot: artifacts/mixing-clean-83f3ced. PASS: tools/check.ps1, check_drink_core.ps1 (837/0 и lab 5/0), check_workbench.ps1 (119/0), check_bar_service.ps1 (52/0). Логи artifacts/mixing-clean-{check,check_drink_core,check_workbench,check_bar_service}.log.

Windows Desktop tools/build_windows.ps1 PASS: builds/windows-20261027-221632-225e3fd9.zip, source_revision=83f3ced, source_dirty=false. Распакован в artifacts/mixing-unpacked-83f3ced, все SHA256 по manifest проверены; EXE --headless --quit-after 5 без ошибок.

После чистых проверок только во временной копии integration_test main_scene изменена на res://tests/parallel/bar/workbench_test.tscn (обычный release-template запрещает path overrides). export-release Windows Validation PASS. EXE: headless 119/0, GPU 1280×720 126/0, GPU 960×600 126/0; логи/семь PNG artifacts/mixing-validation-83f3ced. 07-premix-layer из малой экспортированной версии просмотрен: носик/струя/верхний составной слой/остающийся лёд видны. Рабочий project.godot и общие runner не менялись.

Все 14 путей относительно e351a9a внутри карточки: модель/UI/production-данные/ледяной показ у гостя/собственные тесты и документы. Main/сцены/дом/журнал/сохранения/preferences/общие реестры не затронуты. Новых зависимостей/ресурсов, требующих .uid, нет. git diff --check PASS. Последующий коммит только итоговый статус/передача/результаты, проверенный игровой SHA остаётся источником сборки. Ветка передаётся для ревью; main/релиз не меняются.

Продолжение: TEST-каталог рецептов с допусками и дозировка/джиггер на фактическом составе и технологии; новое бытовое/сюжетное содержание не требуется. При проектировании учитывать BARTENDING_RESEARCH: коэффициенты условны, льдогенерация бесконечная TEST, passive тепловые процессы/точная пена/отдельная работа стрейнером/реальная химия пока не реализованы. Схема сохранений не расширялась. Общие STATUS/BACKLOG/ADR/TESTING сведёт координатор по исключению AGENTS/PARALLEL_WORK.
