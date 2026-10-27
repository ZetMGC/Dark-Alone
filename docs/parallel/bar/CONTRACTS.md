# DA-060: изменённые контракты и потребители

## WORKBENCH-01: дополнение 2026-10-27

Main экспортирует `drink_workbench_enabled: bool=true`, включает новый ServicePanel только совместно с free_roam_enabled и передаёт флаг через RUN_HANDOFF при новой смене. Legacy false сохраняет прежние сигналы/меню. Потребители: Main, ServicePanel, профиль bar_service_dialogue (явно false), новый workbench_test (текущий путь).

ServicePanel добавляет `enable_workbench() -> void`, `workbench_enabled`, `workbench: DrinkWorkbench` и сигнал `preparation_requested(preparation: DrinkPreparation)`. set_open управляет активностью поверхности; прежний serve_requested не меняется. Слой нового сервиса 11, пузырёк 12. DialogueBubblePanel добавляет `set_workbench_overlay(enabled: bool) -> void`: при приготовлении переносит пузырёк в свободную верхнюю правую область без сброса страницы/набора; прежний барьер ввода сохраняется.

NarrativeSession добавляет `serve_preparation(preparation: DrinkPreparation) -> bool`: только SERVICE, вне _changing, с прежней проверкой времени. GuestService добавляет одноимённую команду и `get_prepared_drink() -> Dictionary` (глубокая копия). Проверки configured/served/mutating/null предшествуют seal(&"delivery"); пустой результат отклоняется. Успех сохраняет запечатанный результат, selected_drink_id=prepared_drink и испускает прежний service_completed с тем же service:<guest_id>; время списывается прежним обработчиком один раз. get_served_drink возвращает карточку приготовленной порции. Произвольные внешние Dictionary вместо модели не принимаются. Потребители: Session, представления итогов, новый профиль; дом/checkpoint/preferences не меняются.

DrinkWorkbench владеет одной DrinkPreparation и позициями предметов; его typed-команды и сигналы описаны в исходнике, пользовательский путь — WORKBENCH.md. set_active(false), потеря фокуса, resize завершают удержание без commit_drop, сбрасывают струю и сохраняют уже налитые дозы. Порция остаётся в памяти сцены; файл данных production — content/drinks/test_materials.json, не каталог tests. Подача только через перенос непустого стакана на поднос.

DrinkPreparation: медленная layered-доза того же единственного ингредиента верхнего слоя теперь продлевает этот слой (`outcome=layer_extended`), сохраняя нижние. Быстрая доза по-прежнему смешивает. Схема снимка/методы не меняются; потребители лаборатория, новый верстак, будущие рецепты. Регрессия непрерывных доз добавлена в drink_core_test.

Локальное дополнение к общему CONTRACTS, которое сводит координатор при интеграции. Решение — DECISIONS.md в этой папке. Домашние файлы и API не меняются.

## NarrativeSession

concurrent_service_enabled: bool=false — opt-in, Main задаёт free_roam_enabled до configure. Legacy по умолчанию прежний. `can_open_service() -> bool` — запрос доступности по режиму/configuration/served/времени, без мутации; намеренно не зависит от _changing, чтобы UI внутри mode_changed видел итоговую доступность. Команда open_service дополнительно проверяет _changing.

При opt-in open_service допускает DIALOGUE и сохраняет _service_return, не меняя Runner. close_service и успешная serve_drink возвращают в сохранённый режим. SERVICE с активным Runner показывает пассивный пузырёк и продолжает набор. Menu/Journal скрывают оба экрана, возвращают точный прежний контекст; open_journal допускает SERVICE только при opt-in, ключ/страница/выбор речи не сбрасываются. choose_for_node/finish_for_node/cancel_dialogue по-прежнему принимают только DIALOGUE, в SERVICE отклоняются.

При активном Runner и готовых часах _has_service_time требует >=2 делений, иначе open_service/serve_drink отклоняются; проверка перед фактической подачей повторная. Вне разговора можно использовать последнее деление. Стоимости и ShiftClock API/схема прежние. Нулевое время не создаётся подачей посреди незавершённой реплики. configure_commute, режимы HOME/TRAVEL/Journal/Menu, сигналы и формат checkpoint не изменены.

## Main и представления

Main при free-roam разрешает E по back_counter в EXPLORATION/DIALOGUE; NPC остаётся целью начала только EXPLORATION. SERVICE и прочие модальные экраны блокируют мир. В DIALOGUE фокус оставляет неподвижную камеру и курсор; первый Escape из выбора закрывает его, второй из фокуса отходит, свободный Escape открывает меню. Автоматический выход из фокуса выполняется только при успешном первоначальном _start_dialogue, а не при каждом возврате в DIALOGUE. Начало/подача/выход сохраняют Runner и физическое тело.

DialogueBubblePanel: `set_response_input_enabled(enabled: bool) -> void` блокирует UI confirm/reveal_text/advance_page/select_relative/submit_choice и перехват F/цифр/колеса/Backspace, не останавливая набор. `set_service_overlay(enabled: bool) -> void` скрывает нижнюю подсказку, чтобы не накладывать её на выбор напитка. can_answer учитывает разрешение ввода. Main выключает ввод у фокуса/в SERVICE/пауза; разрешает при свободном DIALOGUE. Публичные методы сохранили сигнатуры; модельные команды по-прежнему не зависят от анимации.

ServicePanel: `set_conversation_context(active: bool) -> void` выбирает компактную нижнюю правую карточку без Shade при активном Runner, иначе прежнее полное меню. В компактном варианте показаны кнопки без отдельных описаний/разделителей, описания доступны как tooltip; оба TEST-напитка помещаются без прокрутки. Это только отображение; истинное состояние живёт в Session. `NavigationHUD.update_workstation(rig, exploration, dialogue: bool=false)` добавляет необязательный флаг для подсказок/видимости при разговоре, старые вызовы совместимы. Screen/Menu, используемые домом, сохраняются. FreeRoamCamera не изменялась.

Потребители: scripts/main/main.gd, scripts/session/narrative_session.gd, scripts/ui/{dialogue_bubble_panel,service_panel,navigation_hud}.gd; новый bar_service_dialogue_test и wrapper check_bar_service.ps1; тематические документы. Существующие тесты моделей/всего цикла остаются отдельной регрессией. Общие check.ps1/export runner намеренно не меняются в параллельном раунде; новый тест подключит координатор.

## DRINK-CORE-01: независимый контракт приготовления

[DRINK_CORE](DRINK_CORE.md) фиксирует новые DrinkMaterialCatalog/DrinkPreparation, JSON материалов/сосудов, команды с идемпотентными ID и снимок результата. Текущие потребители — собственные тесты/TEST-стенд; Main/GuestService/дом не подключаются и прежние публичные интерфейсы не меняются. При дальнейшей интеграции рецепты/подача читают снимок, не изменяя порцию задним числом.
