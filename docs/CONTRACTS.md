# Контракты интеграции

HOME-03: публичный API HOME-02 прежний. HouseInterior после построения основы создаёт локальный VisualDressing и вызывает build(source: Node3D)->void. Единственный игровой потребитель — HouseInterior. Декор не добавляет коллизий/состояний прогресса; накладки следуют старым петлям, ткань — размерам/положению старой шторы, источники — выключателям. Environment назначена только домашней камере. [ADR-0045](decisions/0045-house-visual-layer.md), house_visual_test/house_layout_test.

BAR-NIGHT-01: EnvironmentAudio.configure_night_bar()->void переключает Street на тихий 16-секундный дождь и переносит Street/Furniture к окну/посадочным местам новой локации. Вызывает только Main при reference_bar_enabled. set_gain/set_context и схема предпочтений прежние. [ADR-0044](decisions/0044-night-bar-atmosphere.md); проверяет reference_bar_test, старый профиль — environment_camera_test.

DA-080: ReplyChoiceRow body содержит только авторский caption; hovered/activated позволяют выбрать и выполнить строку без номеров. DialogueBubblePanel принимает E и клик, цифровые/колёсные shortcut-ветки удалены. FreeRoamCamera.set_dialogue_pointer(bool) освобождает курсор только для доступных ответов, не блокируя ходьбу; скрытие панели/закрытие режима возвращает прежний захват. Повторная проверка can_answer и актуальной цели сохранена. Подпись мыши на экране не выводится. Исторические записи о номерах ниже не являются текущим управлением.

DA-079: ReplyChoiceRow — HBoxContainer с key_label/body, set_choice(caption,index,count,chosen,font,font_size), set_selected(bool), natural_width() и читаемым text. Потребители: DialogueBubblePanel и ObjectContextBubble. ReplyPanelLayout.rect(choices,area) возвращает компактную общую область над нижним краем. Индексы выбора и сигналы ответа прежние. speech_hold_seconds=3.0 / speech_fade_seconds=1.2 управляют только VoiceBubble: после завершения последней страницы alpha уменьшается, без изменения Runner/VoiceReplies/can_answer. Новая страница сбрасывает alpha/таймер; скрытая панель и потеря фокуса останавливают отсчёт. Промежуточная страница не исчезает до E.

DA-078 done: действия перенесены из предметного пузырька в область ответов диалога (низ по центру, тот же стиль и отступ 60). У действия указана реально работающая клавиша E; несколько действий также пронумерованы. У объекта остаются только сведения/состояние. Пассивный осмотр не показывает панель действий. [Протокол](worklog/2026-10-28-13-action-reply-area.md). Единая клавиша взаимодействия/продолжения речи/подтверждения — E, F удалена. Во время разговора E у доступного предмета относится к нему, у собеседника — к реплике. Обновлены существующие билд и ярлык; чистый source 6a31164, хеши и запуск PASS.

DA-077: Interactable3D предоставляет context_title/description/passive/anchor/feedback, get_context_actions()->Array[Dictionary] (id/text), activate_context_action(id)->bool. Метаданные не сохраняются на диск. ObjectContextBubble получает InteractionController/Camera3D, проецирует context_anchor либо hit_position; скрывается без актуальной доступной цели, вне кадра и в модальных режимах. Активация повторно проверяет луч/доступность. Номера/колесо/E обрабатываются только в exploration/home, не конкурируют с диалогом. HouseActionTarget пропускает interact для пассивного осмотра. House feedback привязан к источнику действия и очищается при отведении взгляда. Потребители: Main/HUD, HomeExploration/HouseInterior, прицел и карточка верстака. Существующие команды/прогресс legacy-осмотров и событий сохранены.

DA-076: NoticeBubble.show_hint(message, key="", once=true) — пассивный пузырёк без перехвата ввода, 4.5 с, затухание/дедупликация в рамках экземпляра UI. Потребители: HUD, дом, речь, дневник, верстак. InteractionReticle использует существующие get_target/is_available, не меняет активацию объектов. DrinkWorkbench.get_hovered_bottle_info(point) принимает логические координаты поверхности, возвращает id/title/remaining_ml/strength либо пустой словарь при захвате/неактивности/промахе. Форматы save и игровые команды прежние.

BAR-PLAN-02 / CHAR-10: [ADR-0039](decisions/0039-reference-bar-layout.md) уточняет внутренние wall_x/wall_z(..., door: bool=false), chair(pos, yaw) у ReferenceBar; потребитель только его генератор. [ADR-0038](decisions/0038-visitor-behavior.md) задаёт приоритет анимаций без изменения публичного VisitorModel/VisitorBehavior API. Проверки: reference_bar_test, visitor_behavior_test, visitor_model_test.

CHAR-08 уточняет VisitorBehavior: автоматический уход по session.shift.finished после закрытия Runner/возврата стакана; dialogue_finished отдельной ветки его не запускает. [ADR-0038](decisions/0038-visitor-behavior.md). Публичные сигнатуры прежние.

BAR-PLAN-01: Main.reference_bar_enabled включает ReferenceBar, VisitorBehavior.entrance/waypoints задают маршрут новой локации. Путь/ID поверхностей и якорей сохранены; рабочая точка и подача перенесены. [Контракт](BAR_REFERENCE.md), [ADR-0039](decisions/0039-reference-bar-layout.md).

CHAR-07: опциональный Main.visitor_behavior_enabled, VisitorBehavior и ServiceGuest.drink_presented/motion_available, цели процедурных цепочек VisitorModel. [Полный контракт/потребители](decisions/0038-visitor-behavior.md), [инструкция](VISITOR_BEHAVIOR.md). Включено в reasoning_demo; данные диалога/дневника/заказа не меняются.

DA-072–074: speech target/display разделены для плавного движения и hysteresis стороны, не меняя правила ответа. Новый временный UI-state крышки шейкера и API toggle/get — [барный контракт](parallel/bar/CONTRACTS.md). HUD.show_settings(bool)/close_settings()->bool — отдельная страница меню, Esc сначала обрабатывает возврат; пути % настроек прежние. Основная сцена вновь включает PreferenceStore, тестовые fixtures продолжают использовать отключение/изолированные хранилища. [Настройки](PLAYER_SETTINGS.md), [протокол](worklog/2026-10-28-09-speech-shaker-settings.md).

DA-071: selected_index/submit_choice(index) в DialogueBubblePanel относятся к отфильтрованным **доступным видимым ответам**, нумерация 1…N; выбор сохраняется по choice_id при появлении вариантов после вывода. Terminal/no choices скрывают VoiceReplies, F завершает через VoiceHint. Потребители/исключение can_answer terminal — [DIALOGUE_BUBBLES](DIALOGUE_BUBBLES.md), [ADR-0033](decisions/0033-available-dialogue-replies.md). Модальный fallback/модель/сохранения прежние.

DA-070: варианты вывода выбираются мышью в пузырьке у точки группы; hit bounds get_option_rect соответствуют новым строкам, для неверного индекса пустой Rect2. Потребители/семантика отмены — [JOURNAL_REASONING](JOURNAL_REASONING.md), [ADR-0032](decisions/0032-conclusion-popup.md). Модель/сохранения прежние.

DA-068: двухэтапный дневник (подъём закрытой книги → клик/раскрытие), вывод внутри группы и зависимые варианты/предпосылки. Публичные расширения Session/Panel/Reasoning, потребители и восстановление — [JOURNAL_REASONING](JOURNAL_REASONING.md), [ADR-0031](decisions/0031-closed-book-reasoning-chains.md). Новый TEST — отдельная наследованная сцена/пара каталогов, обычный Main и его hash не изменены.

