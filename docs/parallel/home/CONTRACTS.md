# DA-062: локальные контракты

Общие API не изменены. HomeExploration использует прежние configure/set_context/inspect/close_inspection/open_event/request_work/handle_input, state/rig и сигналы. Новый адаптер scripts/home/targets/home_surface_target.gd наследует Interactable3D без собственной Shape/слоя/monitoring. Его rig/object/context_allowed задаёт только HomeExploration; activated повторно проверяет доступность.

Дом вызывает существующий InteractionController.register_surface. Таблица SURFACES связывает реальные StaticBody3D Geometry/<имя>/Body:

| HomeObject | Части геометрии | Ракурс |
| --- | --- | --- |
| Desk | Desk, DeskLegLeft, DeskLegRight, Book | home_desk |
| Window | Window, WindowBar | home_window |
| Bed | BedFrame, Mattress, Pillow | home_bed |
| Door | Door | home_entry |

Отсутствующий предмет/якорь/Body даёт push_error и configure=false. Собственные сферы Objects и все AnchorPoint отключены на слое 2 только в free-roam; legacy доступность прежняя. Стены/пол/непривязанные тела остаются препятствиями. reach=3 м; вход дополнительно проверяет публичный can_move_to: 1,35 м до ракурса и отсутствие преграды до него. Действие издалека не телепортирует. Ближайший предмет выбирается лучом, ближайший якорь больше не является запасным выбором.

В ходьбе E по поверхности вызывает request_move её якоря. В фокусе pointer_mode=true, E по той же поверхности вызывает inspect; другой предмет не активируется. Подсказка следует за курсором; кнопка осмотра прежняя. Доступность проверяется заново при E и при выполнении адаптера: HOME/активная домашняя камера/нет fade или осмотра; Menu/Journal/Travel выключают взаимодействия. Escape/возврат к телу выполняет существующий leave_focus. Камера двери только для free-roam имеет yaw=180°, чтобы дверь была видна в локальном ракурсе; координаты и legacy поворот сохранены.

HomeState, журнал, события/условия, checkpoint v1, настройки, часы и бар не меняются. Потребители: HomeExploration, существующие HomeObject/FreeRoamCamera/InteractionController и новый home_target_test. Координатор переносит это описание в общие CONTRACTS при интеграции.

## HOME-02: интерьер и бытовые действия

HomeExploration.house: Node3D (только free-roam) создаётся из отдельной house_interior.tscn до configure камеры. Локальные методы house_actions_allowed() -> bool, show_house_inspection(title: String,text: String) -> void, house_feedback(text: String) -> void используются только HouseInterior; прежний API и потребители бара не меняются. HouseInterior.build(home), room_at(local_position), tick(delta,active,gain), словари actions/switches для домашней координации/проверок. План/координаты/композиция — HOUSE_PLAN.

HouseActionTarget использует Callable allowed/action/caption. Без собственной Shape/слоя, связан с реальным Body через register_surface. Доступность: активный HOME, нет осмотра/fade, активная домашняя камера, игрок вне фокуса и до основного предмета не более 2,5 м. Выбор — свежий ближайший луч; mode/distance повторно проверяются внутри interact. У сидений дополнительно rig.can_move_to (1,35 м/преграда), две позы seat_sofa/seat_diningchair. Они добавлены только в игровом режиме, без маркеров и цифровых переходов; не являются обязательными точками маршрута.

Новые осмотры используют прежний модальный экран, но не вызывают HomeState.observe/resolve_event. Оба выхода закрывают бытовой осмотр без отметки; J/меню сохраняют его контекст. Переключатели/дверцы/вода/чай — локальное состояние экземпляра. Нагрев 6 секунд только активного HOME, пауза/книга/осмотр замораживают. Радио учитывает существующий PresentationController.get_ambience_gain, останавливается в неактивном контексте/exit_tree; PCM loop_end содержит guard-отсчёт. Сдвижные двери перед закрытием проверяют пересечение нового положения с маской Player (4), не закрываются через капсулу.

Legacy free_roam=false оставляет исходную сцену/граф; остальные общие API и JSON checkpoint v1 прежние. Источники прогресса по-прежнему только четыре прежних объекта и прежнее TEST-событие. Потребители новых локальных API: HouseInterior, HomeExploration, house_layout_test; профильный runner запускает обе домашние сцены и legacy. Общие runner/реестры/Windows Validation сводит координатор.
