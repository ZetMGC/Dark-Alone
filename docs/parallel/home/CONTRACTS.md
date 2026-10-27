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