DA-067: [дополнение JOURNAL_REASONING](JOURNAL_REASONING.md)/ADR-0030 заменяет ручную обводку на open_conclusion(group_id) через точку. Новые get_conclusion_button_rect/get_visible_links/get_page_preview и Journal.make_visual_copy; Catalog.get_reasoning_links, Reasoning.configure(groups,links=[])/get_link_definitions/get_links(sheet). Связи валидируются, выводятся после обеих записей, новых save-полей нет. Panel.preview_mode — только изолированная отрисовка без opened; временный settle блокирует ввод при передаче кадра. Прежние публичные сигналы Session и определения conclusion/evidence сохранены.

DA-066 заменяет игровое письмо DA-065: [JOURNAL_REASONING](JOURNAL_REASONING.md), ADR-0029. Новые Catalog getters, Journal.choose_conclusion/has_conclusion/get_reasoning_groups/get_journal_recipes, JournalReasoning и optional conclusions в progress; choice.required_conclusions/missing_conclusions в Runner. PaperPages.bind теперь принимает Journal; редактор удалён, choose_option проверяет видимость/порог/контекст, finish_edit — no-op совместимости. Notebook читается архивом. Потребители: Catalog/Validator/Journal/Runner/оба dialogue UI/Session/Panel/PaperPages/BookArt, профильные тесты. Верхние checkpoint/Session-сигналы прежние, источниковые определения не переписываются выбором.

DA-065: [личные страницы/изменённые UI-контракты](PERSONAL_JOURNAL.md), [ADR-0028](decisions/0028-personal-paper-journal.md). Journal.notebook и опциональный notebook в progress; старые сохранения читаются. Поиск/фильтры/InkTool удалены из сцены, select_section/set_ink_tool заменяют управление. Сигналы Session/семантические пометки/граница checkpoint прежние. Потребители перечислены по ссылкам.

CHAR-06: VisitorModel `talking`, новый `speaking: bool`, `begin_line(key: String)->void`; потребитель GuestArt связывает состояния с активным Runner/печатанием DialogueBubblePanel. Опорная кисть ограничена высотой TEST-стойки 1.16 м. [ADR-0037](decisions/0037-conversation-gestures.md) описывает паузы, SERVICE и ограничения переноса. Runner/сохранения прежние.

CHAR-04/ADR-0029: ServiceGuest.configure_body_scale(float)->bool обновляет уникальные капсулы/позиции от пола без накопления, отклоняет неконечные/неположительные значения. Вызывает GuestArt при смене D/A/B/C. ServiceGuest/GuestArt.get_dialogue_head_position()/get_dialogue_face_position()->Vector3 возвращают мировые точки. Bubble опционально вызывает их, для обычного Node3D использует прежние +0.36/+0.06; взгляд считается к face. Потребители/проверки: GuestArt, ServiceGuest, DialogueBubblePanel, visitor_model_test/capture_visitor и прежние bubble/world/faces/free_roam. [Описание](CHARACTER_PROTOTYPE.md).

CHAR-02: внешний GuestArt API/ID test_visitor остаётся прежним. VisitorModel теперь содержит CharacterMesh со Skin; внутренние BoneAttachment3D-детали удалены. is_blinking читают тест/съёмка, talking управляется Session. Обновлены visitor_model_test/capture_visitor; Main/ServiceGuest не зависят от внутреннего дерева. [Актуальный контракт](CHARACTER_PROTOTYPE.md).

CHAR-01: GuestArt принимает новый ID test_visitor через прежний set_test_appearance; меню получает вариант D. TestFace.get_appearance_ids сохраняет только A/B/C. Смена внешности не меняет ServiceGuest/коллизии/Session. Полный контракт/потребители — [CHARACTER_PROTOTYPE](CHARACTER_PROTOTYPE.md).

DA-063 объединяет действующие [барные контракты](parallel/bar/CONTRACTS.md) с домашними/дневниковыми ниже. DA-060 и WORKBENCH-01–04 включают одновременное обслуживание/речь, независимые составы и технологию смешивания. [ADR-0026](decisions/0026-bar-home-journal-integration.md) фиксирует совместимость и общие профили; checkpoint/preferences/Home API не меняются барной интеграцией.

Интегрированы 2026-10-27: [домашние поверхности/бытовые действия](parallel/home/CONTRACTS.md) и [семантические пометки дневника](parallel/journal/CONTRACTS.md). Эти документы являются частью действующего контракта main. Прежние Main/Session/InteractionController/FreeRoamCamera и схема верхнего checkpoint не менялись; Journal дополнен annotation API и опциональным annotations в собственном прогрессе, старые данные читаются. Description книги теперь собственный Control/TextParagraph. Подробности/потребители/ограничения указаны по ссылкам; общий check.ps1 включает новые home_target, house_layout, journal_ink.

DA-052 заменяет игровое перемещение по графу ходьбой/локальным фокусом. API AnchorCamera ниже сохранён для старого контракта; новые типы/потребители описаны в разделе DA-052 в конце. [FREE_ROAM](FREE_ROAM.md).

**Статус:** навигация M1, контент/исполнение DA-020–DA-021, обслуживание DA-022 и смена DA-023 реализованы. Не считать интерфейсы будущих модулей существующим API.

## Якоря — implemented, DA-010–DA-012

Реализация: [AnchorPoint](../scripts/navigation/anchor_point.gd), [AnchorCamera](../scripts/player/anchor_camera.gd), решение ADR-0002. Поля якоря: `anchor_id: StringName`, `display_name: String`, `neighbours: PackedStringArray`; глобальный transform задаёт позу камеры. ID уникален в локации, масштаб единичный. Смена позы — fade, маршрутов интерполяции пока нет.

Внешний API `AnchorCamera`:

```gdscript
func configure(anchors_root: Node3D, initial_id: StringName) -> bool
func can_move_to(anchor_id: StringName) -> bool
func request_move(anchor_id: StringName) -> bool
func get_anchor(anchor_id: StringName) -> AnchorPoint
func get_anchors() -> Array[AnchorPoint]
func set_controls_enabled(enabled: bool) -> void
func reset_look() -> void
func apply_look_delta(delta: Vector2) -> void
signal transition_started(from_id: StringName, to_id: StringName)
signal anchor_reached(anchor_id: StringName)
```

`configure` вызывать после входа камеры и якорей в дерево. Корень содержит AnchorPoint непосредственными детьми. При ошибке false, причины — `validation_errors: PackedStringArray`; старый граф и поза сохраняются. Проверяются дубли/пустые ID, отсутствующие соседи, самоссылки, повторы связей, конечность transform и единичный масштаб. Вызов во время перехода отклоняется.

Поля `current_anchor_id`, `is_transitioning`, `view` предназначены для чтения потребителями; не менять их извне. `current_anchor_id` обновляется после fade-in; физическая поза меняется в середине перехода под чёрным экраном. Порядок `get_anchors` — порядок детей сцены; UI и цифровые клавиши используют его. M1 предполагает четыре точки; добавление пятой требует расширить InputMap и UI.

`request_move` возвращает принят ли запрос, а не завершён ли переход. Во время перехода новые запросы отклоняются; неизвестный ID не меняет состояние. При отклонении нет события завершения. Для принятого перехода `anchor_reached` испускается один раз. Начальная установка камеры — отдельный явно документированный путь, а не игровой переход.

## Взаимодействие — implemented, DA-013

Базовый тип [Interactable3D](../scripts/interaction/interactable_3d.gd) (Area3D): `is_available() -> bool`, `get_prompt() -> String`, `interact() -> void`. [InteractionController](../scripts/interaction/interaction_controller.gd) предоставляет `configure(view: Camera3D)`, `set_enabled(enabled: bool)`, `activate(target: Interactable3D) -> bool`, `try_interact() -> bool` и сигнал `prompt_changed(prompt: String)`.

