# 2026-10-27: DA-057 — постоянные настройки игрока

Исполнитель: агент DA-057. Ветка codex/da057-persistent-settings, база main 1b748d3.

## Выполнено

Владелец ответил «Сюжет позже — продолжим технические механики». Q-04 отложена, канон/персонажи не добавлялись. Следующей технической задачей агент выбрал известное ограничение настроек только в памяти. На старте рабочая копия чистая, общую HUD-сцену редактировал один агент; активных других владельцев этой сцены в BACKLOG нет.

PreferenceStore валидирует отдельный JSON v1, ограничивает размер, пишет через временный файл/переименование. PreferenceController собирает предпочтения звука/изображения/камеры/книги/экрана, сохраняет после короткой паузы и при выходе/смене. Плохой файл не блокирует игру, ошибка видна; независимый сброс настроек в меню. Новый старт игры сохраняет предпочтения. Дисплей проверяет доступные индексы/рабочую область, нативные размер/разворачивание и F11; handoff не применяет окно повторно и не меняет его позицию.

Тестовые Main/снимки отключают реальные предпочтения; новый набор и процессы используют только user://preference_tests/. Прогресс/checkpoint v1/контент/внешность/речь не менялись.

Изменены: scripts/settings/preference_store.gd и preference_controller.gd с UID, scripts/main/main.gd, scripts/player/anchor_camera.gd, scripts/presentation/presentation_controller.gd и display_settings.gd, scripts/ui/journal_panel.gd, scenes/ui/navigation_hud.tscn; tests/preference_test.gd/.uid/.tscn, tests/playthrough_test.gd, прежние Main-fixtures, tools/check.ps1/check_windows_export.ps1 и capture_* с Main. Документы: README/STATUS/HANDOFF/BACKLOG/CONCEPT/ARCHITECTURE/CONTRACTS/DISPLAY/SAVES/PLAYTEST/TESTING/BUILD, PLAYER_SETTINGS, task DA-057, ADR-0023 и индексы. Новых ассетов/зависимостей нет.

## Проверки

Windows, Godot 4.7.2.stable.official.ed1daf0bf, Compatibility/RTX 5060.

| Команда / сценарий | Фактический результат |
| --- | --- |
| check.ps1 после первой интеграции | PASS прежних наборов, artifacts/da057-regression.log |
| preference_test headless | PASS 29/0, artifacts/da057-preferences.log |
| Два отдельных исходных процесса --preference-probe=write/read | PASS 2/3, новый Main применил значения с диска |
| GPU со снимком меню | PASS 33/0 до проверки нативного maximize, artifacts/da057-preferences-graphics.log; меню просмотрено |
| Итоговый GPU с native maximize/F11 | PASS 33/0 без снимка, artifacts/da057-preferences-final-graphics.log |

Итоговый код: `3710d8c43ed43574c830d527ea0e731e4d7ee3a0`.

- Полный check.ps1 из чистого Git archive ce332b0 PASS, включая настройки 29, процессы 2/3, все прежние наборы; artifacts/da057-clean-source.log. После него добавлена только защита reset в отключённом режиме и её проверка. Последний 3710d8c отдельно импортирован из чистого Git archive и прошёл настройки 30/0: artifacts/da057-final-clean.log.
- build_windows.ps1 PASS: builds/windows-20261027-141127-0e5c42b7.zip, manifest source_dirty=false, artifacts/da057-final-build.log. Промежуточный ce332b0-билд не итоговый.
- check_windows_export.ps1 -BuildDirectory builds/windows-20261027-141127-0e5c42b7 -Graphics PASS. Настройки 30 headless/34 GPU, процессы write/read 2/3 и отдельный графический read 4 с восстановлением fullscreen. Прежние речь 107/109, пеший цикл 63/64, checkpoint 51/53, процессы checkpoint 2/5, цикл 50, книга 51, экран 46, лица 22/38, детализация 18 — PASS. artifacts/da057-export.log, builds/validation-e7c7936756654d4fb706c5c44a5af734.
- ZIP распакован отдельно: SHA256 файлов manifest совпали, извлечённый EXE запущен без редактора и ошибок. git diff --check и ссылки новых документов PASS.

Архив локальный/игнорируется Git, ветка отправляется отдельно от main. После 3710d8c меняются только документы результатов. Новый GitHub-релиз не опубликован.

## Решения и ограничения

[ADR-0023](../decisions/0023-persistent-preferences.md), [PLAYER_SETTINGS](../PLAYER_SETTINGS.md), [CONTRACTS](../CONTRACTS.md). Файл отделён от checkpoint; backup/облака/миграций/блокировки нескольких писателей нет. Монитор определяется индексом, недоступность проверена подстановкой 255; физическое отключение второго монитора/другая машина не проверены. Окно в новом процессе вписывается/центрируется, позиция только в памяти. TEST-лицо и параметры речи не сохраняются. Сам запуск плохой файл не перезаписывает; следующее пользовательское изменение может заменить его. M3 целиком не закрыт, история остаётся TEST.

## Продолжение

Пользователю изменить звук/камеру/окно/книгу, закрыть и запустить заново, проверить меню, затем независимые «Сбросить настройки» и «Начать заново». Коллегам: читать PLAYER_SETTINGS, изолировать новые Main-fixtures preferences_enabled=false или тестовым Store, выполнять check.ps1/экспорт -Graphics. STATUS/BACKLOG/HANDOFF обновлены; техническая задача done. Сюжет/новые записи/реалистичные лица не возобновлять без поручения. Слияния/релиза в этой задаче нет.
