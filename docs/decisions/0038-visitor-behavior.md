# ADR-0038: локальный цикл поведения посетителя

CHAR-10, 2026-10-28: по отзыву о конфликтующих анимациях введён приоритет ходьба/отход → глоток → разговор/покой. Внутри VisitorModel цепочки рук смешиваются по quaternion-позам; frame начинается с reset_bone_poses. Геометрия/скелет и публичные поля прежние, изменения локальны для presentation. VisitorBehavior уточняет цель кисти при глотке. Потребители: прежние GuestArt/VisitorBehavior, visitor_behavior_test; старый behavior_enabled=false проверяет visitor_model_test. Меш не получает физическую самоколлизию.

CHAR-08, 2026-10-28: по новому поручению автоматический уход отвязан от dialogue_finished. VisitorBehavior ждёт session.shift.finished + неактивный Runner + законченный глоток. Конец отдельной ветки/отмена не запускает уход. Явный request_departure остаётся техническим API для теста/авторского сценария. Контракт Session/Runner/сохранений прежний. [Протокол](../worklog/2026-10-28-14-npc-animation-polish.md).

2026-10-28. Принято по прямому поручению участника: ходьба, реакции, взгляд, слушание и напиток.

VisitorBehavior — отдельный Node, создаётся Main при visitor_behavior_enabled. Включён только в текущем reasoning_demo. configure(guest: ServiceGuest, camera: Camera3D, session: NarrativeSession) запускает приход; start_visit() повторяет маршрут, request_departure() ждёт завершения диалога/глотка. Публичный state — arriving/settling/docked/releasing/leaving/absent. Новые сюжеты и причины ухода не вводятся.

ServiceGuest добавляет signal drink_presented, испускаемый после show_served/show_prepared. motion_available ограничивает is_available/interact во время движения; Session по-прежнему владеет заказом и эффектами. Стакан не масштабируется и не меняет объём после визуального глотка.

VisitorModel добавляет behavior_enabled, walk_speed/travel_distance/support_weight, attention/look_target, drink_weight/drink_target, react(kind: StringName), hand_transform()->Transform3D. Контроллер задаёт цели, модель сглаживает взгляд и решает цепочки костей; фаза шага зависит от расстояния. Старые talking/speaking/begin_line и неподвижная поза при behavior_enabled=false сохранены.

Реакции на конкретные узлы хранятся в презентационном TEST-сопоставлении, схема DialogueCatalog/сохранений не меняется. Для расширения на других NPC нужен авторский набор сопоставлений. Маршрут ограничен текущим залом и останавливается перед препятствием, не строит обход. Уход начинается по dialogue_finished, не dialogue_cancelled; стакан возвращается до ухода.

Потребители: Main/reasoning_demo, ServiceGuest, VisitorModel, VisitorBehavior, visitor_behavior_test; старые visitor_model/free_roam/world/dialogue/service проверки остаются в check.ps1.