Луч смотрит из центра камеры на 15 м; маска 3 включает слои геометрии и целей, `collide_with_areas=true`. Ближайшая стена перекрывает выбор. `activate` повторно проверяет доступность. Прямое действие через кнопку маршрута не требует видимости точки в кадре, но требует разрешённого ребра графа. Main отключает контроллер при переходе и меню.

`AnchorPoint.set_available(value: bool)` управляет доступностью, маркером и слоем цели; `move_requested(anchor_id: StringName)` сообщает о действии. Main обновляет доступность по `can_move_to` при смене режима. Для будущего гостя наследовать Interactable3D и подключать событие к координатору, не встраивать знания о диалогах в камеру.

## Каталог и валидация — implemented, DA-020

Реализация: [DialogueCatalog](../scripts/dialogue/dialogue_catalog.gd), [DialogueContentValidator](../scripts/dialogue/dialogue_content_validator.gd). Схема данных v1 принята в ADR-0003 и подробно описана в [DIALOGUE_CONTENT](DIALOGUE_CONTENT.md).

```gdscript
func load_files(glossary_path: String, dialogue_paths: PackedStringArray) -> bool
func load_data(glossary: Variant, documents: Array, glossary_source: String = "glossary", sources: PackedStringArray = []) -> bool
func is_loaded() -> bool
func has_term(term_id: StringName) -> bool
func has_dialogue(dialogue_id: StringName) -> bool
func get_term(term_id: StringName) -> Dictionary
func get_dialogue(dialogue_id: StringName) -> Dictionary
func get_node(dialogue_id: StringName, node_id: StringName) -> Dictionary
func get_term_ids() -> PackedStringArray
func get_dialogue_ids() -> PackedStringArray
```

`validation_errors: PackedStringArray` — диагностика последней попытки. Загрузка атомарна: false не подменяет прежний успешный снимок. `is_loaded` означает наличие такого снимка, не успех последней попытки. Потребитель обязан проверять bool загрузки. После успеха ошибки очищаются.

Геттеры возвращают глубокие копии, неизвестные ID — пустой Dictionary; списки ID отсортированы. В копии диалога и термина присутствует `test_content` из документа. Для прямой проверки данных без каталога: `DialogueContentValidator.validate(glossary: Variant, documents: Array, glossary_source: String = "glossary", sources: PackedStringArray = []) -> PackedStringArray`; пустой список ошибок означает валидный комплект. Валидатор не меняет входные данные.

## Исполнитель диалогов — implemented, DA-021

Реализация: [DialogueRunner](../scripts/dialogue/dialogue_runner.gd), RefCounted. Решение ADR-0004, подробная интеграция — [DIALOGUE_RUNTIME](DIALOGUE_RUNTIME.md).

```gdscript
func configure(catalog: DialogueCatalog, journal: Journal, shift_number: int = 1) -> bool
func start(dialogue_id: StringName) -> bool
func choose(choice_id: StringName) -> bool
func finish() -> bool
func cancel() -> bool
func get_current_node() -> Dictionary
func get_choices() -> Array[Dictionary]
func get_dialogue_title() -> String
func is_terminal() -> bool
signal node_changed(dialogue_id: StringName, node_id: StringName)
signal dialogue_finished(dialogue_id: StringName)
signal dialogue_cancelled(dialogue_id: StringName)
```

Формат JSON v1 уже принят: разговор с ID и start_node; узел с ID, speaker, text, end, choices и effects; выбор с ID, text, target, required_terms. Подробности — DIALOGUE_CONTENT. Терминальная нода явно завершается, а не ссылается на несуществующий ID. Использовать стабильные ID выбора, не индекс кнопки.

Статические проверки выполняет DA-020. configure вызывается один раз и копирует определения; Journal уже должен быть настроен и знать термины каталога. На неудачу false, без старта. Новая игровая сессия создаёт новые модели. Каталог после этого можно менять независимо: Runner использует снимок.

Поля только для чтения: active, current_dialogue_id, current_node_id. start отклоняет неизвестный ID и параллельный разговор; choose — неизвестный/недоступный выбор. get_choices сохраняет порядок и добавляет available: bool, missing_terms: PackedStringArray. Геттеры возвращают копии; вне разговора узел пуст, варианты пусты, is_terminal=false.

Эффекты входа применяются до node_changed. grant_term имеет ключ `(dialogue_id, effect_id)` и не повторяется в цикле, при перерисовке или новом начале того же разговора в этой сессии. Команды из обработчиков сигналов во время изменения отклоняются; обработчики могут читать состояние.

Терминальный текст остаётся активным до finish. finish очищает текущее состояние и сигналит один раз; ID берётся из аргумента сигнала, не из уже очищенного current_dialogue_id. cancel очищает состояние с отдельным dialogue_cancelled, без dialogue_finished. Термины сохраняются; start после обоих исходов разрешён. Runner не считает время; NarrativeSession передаёт завершение в ShiftClock.

## Дневник — implemented, DA-021

Реализация: [Journal](../scripts/journal/journal.gd), RefCounted.

```gdscript
func configure(catalog: DialogueCatalog) -> bool
func is_configured() -> bool
func add_term(term_id: StringName, source: Dictionary = {}) -> bool
func has_term(term_id: StringName) -> bool
func get_definition(term_id: StringName) -> Dictionary
func get_known_term_ids() -> PackedStringArray
func get_entries() -> Array[Dictionary]
signal term_added(term_id: StringName)
```

configure вызывается один раз из принятого каталога. add_term возвращает true только при первом добавлении известного ID; неизвестный и повторный ID — false без события. Данные определения копируются, порядок entries и known_term_ids — порядок получения. Неизвестное определение — пустой Dictionary. Записи живут до закрытия сессии, на диск не пишутся.

## Сессия и панели — implemented, DA-021

[NarrativeSession](../scripts/session/narrative_session.gd) предоставляет configure(catalog, dialogue_panel, journal_panel, service_panel=null, guest_id=&"", drink_options=[]) -> bool, start_dialogue(dialogue_id) -> bool, choose_for_node(dialogue_id, node_id, choice_id) -> bool, finish_for_node(dialogue_id, node_id) -> bool, cancel_dialogue() -> bool, open_journal/close_journal/open_menu/resume_menu() -> bool. Новые необязательные параметры DA-022 сохраняют прежние трёхаргументные вызовы без сервиса. Сигналы mode_changed(mode: StringName), journal_changed(count: int). mode, runner, journal и service предназначены для чтения/привязки, не для перенастройки UI-потребителями.

Все игровые команды UI идут через NarrativeSession: прямой runner.choose обошёл бы модальные блокировки. Команды выбора/завершения допустимы только в dialogue и при совпадении ID текущего узла; старые кнопки безопасно отклоняются. journal и menu хранят режимы возврата, сами не отменяют разговор. Main дополнительно проверяет текущий якорь и переход камеры перед стартом/открытием дневника.

Main.start_test_dialogue() -> bool — общий вход разговора, доступен только в exploration у DialogueTrigger.required_anchor вне fade. DialogueTrigger наследует Interactable3D, сигналит dialogue_requested(dialogue_id), имеет set_available(bool). В DA-022 корневой узел с прежним именем DialogueTrigger стал экземпляром [ServiceGuest](../scripts/characters/service_guest.gd), который наследует этот контракт. Самостоятельная прежняя сцена сферы сохранена для технических проверок.

## Гость и обслуживание — implemented, DA-022

[GuestService](../scripts/service/guest_service.gd), RefCounted:

