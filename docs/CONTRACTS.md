# Контракты интеграции

**Статус:** навигация M1, контент/исполнение DA-020–DA-021 и гость/обслуживание DA-022 реализованы. Время и завершение смены ещё не реализованы. Не считать интерфейсы будущих модулей существующим API.

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
func configure(catalog: DialogueCatalog, journal: Journal) -> bool
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

Терминальный текст остаётся активным до finish. finish очищает текущее состояние и сигналит один раз; ID берётся из аргумента сигнала, не из уже очищенного current_dialogue_id. cancel очищает состояние с отдельным dialogue_cancelled, без dialogue_finished. Термины сохраняются; start после обоих исходов разрешён. Расход времени пока отсутствует.

## Дневник — implemented, DA-021

Реализация: [Journal](../scripts/journal/journal.gd), RefCounted.

```gdscript
func configure(catalog: DialogueCatalog) -> bool
func is_configured() -> bool
func add_term(term_id: StringName) -> bool
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

## Время и эффекты — предложение для DA-023

`apply_completed_event(event_id: StringName, time_cost: int) -> bool` у координатора. ID относится к уникальному событию текущего прохождения, не только к типу диалога. Повторный ID не расходует время; отрицательная стоимость недопустима; ноль допустим для тестового события. Время идёт от завершённых событий, не от секунд реального времени. Конкретные единицы и бюджет смены — Q-05.

Одноразовые эффекты (термин, изменение флага, время) не запускать из рендера UI. Согласовать порядок применения и защиту от частичного применения: сначала проверить все эффекты, затем изменить состояние. Событие окончания смены испускается ровно один раз.

## Как менять контракт

Указать задачу, статус (`proposed` / `implemented`), фактический путь реализации, затронутые системы, совместимость данных и проверку потребителей. Реализованные разделы обязательны для потребителей; предложения принимаются соответствующей задачей. Если реализация отличается, документ обновляется в том же изменении.
