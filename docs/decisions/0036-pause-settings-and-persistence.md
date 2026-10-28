# ADR-0036: Короткая пауза и постоянные настройки основного запуска

Статус: принято, 2026-10-28, прямое поручение владельца.

DA-074: выключенный preferences_enabled в отдельной demo-сцене стал ошибкой после назначения её основной. Включаем его обратно, прежний PreferenceStore и файл сохраняются без сброса. Игровой checkpoint TEST-сцены остаётся отключённым. Esc показывает короткую pause-страницу; настройки на отдельной странице с Back/Esc назад, затем resume. Контролы остаются по прежним путям для Presentation/Camera/Book/Display/PreferenceController. show_settings(bool)/close_settings()->bool реализует HUD, Main даёт Esc settings приоритет над resume. Тесты привязывают отдельный Store, реальные параметры не трогают. [Контракт](../PLAYER_SETTINGS.md).

[Проверки/передача](../worklog/2026-10-28-09-speech-shaker-settings.md).