```gdscript
func configure(id: StringName, options: Array[Dictionary]) -> bool
func is_configured() -> bool
func get_options() -> Array[Dictionary]
func get_served_drink() -> Dictionary
func serve(drink_id: StringName) -> bool
signal service_completed(event_id: StringName, guest_id: StringName, drink_id: StringName)
```

Первый аргумент configure задаёт ID гостя. Каждый option содержит только id/title/description, непустые строки. ID — snake_case, без дублей. Ошибки — validation_errors; ошибочная первоначальная конфигурация не раскрывает меню. Настройка один раз, getters возвращают копии. Поля served, guest_id, selected_drink_id — только для чтения. serve известного ID допустим один раз; состояние фиксируется до события. ID события `service:<guest_id>` уникален в пределах одного заказа гостя текущей сессии; при множестве заказов нужен новый контракт ID.

NarrativeSession добавляет open_service/close_service() -> bool, serve_drink(drink_id: StringName) -> bool и relay service_completed с теми же тремя аргументами. Сервис настраивается только при передаче ServicePanel и непустого валидного меню в configure. Вызов без панели сохраняет поведение DA-021.

Режим service блокирует мир, разговор и journal. Escape/close_service возвращают exploration без подачи. open_menu запоминает service, resume_menu возвращает его. serve_drink допустим только в service; событие возвращает exploration. Main.open_service_menu() дополнительно проверяет якорь/отсутствие fade и served=false.

ServiceGuest.guest_id задаётся сценой, show_served(drink_title: String) меняет только представление (стакан и подпись). Main связывает сигнал с этим методом и HUD. Получение терминов, время и JSON v1 не меняются. Подробности — [GUEST_SERVICE](GUEST_SERVICE.md).

При настроенном ShiftClock событие подачи возвращает exploration только если смена не закончена; на последнем делении режим — shift_complete, видимый результат всё равно обновляется.

## Время и смена — implemented, DA-023

`ShiftClock` ([код](../scripts/session/shift_clock.gd)), RefCounted: configure(time_budget: int) -> bool, apply_completed_event(event_id: StringName, time_cost: int) -> bool, get_events() -> Array[Dictionary]. Поля remaining/budget/finished только для чтения. Сигналы progress_changed(remaining: int, budget: int), shift_finished. Конфигурация один раз, бюджет > 0. Дубликаты/пустые ID, отрицательная стоимость, вложенный вызов и события после конца отклоняются. Ноль допустим, превышение ограничивается остатком 0; событие конца одно, после фиксации состояния. История выдаётся копиями.

NarrativeSession.configure_shift(time_budget: int, summary_panel: ShiftSummaryPanel) -> bool — дополнительная настройка до игрового прогресса. Старый configure без неё сохраняет поведение самостоятельных моделей. shift предназначен для чтения/подписки, не начисления произвольных событий UI. shift_progress_changed(remaining, budget) обновляет HUD. Каждый start получает ID `dialogue:<id>:<serial>`; finish расходует 1, cancel — 0. Подача расходует 1 по прежнему `service:<guest_id>`.

Q-05 принят владельцем: по умолчанию 2 деления, Main.shift_budget экспортируется для тестового баланса. Новый режим shift_complete блокирует мир. Из него разрешён дневник с возвратом к итогам и меню с тем же возвратом. ShiftSummaryPanel сигналит restart_requested/journal_requested/quit_requested. Main.restart_shift() -> bool допускает перезагрузку только законченной текущей сцены, повторный запрос блокируется. При прямом тестовом сбросе все модели создаются заново; обычный возврат DA-033 сохраняет Journal (описано ниже). Сохранения DA-032 описаны ниже и в SAVES.

JournalPanel.render добавляет необязательный третий аргумент return_to_summary: bool=false для подписи возврата. Отложенные запросы фокуса проверяют присутствие панели в дереве, чтобы пережить перезагрузку.

Одноразовые эффекты (термин, изменение флага, время) не запускать из рендера UI. Согласовать порядок применения и защиту от частичного применения: сначала проверить все эффекты, затем изменить состояние. Событие окончания смены испускается ровно один раз.

## Представление — implemented, DA-030

`PresentationController` — CanvasLayer, сцена `scenes/presentation/presentation.tscn`. API: `configure_controls(hud: NavigationHUD) -> void`, `set_retro_enabled(value: bool) -> void`, `is_retro_enabled() -> bool`, `set_ambience_gain(value: float) -> void`, `get_ambience_gain() -> float`. Main вызывает configure_controls один раз после основной настройки.

NavigationHUD предоставляет уникальные узлы `%RetroCheck` (CheckButton), `%AmbienceVolume` (HSlider 0…1) и `%AmbienceLabel` (Label). Контроллер подписывает их и синхронизирует без повторных сигналов. Число громкости ограничивается 0…1, нечисловые/бесконечные значения игнорируются, ноль останавливает AudioStreamPlayer. Предпочтения живут только в памяти процесса и переживают новую смену, игровые модели не затрагиваются. Слой эффекта 2 ниже HUD/панелей и fade, mouse_filter=IGNORE.

BarLevel/Art зависит от существующих Geometry/Props/Lights/WorldEnvironment; GuestArt — от узлов Body. Они не меняют публичные интерфейсы якорей, взаимодействия, гостя и сессии. Потребители новых UI-узлов — Main, PresentationController и presentation_test. Решение — ADR-0008.

## Переход между сменами — implemented, DA-031

`CommuteFlow` (RefCounted, scripts/session/commute_flow.gd): read-only state: StringName и trip_id: int; start_home/start_work() -> bool, complete(id: int) -> bool, signal state_changed(state: StringName). Порядок at_work → to_home → at_home → to_work → ready. Повторные/неподходящие команды, старый ID и вложенная команда во время сигнала отклоняются. Модель не знает о времени/панелях/ресурсах.

`NarrativeSession.configure_commute(panel: CommutePanel) -> bool` вызывается после configure_shift, до прогресса. Без неё новые действия недоступны, кнопка домой скрыта; прежние потребители работают. go_home() допустим только в shift_complete, go_to_work() — home, finish_commute(trip_id: int) — travel с совпадающим ID. Новые режимы travel/home блокируют мир. Дневник разрешён дома; меню приостанавливает скрытую анимацию, возврат продолжает её. По окончании обратного маршрута испускается new_shift_requested; Main проверяет current_scene, готовность CommuteFlow и защиту от повторной перезагрузки. Прямой restart_shift сохранён.

`CommutePanel`: begin_trip(id: int, to_home: bool), show_home(), stop_trip(), set_open(value: bool, travelling: bool, interactive: bool=true) -> void; сигналы arrived(trip_id: int), work_requested, journal_requested. travel_seconds=3.0. Таймер и пропуск проходят одну защиту _active; фон и управляющие элементы отделяются при чтении дома. Слой 11 ниже дневника, в меню панель скрыта. `ShiftSummaryPanel` добавляет home_requested и set_home_available(value: bool) -> void.

JournalPanel.render получает четвёртый необязательный return_to_home: bool=false; старые вызовы совместимы. Затронуты Main, NarrativeSession, Summary/Journal UI, commute_test, playthrough_test и команды снимков. JSON v1/деньги/сохранения/время не меняются. Данные DA-033 теперь реализованы ниже; книжное представление DA-034 реализовано ниже — JOURNAL_BOOK.

## Основные механики дневника — implemented, DA-033

Journal дополняет прежние записи полями entry_id=`term:<id>`, learned_order (с 1), source, read, bookmarked. source либо пуст, либо содержит ровно непустые строки dialogue_id/node_id/speaker и положительный int shift. Ссылки поставляет принятый Runner, Journal проверяет структуру. Повторное add_term не меняет первый источник/отметки. get_definition остаётся только определением, get_entries/get_entry возвращают глубокие копии данных и прогресса. JSON v1 не менялся.

