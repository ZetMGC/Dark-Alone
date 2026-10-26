# Контракты интеграции

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

Q-05 принят владельцем: по умолчанию 2 деления, Main.shift_budget экспортируется для тестового баланса. Новый режим shift_complete блокирует мир. Из него разрешён дневник с возвратом к итогам и меню с тем же возвратом. ShiftSummaryPanel сигналит restart_requested/journal_requested/quit_requested. Main.restart_shift() -> bool допускает перезагрузку только законченной текущей сцены, повторный запрос блокируется. При прямом тестовом сбросе все модели создаются заново; обычный возврат DA-033 сохраняет Journal (описано ниже). Дисковых сохранений нет.

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

Обычный возврат из дома переносит Journal и number+1 через одноразовый SceneTree metadata dark_alone_journal_handoff (scene/journal/shift). Main проверяет точный scene_file_path/типы, потребляет передачу, Session проверяет каталог. Отказ настройки не маскируется пустым дневником; при отказе reload временная передача удаляется. Прямой Main.restart_shift по-прежнему полностью сбрасывает знания. Дисковые сохранения отсутствуют, UI/Runner/часы/заказ создаются заново; это не autoload и не общая шина событий.

NavigationHUD.update_narrative получает четвёртый необязательный unread: int=0; update_shift — третий number: int=0 (положительный задаёт номер, ноль сохраняет текущий). Main передаёт начальный номер и непрочитанные записи. При фокусе LineEdit Main не забирает игровые буквы, Escape работает. Затронуты Journal/Runner/Session/Main, JournalPanel/HUD/Commute/Summary и тесты/превью. Решение — ADR-0010, инструкция — JOURNAL_CORE. Книга/страницы/анимации реализованы DA-034 ниже; схема save ещё не принята.

## Книга — implemented, DA-034

Journal добавляет `reading_offset: int=0` к каждой записи; `set_reading_offset(term_id: StringName, offset: int) -> bool`, сигнал `reading_position_changed(term_id: StringName)`. Допустимы известный ID и смещение 0…description.length() включительно; дубликат/вложенный вызов отклоняется. Смещение — позиция символа исходной строки, не байт и не номер страницы. Оно переносится с тем же Journal между обычными сменами.

BookPaginator (RefCounted): статические `paginate(text: String,font: Font,font_size: int,area: Vector2) -> Array[Dictionary]` возвращает непрерывные диапазоны `{start,end,text}`; `page_for_offset(pages: Array[Dictionary],offset: int) -> int` выбирает содержащую позицию страницу. Пустой текст даёт одну страницу; EOF относится к последней. Это чистое представление, модель не меняется.

JournalPanel сохраняет прежнюю сигнатуру render. Новые сигналы `opened`, `close_completed`, `reading_position_requested(term_id: StringName,offset: int)`; методы `request_page(direction: int) -> bool` (только -1/1), `begin_close() -> bool`, `force_closed() -> void`, `is_transitioning/is_closing() -> bool`, `get_page_count/get_page_index() -> int` (индекс с 0). `set_open(false)` скрывает/приостанавливает, `force_closed` отменяет/сбрасывает. Чтение выставляет Session после opened или завершённого выбора, render не меняет Journal. Во время анимации выбор/закладки/повторное листание блокируются; закрытие отменяет незавершённый переход.

Session добавляет `set_journal_reading_position(term_id: StringName,offset: int) -> bool`, допустимый только в journal для выбранного ID вне анимации; `request_close_journal() -> bool` запускает закрытие, до конца сохраняет режим journal. Прежний `close_journal() -> bool` синхронно отменяет анимации/закрывает панель и возвращает прежний режим. Main и пользовательская кнопка используют request_close_journal; close_completed вызывает close_journal. Меню скрывает и приостанавливает книгу.

JournalPanel.configure_controls(hud: NavigationHUD) связывает `%BookMotion` (OptionButton full/reduced/off), `%PageVolume` (HSlider), `%PageVolumeLabel`. Методы `set_motion_mode(value: StringName) -> bool`, `set_page_volume(value: float) -> void`: неизвестный режим/нечисловая громкость отклоняются; громкость ограничивается 0…1, ноль останавливает звук. Static motion_mode/page_volume — только предпочтения процесса. Смена режима во время скрытого действия завершает его один раз при возврате. Потребители изменений: Main/Session/JournalPanel, HUD, book_test, journal_core_test, playthrough и инструменты снимков. Старые изолированные проверки используют off, сквозной цикл — полные анимации. JSON/эффекты/часы/Runner не менялись. Решение — ADR-0011, инструкция — JOURNAL_BOOK.

## Экран — implemented, DA-037

DisplaySettings (`scripts/presentation/display_settings.gd`, отдельный Node в Main): `configure_controls(hud: NavigationHUD) -> void`, `is_fullscreen() -> bool`, `set_fullscreen(enabled: bool) -> bool`, `set_monitor(index: int) -> bool`. Смена режима/монитора возвращает false для headless/встроенного окна, повторного значения или неизвестного экрана. Fullscreen использует Window.MODE_FULLSCREEN/native разрешение; возврат восстанавливает окно/развёрнутый режим с ограничением рабочей областью. F11 обрабатывается в контроллере, echo игнорируется; игровые модели/время не меняются. Static-поля содержат только предпочтения окна до закрытия процесса.

NavigationHUD предоставляет `%DisplayMode` (OptionButton: 0 окно, 1 fullscreen), `%DisplayMonitor` (индекс фактического экрана); Main вызывает configure_controls после прочих настроек. Настройки меню помещены в ScrollContainer, `%Resume`/`%Quit` остаются вне него; прежние уникальные имена сохранены. Список/выбор обновляются раз в секунду и по size_changed. `project.godot`: canvas_items/expand от 1280×720, минимум 960×600. Потребители — Main/HUD, display_test, старые проверки и инструменты снимков. Решение — ADR-0012, инструкция — DISPLAY.

## Как менять контракт

Указать задачу, статус (`proposed` / `implemented`), фактический путь реализации, затронутые системы, совместимость данных и проверку потребителей. Реализованные разделы обязательны для потребителей; предложения принимаются соответствующей задачей. Если реализация отличается, документ обновляется в том же изменении.
