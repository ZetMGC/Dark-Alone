# Контракты интеграции

**Статус:** якоря и взаимодействие реализованы в M1; формат, каталог и валидатор контента — в DA-020. Исполнитель диалогов, дневник и применение эффектов ещё не реализованы. Не считать интерфейсы будущих модулей существующим API.

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

## Исполнитель диалогов — proposed, DA-021

```gdscript
func start(dialogue_id: StringName) -> bool
func choose(choice_id: StringName) -> bool
signal node_changed(dialogue_id: StringName, node_id: StringName)
signal dialogue_finished(dialogue_id: StringName)
```

Формат JSON v1 уже принят: разговор с ID и start_node; узел с ID, speaker, text, end, choices и effects; выбор с ID, text, target, required_terms. Подробности — DIALOGUE_CONTENT. Терминальная нода явно завершается, а не ссылается на несуществующий ID. Использовать стабильные ID выбора, не индекс кнопки.

Статические проверки уникальности ID, ссылок, достижимости, пути к завершению и намеренности циклов выполняет DA-020. В DA-021 нужно проверять доступность ответа в текущем состоянии и предотвращать повторное применение grant_term. UI читает представление узла через согласованный метод/модель, не меняет каталог напрямую.

Невалидные данные возвращают отказ со списком ошибок до изменения игрового состояния. Завершение диалога испускается один раз. Правила отмены и повторного разговора принимаются до DA-023.

## Дневник — предложение для DA-021

```gdscript
func add_term(term_id: StringName) -> bool
func has_term(term_id: StringName) -> bool
signal term_added(term_id: StringName)
```

`add_term` возвращает `true` только при первом добавлении известного ID. Дубликат — `false` без события, неизвестный ID — отказ с диагностикой. Запись словаря содержит ID, название и описание. Видимый список берётся из модели, а не из текста кнопок. Порядок отображения принять в задаче.

## Время и эффекты — предложение для DA-023

`apply_completed_event(event_id: StringName, time_cost: int) -> bool` у координатора. ID относится к уникальному событию текущего прохождения, не только к типу диалога. Повторный ID не расходует время; отрицательная стоимость недопустима; ноль допустим для тестового события. Время идёт от завершённых событий, не от секунд реального времени. Конкретные единицы и бюджет смены — Q-05.

Одноразовые эффекты (термин, изменение флага, время) не запускать из рендера UI. Согласовать порядок применения и защиту от частичного применения: сначала проверить все эффекты, затем изменить состояние. Событие окончания смены испускается ровно один раз.

## Как менять контракт

Указать задачу, статус (`proposed` / `implemented`), фактический путь реализации, затронутые системы, совместимость данных и проверку потребителей. Реализованные разделы обязательны для потребителей; предложения принимаются соответствующей задачей. Если реализация отличается, документ обновляется в том же изменении.