API Journal: matches_catalog(catalog: DialogueCatalog) -> bool (полное совпадение словаря); get_entry(term_id: StringName) -> Dictionary; get_filtered_entries(query: String="", section: StringName=&"all") -> Array[Dictionary] с all/new/bookmarks; get_unread_count() -> int; select_entry(term_id: StringName) -> bool; set_bookmarked(term_id: StringName,value: bool) -> bool. Read-only selected_term_id, новые сигналы entry_changed/selection_changed(term_id: StringName). Выбор отмечает прочитанной только эту запись. Неизвестный ID/раздел, невалидный source, повтор той же закладки и вложенные изменения отклоняются; фильтрация не меняет данные.

Runner.configure добавляет третий необязательный shift_number=1 и передаёт контекст узла в add_term. NarrativeSession.configure добавляет в конце shared_journal: Journal=null, number: int=1; старые вызовы совместимы. Shared journal принимается только после matches_catalog; configure_shift теперь допускает непустые знания до начала действий новой смены. Session.shift_number — номер текущей смены. select_journal_entry(term_id) / bookmark_journal_entry(term_id,value) -> bool допустимы только в journal; закладка дополнительно проверяет совпадение с выбранным ID. JournalPanel сигналит entry_requested/bookmark_requested, render только рисует, не выдаёт прогресс.

Обычный возврат из дома переносит Journal и number+1 через одноразовый SceneTree metadata dark_alone_journal_handoff (scene/journal/shift). Main проверяет точный scene_file_path/типы, потребляет передачу, Session проверяет каталог. Отказ настройки не маскируется пустым дневником; при отказе reload временная передача удаляется. Прямой Main.restart_shift по-прежнему полностью сбрасывает знания. DA-032 дополнила передачу сохранением на диск; UI/Runner/часы/заказ создаются заново; это не autoload и не общая шина событий.

NavigationHUD.update_narrative получает четвёртый необязательный unread: int=0; update_shift — третий number: int=0 (положительный задаёт номер, ноль сохраняет текущий). Main передаёт начальный номер и непрочитанные записи. При фокусе LineEdit Main не забирает игровые буквы, Escape работает. Затронуты Journal/Runner/Session/Main, JournalPanel/HUD/Commute/Summary и тесты/превью. Решение — ADR-0010, инструкция — JOURNAL_CORE. Книга/страницы/анимации реализованы DA-034 ниже; схема save v1 принята ADR-0019.

## Книга — implemented, DA-034

Journal добавляет `reading_offset: int=0` к каждой записи; `set_reading_offset(term_id: StringName, offset: int) -> bool`, сигнал `reading_position_changed(term_id: StringName)`. Допустимы известный ID и смещение 0…description.length() включительно; дубликат/вложенный вызов отклоняется. Смещение — позиция символа исходной строки, не байт и не номер страницы. Оно переносится с тем же Journal между обычными сменами.

BookPaginator (RefCounted): статические `paginate(text: String,font: Font,font_size: int,area: Vector2) -> Array[Dictionary]` возвращает непрерывные диапазоны `{start,end,text}`; `page_for_offset(pages: Array[Dictionary],offset: int) -> int` выбирает содержащую позицию страницу. Пустой текст даёт одну страницу; EOF относится к последней. Это чистое представление, модель не меняется.

JournalPanel сохраняет прежнюю сигнатуру render. Новые сигналы `opened`, `close_completed`, `reading_position_requested(term_id: StringName,offset: int)`; методы `request_page(direction: int) -> bool` (только -1/1), `begin_close() -> bool`, `force_closed() -> void`, `is_transitioning/is_closing() -> bool`, `get_page_count/get_page_index() -> int` (индекс с 0). `set_open(false)` скрывает/приостанавливает, `force_closed` отменяет/сбрасывает. Чтение выставляет Session после opened или завершённого выбора, render не меняет Journal. Во время анимации выбор/закладки/повторное листание блокируются; закрытие отменяет незавершённый переход.

Session добавляет `set_journal_reading_position(term_id: StringName,offset: int) -> bool`, допустимый только в journal для выбранного ID вне анимации; `request_close_journal() -> bool` запускает закрытие, до конца сохраняет режим journal. Прежний `close_journal() -> bool` синхронно отменяет анимации/закрывает панель и возвращает прежний режим. Main и пользовательская кнопка используют request_close_journal; close_completed вызывает close_journal. Меню скрывает и приостанавливает книгу.

JournalPanel.configure_controls(hud: NavigationHUD) связывает `%BookMotion` (OptionButton full/reduced/off), `%PageVolume` (HSlider), `%PageVolumeLabel`. Методы `set_motion_mode(value: StringName) -> bool`, `set_page_volume(value: float) -> void`: неизвестный режим/нечисловая громкость отклоняются; громкость ограничивается 0…1, ноль останавливает звук. Static motion_mode/page_volume — только предпочтения процесса. Смена режима во время скрытого действия завершает его один раз при возврате. Потребители изменений: Main/Session/JournalPanel, HUD, book_test, journal_core_test, playthrough и инструменты снимков. Старые изолированные проверки используют off, сквозной цикл — полные анимации. JSON/эффекты/часы/Runner не менялись. Решение — ADR-0011, инструкция — JOURNAL_BOOK.

## Экран — implemented, DA-037

DisplaySettings (`scripts/presentation/display_settings.gd`, отдельный Node в Main): `configure_controls(hud: NavigationHUD) -> void`, `is_fullscreen() -> bool`, `set_fullscreen(enabled: bool) -> bool`, `set_monitor(index: int) -> bool`. Смена режима/монитора возвращает false для headless/встроенного окна, повторного значения или неизвестного экрана. Fullscreen использует Window.MODE_FULLSCREEN/native разрешение; возврат восстанавливает окно/развёрнутый режим с ограничением рабочей областью. F11 обрабатывается в контроллере, echo игнорируется; игровые модели/время не меняются. Static-поля содержат только предпочтения окна до закрытия процесса.

NavigationHUD предоставляет `%DisplayMode` (OptionButton: 0 окно, 1 fullscreen), `%DisplayMonitor` (индекс фактического экрана); Main вызывает configure_controls после прочих настроек. Настройки меню помещены в ScrollContainer, `%Resume`/`%Quit` остаются вне него; прежние уникальные имена сохранены. Список/выбор обновляются раз в секунду и по size_changed. `project.godot`: canvas_items/expand от 1280×720, минимум 960×600. Потребители — Main/HUD, display_test, старые проверки и инструменты снимков. Решение — ADR-0012, инструкция — DISPLAY.

## TEST-внешность гостя — implemented для прототипа DA-035

`TestFace` (Node3D, scripts/presentation/test_face.gd, scenes/characters/test_face.tscn): `static get_appearance_ids() -> Array[StringName]`, `set_appearance(id: StringName) -> bool`, `get_appearance_id() -> StringName`, `get_profile() -> Dictionary`. ID test_face_a/b/c — только визуальные профили TEST, не guest_id/character_id. Неизвестный ID возвращает false без замены; до ready можно выбрать профиль, в дереве он пересобирается сразу. Профиль возвращается глубокой копией. Anatomy одна; предыдущая отсоединяется/queue_free, нет новых коллизий/игровых эффектов. Локальная передняя ось +X, начало в центре головы прежней модели.

