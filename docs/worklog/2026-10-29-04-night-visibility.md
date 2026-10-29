# 2026-10-29: BAR-NIGHT-02 — видимость левого зала и кладовки

Второй участник + Codex, codex/night-bar-atmosphere от f8bdf7f. По пользовательскому скриншоту слишком темно слева от бармена и в кладовке.

ReferenceBar: энергия кухонного спота 0.65 → 1.2, кладовки 0.25 → 1.4; увеличен радиус. Добавлены локальные OmniLight3D с тенями: LeftSeatingFill (0.85/4.3 м), StoreFill (0.7/2.5 м), ServicePassageFill (0.55/2.6 м). Они освещают боковые поверхности мебели/ящиков и пол между прежними световыми островками. Общий ambient 0.30, GuestFill, рабочий свет и звуковой профиль прежние. Публичные API/планировка не менялись.

GPU Godot 4.7.2 Compatibility/RTX4070/Dummy: reference_bar_test PASS 27/0, `.tools/night-bar-visibility-gpu.log`. Просмотрены seating/service_left/store. Добавлены два ракурса в существующий помощник съёмки; новых автоматических тестов на значения настроек нет. `git diff --check` PASS. Общий набор не повторялся: изменения ограничены локальными источниками света.

[Левая часть от бармена](../art/night-bar-left-visible.png), [кладовка](../art/night-bar-store-visible.png) — реальные GPU кадры. STATUS/HANDOFF/BACKLOG обновлены. Файлы: reference_bar.gd, reference_bar_test.gd, документация и два кадра. Прежние project.godot/test_materials.json сохранены вне задачи. Следующее: F5 и оценить видимость в игре на своём мониторе. Push/main/новый EXE не выполнялись.