GuestArt (`scripts/presentation/guest_art.gd`, Body TEST-гостя) после ready предоставляет `configure_controls(hud: NavigationHUD) -> void`, `set_test_appearance(id: StringName) -> bool`, `get_test_appearance() -> StringName`. Static-предпочтение TEST-варианта переживает смену сцены, не хранит личность NPC. Main связывает `%TestFace` OptionButton HUD (индексы A/B/C). В test_guest.tscn прежние Head/Hair/LeftEye/RightEye/Nose/Mouth заменены вложенной TestFace; потребителей старых путей в коде/тестах не было. ServiceGuest/DialogueTrigger/GuestService API, поза/Target/стакан/guest_id не меняются. Потребители: Main/HUD/GuestArt, faces_test и preview, прочие существующие тесты/экспорт. Финальные appearance/portrait привязки требуют Q-04 и нового решения. ADR-0014, TEST_FACES.

## Детализация — implemented, DA-042

DA-042 добавляет к PresentationController `set_image_detail(value: StringName) -> bool` и `get_image_detail() -> StringName`. Допустимы adaptive/native/classic, неизвестное значение возвращает false без изменения. Static-предпочтение переживает новую сцену в памяти процесса; UI `%ImageDetail` OptionButton с индексами 0/1/2 синхронизируется при configure_controls. Оно не зависит от включения ретро-эффекта, не меняет Session/Journal/время. Shader: adaptive virtual_height=0,pixel_block=2; native 0/1; classic 360/2. SCREEN_PIXEL_SIZE задаёт физическое разрешение; resize не требует команды Session.

MSDF включён для стандартного font в project.godot и отдельно для SystemFont book_theme; другие font-ресурсы требуют своей проверки. Потребители: PresentationController/HUD, presentation_test (20), image_detail_test, validation runner и check_windows_export с новым необязательным -Graphics. Этот флаг добавляет графическую GPU-проверку; прежние вызовы checker остаются headless. Формат JSON/знаний/курсора не менялся. Решение ADR-0013, инструкция IMAGE_DETAIL.

## Окружение и камера — implemented, DA-048


AnchorCamera добавляет `configure_controls(hud: NavigationHUD) -> void`, `set_look_sensitivity(multiplier: float) -> void`, `set_transition_duration(seconds: float) -> void`. Конечные значения ограничиваются 0,5…2 и 0,2…1 соответственно, NaN/INF игнорируются. Полная длительность=2*fade_seconds+black_hold_seconds, hold=0,06. Static-предпочтения процесса применяются только при связывании UI, не отменяют configure графа. Изменение длительности не перезапускает активный Tween. HUD предоставляет `%LookSensitivity`, `%LookSensitivityLabel`, `%TransitionDuration`, `%TransitionDurationLabel`, `%ResetCamera`; reset=100%/0,5 с. Прежние API/сигналы движения не менялись.

EnvironmentAudio (scripts/presentation/environment_audio.gd, scenes/presentation/environment_audio.tscn) — Node3D с дочерними Street/Furniture AudioStreamPlayer3D; находится в Presentation. API `set_gain(value: float) -> void` (0…1, нечисловое отклоняется), `set_context(mode: StringName) -> void`. Контекст travel/home выключает новые источники; exploration/dialogue/service/shift_complete возвращает бар, menu/journal сохраняют место. Редкие события только в exploration, при положительной громкости и фокусе; новый интервал после события 18…38 с. Spatial-позиции относятся к текущей сцене бара, без коллизий.

PresentationController добавляет `set_environment_context(mode: StringName) -> void`, пересылает контекст и общий ambience_gain в EnvironmentAudio. Main вызывает его при смене режима, а configure_controls камеры — после остальных настроек. Новые звуки не затрагивают Journal/ShiftClock. Потребители — Main, AnchorCamera/HUD, PresentationController/EnvironmentAudio, environment_camera_test и tools/check.ps1. ADR-0017. Данные/баланс/модели прежние.

## Дом — implemented для TEST-задела, DA-049

HomeState (RefCounted, scripts/home/home_state.gd): `observe(id: StringName) -> bool`, `has_observed(id) -> bool`, `get_observed_ids() -> Array[StringName]`, `get_available_events() -> Array[Dictionary]`, `resolve_event(id) -> bool`, `has_resolved(id) -> bool`, signal changed. Изменения одноразовые, неизвестные ID/вложенные мутации отвергаются; события требуют все наблюдения, геттер возвращает копии. Текущие определения TEST — OBJECTS/EVENTS в модели. Прогресс не принадлежит исходным JSON и не расширяет Journal.

HomeObject наследует Interactable3D: object_id/required_anchor/title/description; `set_available(bool)`, signal inspect_requested(object_id). HomeExploration (Node3D, отдельная сцена): `configure(session: NarrativeSession,hud: NavigationHUD,shared_state: HomeState=null) -> bool`, `inspect(id) -> bool`, `open_event() -> bool`, `close_inspection(commit: bool) -> bool`, `request_work() -> bool`, `handle_input(event: InputEvent) -> bool`, `set_context(mode) -> void`. Read-only для потребителей state/rig/interaction. Изменения осмотра/события только по явному завершению в HOME, отмена без эффектов, выход только у двери вне перехода/осмотра. Книга/меню сохраняют незавершённый осмотр, скрытые действия отвергаются. E требует ray; кнопка осмотра требует текущий якорь, не видимость.

NarrativeSession.configure_commute добавляет explorable_home=false; true скрывает старый HOME-экран и не связывает его Work/Journal, дорога/сигналы прежние. Main создаёт HomeExploration с offset(32,0,0), подключает домашние команды, маршрутизирует HOME-ввод и выбирает камеры. RUN_HANDOFF дополнен необязательным home_state: HomeState; неверный тип отвергается, обычная новая смена переносит тот же объект, технический reset не переносит. AnchorCamera добавляет `apply_preferences() -> void` для домашней камеры без повторных подключений UI. JournalPanel текст возврата домой теперь «Вернуться домой». Потребители: Main/Session/Home*, JournalPanel, commute/playthrough/home tests, check.ps1. Решение ADR-0018, инструкция HOME.md. DA-049 не добавляла сохранений/затрат времени/канонических событий; DA-032 сохраняет HomeState по контракту ниже.

## Горизонт камеры — исправлено, DA-050

DA-050 уточняет реализацию AnchorCamera без новых API: rig.global_transform сохраняет позу якоря, но view.global_basis строится из мирового yaw и отдельного pitch. Начальные yaw/pitch извлекаются из направления якоря при configure/переходе, R возвращает их; обзор ограничивает суммарный вертикальный угол ±65° относительно мира. У view.rotation могут быть локальные компенсации наклонённого родителя: для проверки горизонта использовать global_basis.x.dot(Vector3.UP), а не локальный Z Euler. Барные ненаклонённые якоря совместимы. Потребители проверены navigation/environment_camera/home/camera_horizon и полным циклом.

## Как менять контракт

Указать задачу, статус (`proposed` / `implemented`), фактический путь реализации, затронутые системы, совместимость данных и проверку потребителей. Реализованные разделы обязательны для потребителей; предложения принимаются соответствующей задачей. Если реализация отличается, документ обновляется в том же изменении.

## DA-032: checkpoint v1

Journal добавляет `export_progress() -> Dictionary` и `restore_progress(data: Dictionary) -> bool`. Restore допустим только для настроенной пустой модели, проверяет весь набор до применения, не испускает сигналы, сохраняет порядок/источник/read/bookmark/курсор/selected. HomeState предоставляет те же методы для пустой модели observed/resolved и проверяет зависимости событий. Возвращаемые данные независимы от модели.

CheckpointCodec (RefCounted): `content_hash(catalog) -> String`, `encode(number, journal, home, catalog) -> Dictionary`, `decode(data: Variant, catalog) -> Dictionary`, `last_error: String`. Decode возвращает новые journal/home_state, shift и saved_at_utc либо пустой Dictionary без изменения живых моделей. Версия/отпечаток/границы/источники проверяются целиком.

CheckpointStore (RefCounted): конструктор `directory: String="user://checkpoints"`, только внутри user://; `get_path() -> String`, `has_checkpoint() -> bool`, `load_checkpoint(catalog) -> Dictionary`, `save_checkpoint(number,journal,home,catalog) -> bool`, `clear_checkpoint() -> bool`, last_error/recovered_backup для чтения. Ограничение 1 МиБ, предыдущая исправная копия, последовательная запись без параллельных писателей. Схема и отказоустойчивость — SAVES/ADR-0019.

Main экспортирует `checkpoint_enabled: bool=true`, принимает `checkpoint_store: CheckpointStore` до добавления в дерево. Тесты/превью отключают checkpoint; новые интеграционные тесты подставляют отдельный каталог. RUN_HANDOFF теперь передаёт также checkpoint_enabled/checkpoint_store/fresh; fresh=true пропускает автозагрузку после явного сброса. Обычная передача Journal/HomeState приоритетна; запись выполняется только после полной настройки новой смены. Старые данные передачи без новых полей по-прежнему допускаются.

NavigationHUD добавляет `new_game_requested`, `set_checkpoint_status(text: String) -> void`, уникальные CheckpointStatus/NewGame/ConfirmNewGame. Подтверждение скрывается при закрытии меню; Main отвергает устаревший запрос вне MENU. Потребители: Main, Journal, HomeState, HUD, checkpoint_test, все Main-fixtures прежних тестов и команды снимков, check.ps1/check_windows_export.ps1. Форматы контента v1 и публичные API прежних действий не изменены.

## DA-052: ходьба и рабочие места

FreeRoamCamera extends AnchorCamera, отдельные scripts/player и scenes/player. До configure задаются `free_roam_enabled: bool=false` и `focus_anchor_ids: PackedStringArray=[]` (пусто — все); в игровом Main default true, список [counter], дома true/все. Публичные `body: CharacterBody3D`, `focus_active: bool` — для чтения, `walk_speed=2.6`, `focus_distance=1.35` — параметры первоначального плейтеста. Сигнал `availability_changed` требует обновить доступность/локальный UI.

При включённой ходьбе `current_anchor_id` пуст вне рабочего места; `can_move_to/request_move` означают локальное занятие рабочего места, проверяют controls/transition/focus/ID/радиус/преграду, не neighbours. `try_focus() -> bool` дополнительно выбирает ближайшее место в направлении взгляда, `leave_focus() -> bool` возвращает к телу/прежнему взгляду только из немодального состояния после fade. Прежние transition_started/anchor_reached сохраняются при входе; при выходе обновление через availability_changed. Старый режим false использует все прежние контракты AnchorCamera. configure создаёт дочерний top_level CharacterBody3D, не внешний singleton.

Main.free_roam_enabled по умолчанию true, передаётся через RUN_HANDOFF вместе с прежним checkpoint-контекстом; игровые клавиши anchor_1…4 отключены. HomeExploration.configure получает четвёртый необязательный free_roam: bool=false; прежние вызовы совместимы. Включённый режим требует занятого места для осмотров/события/выхода на работу; ходьба доступна только в HOME без осмотра. Main разрешает разговор/обслуживание только у counter после завершения входа.

NavigationHUD добавляет `update_workstation(rig: FreeRoamCamera, exploration: bool) -> void`, `leave_workstation_requested`, уникальные LeaveWorkstation/MovementHint. Направления и старый Bottom скрыты в ходьбе, Actions видны только у рабочего места, у дома свой условный Bottom. HUD/модели не задают положение физического тела. InputMap добавляет move_forward/back/left/right (W/S/A/D), mouse захвачен при активной ходьбе и освобождён в рабочих/модальных режимах и при потере фокуса.

Потребители: Main, HomeExploration, NavigationHUD, сцены Main/Home/HUD/player, StaticBody гостя на слое 3; прежние Main-fixtures/команды снимков явно задают free_roam_enabled=false для старых контрактов; free_roam_test и проверочный экспорт проходят настоящий новый цикл. Сохранения v1, Dialogue/Journal/HomeState/ShiftClock не менялись. Новое решение ADR-0020, инструкция FREE_ROAM.

## DA-053: речь NPC

DialogueBubblePanel extends DialoguePanel, новая сцена наследует прежнюю; поля bubble_enabled=false, characters_per_second=38, looking_at_speaker/edge_mode/selected_index для чтения. Main включает bubble_enabled при free_roam_enabled, иначе сохраняется прежнее render/set_open/focus_current. `configure_speaker(camera: Camera3D,speaker: Node3D) -> void` задаёт актуального говорящего до разговора. `is_line_complete() -> bool`, `reveal_text() -> void`, `can_answer() -> bool`, `select_relative(direction: int) -> bool` (-1/+1), `submit_choice(index: int) -> bool` (с 0), `confirm() -> bool` проверяют текущую реплику/экран/взгляд/набор; confirm во время набора только раскрывает текст. UI испускает прежние choice_requested/finish_requested/cancel_requested/journal_requested, модельный Session API не блокируется ожиданием UI-анимации.

Ключ реплики dialogue_id:node_id не пересоздаёт набор при повторном render той же реплики и при меню/дневнике. Закрытие завершённого Runner сбрасывает ключ для следующего разговора. Позиция привязана к ServiceGuest.global_position + высота; проекция/behind/луч окружения определяют пузырёк/угол, ответы требуют взгляда в конусе 20°. Поле выбора скрыто до набора, при отвороте/преграде/потере говорящего. Ранние цифры/недоступные варианты/echo/скрытый UI не дают ответ. Колесо пропускает закрытые варианты, F подтверждает, Backspace отменяет. Новые %VoiceBubble/VoiceText/VoiceReplies/VoiceChoices/VoiceHint и вспомогательные узлы принадлежат новой сцене.

FreeRoamCamera добавляет `set_dialogue_look(enabled: bool) -> void`: обзор при DIALOGUE независимо от controls_enabled, но без движения тела/выхода с места. Main выключает его для всех других режимов; обычное рабочее место сохраняет фиксированную камеру. Mouse/стрелки допускаются только при активном окне.

DialogueText (RefCounted): статические `plain(text: String) -> String`, `write(label: RichTextLabel,text: String) -> void`; парные ** дают только bold через push_bold/add_text, прочий текст буквальный. CheckpointCodec.content_hash нормализует только node.text через plain: форматирование совместимо с прежним отпечатком, содержательные изменения нет. Потребители: Main, FreeRoamCamera, новая UI-сцена/панель, TEST-JSON, CheckpointCodec, dialogue_bubble_test, check.ps1/check_windows_export.ps1. JSON v1/Runner/Session/Journal API прежние; жирное не выдаёт новые эффекты. ADR-0021/DIALOGUE_BUBBLES описывают границы.

## DA-054: продолжения речи

DialogueBubblePanel.is_line_complete теперь означает завершение набора текущего пузырька, `is_speech_complete() -> bool` — последнего пузырька всей реплики. `get_page_count/get_page_index() -> int` (индекс с 0), `advance_page() -> bool`: только видимый активный экран, текущий текст набран, есть продолжение. reveal_text раскрывает только текущий фрагмент; confirm сначала раскрывает, затем продолжает, и только на последнем допускает ответ/finish. can_answer использует is_speech_complete. Повторный render того же node и скрытие меню/книгой сохраняют индекс/набор. %VoicePage — счётчик; VoiceText без scroll_active, PgUp/PgDn для речи удалены.

SpeechPaginator.paginate(text: String,regular: Font,bold: Font,font_size: int,area: Vector2) -> Array[Dictionary] возвращает start/end в plain-тексте и text с парным bold, literal=true для исходного текста с непарным **. Границы по TextParagraph, длинные слова переносятся адаптивно. DialogueText.styled_slice(text,start,length) -> String сохраняет bold на срезе; при literal=true страницу нужно выводить add_text напрямую. Эти данные — только UI, в checkpoint не входят. Потребители: DialogueBubblePanel, новая сцена/стили, dialogue_bubble_test; модели и JSON не меняются. ADR-0022/DIALOGUE_BUBBLES.

## DA-057: постоянные настройки

PresentationController, AnchorCamera, JournalPanel, DisplaySettings добавляют сигнал `preferences_changed` после принятых настроек; файл/контроллер им неизвестны. AnchorCamera.get_preferences() -> Dictionary возвращает sensitivity/transition. DisplaySettings.export_preferences() -> Dictionary — fullscreen/monitor/size/maximized; restore_preferences(data: Dictionary) -> bool принимает уже проверенный блок display, ограничивает монитор/размер, headless/embedded возвращает false. Внутренний кеш размера окна защищён от промежуточных размеров переключения fullscreen.

PreferenceStore (RefCounted): constructor directory="user://settings", get_path() -> String, defaults() -> Dictionary (static), validate(data: Variant) -> bool, load_preferences() -> Dictionary, save_preferences(data: Dictionary) -> bool; last_error для чтения. Версия 1, 16 КиБ, все поля проверяются перед применением, .tmp не загружается. Ошибка чтения/формата возвращает пустой Dictionary и не удаляет исходный файл. Числа целых полей после JSON нормализуются в int, данные возвращаются независимой копией.

PreferenceController (Node) configure(store,art,camera,book,display,hud,enabled,load_from_disk=true) -> void вызывать один раз после configure_controls модулей; reset_preferences() -> void и flush() -> bool. Снимок/запись через 0,35 с, ошибка повторяется с интервалом 5 с; flush сохраняет последние значения перед выходом/сменой. UI-кнопка сброса работает только в открытом меню; программный reset явный. %PreferenceStatus/%ResetPreferences принадлежат NavigationHUD. Прогресс не сбрасывается.

Main.preferences_enabled=true, preference_store: PreferenceStore подставляется до add_child. RUN_HANDOFF дополнен preferences_enabled/preference_store; проверяет типы, переносит даже отключённый режим тестов. При handoff сохраняются текущие параметры без повторного применения дисплея с диска. Старый handoff без полей совместим с прежним путём запуска.

Потребители: Main, перечисленные четыре модуля/HUD, все Main-fixtures/команды снимков, preference_test, check.ps1/check_windows_export.ps1. TEST-внешность, речь, Runner/Session/Journal/HomeState и checkpoint v1 не изменены. PLAYER_SETTINGS/ADR-0023.

## DA-058: цели мира

Interactable3D добавляет `get_unavailable_prompt() -> String` (по умолчанию пусто). InteractionController: `register_surface(body: CollisionObject3D,target: Interactable3D) -> bool` хранит WeakRef к цели, null отклоняется; `get_target() -> Interactable3D` обновляет луч, может вернуть недоступную поверхность ради пояснения; `pointer_mode: bool=false` переключает центр/курсор. try_interact теперь обновляет запрос перед activate. activate сохраняет прямой API с проверкой enabled/target/is_available. Курсор берётся из событий viewport, кеш сбрасывается при смене режима/размера; не пересчитывать event.position как физические пиксели. Луч по-прежнему маска 3/ближайшее препятствие, default reach=15 для старых потребителей, Main free-roam задаёт 3 м.

WorkstationTarget extends Interactable3D: available: bool, prompt/blocked_prompt: String; activated без аргументов. Main связывает три физических Body стойки, регулирует действие «открыть рабочее место»/«выбрать напиток» и проверяет контекст/расстояние. Несуществующая коллизия — явная ошибка настройки. Main запускает свободный разговор в exploration при близости NPC <=3 м/прямой видимости; required_anchor остаётся обязательным только в legacy. Камера/тело не перемещаются при таком старте, обзор/блокировки DIALOGUE прежние.

DialogueTrigger.show_marker: bool=true отделяет маркер от доступности. Main в free-roam выключает его и все барные AnchorPoint-метки; ServiceGuest collider покрывает голову/тело, физическое препятствие прежнее. NavigationHUD показывает E-подсказку рядом с курсором на занятом месте, по центру при ходьбе; Actions остаются локальными. Потребители: Main, InteractionController/Interactable3D/DialogueTrigger, WorkstationTarget, guest-сцена, HUD, free_roam_test/world_target_test, check.ps1/export. Home/Runner/Session/Journal/сохранения/настройки прежние. WORLD_INTERACTION/ADR-0024.

## DA-059: задняя стойка и движение в разговоре

[ADR-0025](decisions/0025-backbar-walking-dialogue.md) заменяет прежнюю блокировку тела DIALOGUE и привязку переднего прилавка. Публичные методы не менялись; меняется поведенческий контракт Main в free_roam_enabled=true: controls_enabled в exploration/dialogue, взаимодействия мира пока только exploration. При входе в dialogue из focus Main вызывает leave_focus, освобождая тело и возвращая прежний взгляд. Menu/Journal по-прежнему блокируют движение; при возврате к dialogue ходьба возобновляется. Speech/Runner/страница/эффекты не перезапускаются из-за движения, конец не телепортирует игрока.

Main добавляет независимую scenes/levels/back_counter.tscn и AnchorPoint back_counter по дочернему WorkPosition перед configure камеры. Только back_counter в focus_anchor_ids текущего бара. Физические привязки: BackCounter/{Top,Cabinet}/Body и BarLevel/Geometry/{ShelfBack,ShelfUpper,ShelfLower}/Body. CounterTop/Base/Trim не интерактивны. Отсутствие обязательного Body — ошибка настройки. Старый counter/граф и legacy fixtures остаются прежними; Home не меняется.

Потребители: Main, NavigationHUD, back_counter.tscn, world_target_test/free_roam_test/dialogue_bubble_test; check.ps1/Windows Validation уже включают их. Session/Runner/GuestService, сохранения и настройки прежние. Программные service API и UI пока разрешают подачу только exploration у back_counter (legacy: required_anchor). Готовить параллельно разговору будет DA-060 с отдельным решением, сейчас не обещать такую возможность.

## DA-081: перенос напитка

ServicePanel.preparation_stager: Callable(DrinkPreparation)->bool перехватывает завершение; успех вызывает DrinkWorkbench.mark_world_staged(), блокирует редактирование/повтор. Без callback прежний preparation_requested сохранён. world_output меняет подпись на «Завершить напиток».

NarrativeSession.can_stage_preparation()->bool проверяет готовность сервиса/время/режим без подачи. DrinkCarry.configure(camera, session, root), stage(preparation)->bool, pick_up()->bool, place()->bool, consume()->void; changed обновляет навигацию. Одна незапечатанная порция принадлежит переносчику до serve_preparation. ServiceGuest.carry_mode/carry_delivery заменяют разговор подачей только при доступном сервисе. Потребители: Main, ServicePanel, DrinkWorkbench, ServiceGuest, DialogueBubblePanel; проверки drink_carry/release_integration/legacy workbench.

## DA-082: мышь при ответах

ЛКМ при захваченном обзоре вызывает confirm и сохраняет захват мыши до смены режима выбора. Клик по фону при открытых ответах возвращает камеру без подтверждения. Автоматический курсор подавлен до новой реплики или отведения взгляда; E и наведение/клик по строкам сохраняются. Потребители: DialogueBubblePanel, FreeRoamCamera; публичные API не менялись.
