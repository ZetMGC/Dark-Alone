# DA-060: изменённые контракты и потребители

Локальное дополнение к общему CONTRACTS, которое сводит координатор при интеграции. Решение — DECISIONS.md в этой папке. Домашние файлы и API не меняются.

## NarrativeSession

concurrent_service_enabled: bool=false — opt-in, Main задаёт free_roam_enabled до configure. Legacy по умолчанию прежний. `can_open_service() -> bool` — запрос доступности по режиму/configuration/served/времени, без мутации; намеренно не зависит от _changing, чтобы UI внутри mode_changed видел итоговую доступность. Команда open_service дополнительно проверяет _changing.

При opt-in open_service допускает DIALOGUE и сохраняет _service_return, не меняя Runner. close_service и успешная serve_drink возвращают в сохранённый режим. SERVICE с активным Runner показывает пассивный пузырёк и продолжает набор. Menu/Journal скрывают оба экрана, возвращают точный прежний контекст; open_journal допускает SERVICE только при opt-in, ключ/страница/выбор речи не сбрасываются. choose_for_node/finish_for_node/cancel_dialogue по-прежнему принимают только DIALOGUE, в SERVICE отклоняются.

При активном Runner и готовых часах _has_service_time требует >=2 делений, иначе open_service/serve_drink отклоняются; проверка перед фактической подачей повторная. Вне разговора можно использовать последнее деление. Стоимости и ShiftClock API/схема прежние. Нулевое время не создаётся подачей посреди незавершённой реплики. configure_commute, режимы HOME/TRAVEL/Journal/Menu, сигналы и формат checkpoint не изменены.

## Main и представления

Main при free-roam разрешает E по back_counter в EXPLORATION/DIALOGUE; NPC остаётся целью начала только EXPLORATION. SERVICE и прочие модальные экраны блокируют мир. В DIALOGUE фокус оставляет неподвижную камеру и курсор; первый Escape из выбора закрывает его, второй из фокуса отходит, свободный Escape открывает меню. Автоматический выход из фокуса выполняется только при успешном первоначальном _start_dialogue, а не при каждом возврате в DIALOGUE. Начало/подача/выход сохраняют Runner и физическое тело.

DialogueBubblePanel: `set_response_input_enabled(enabled: bool) -> void` блокирует UI confirm/reveal_text/advance_page/select_relative/submit_choice и перехват F/цифр/колеса/Backspace, не останавливая набор. `set_service_overlay(enabled: bool) -> void` скрывает нижнюю подсказку, чтобы не накладывать её на выбор напитка. can_answer учитывает разрешение ввода. Main выключает ввод у фокуса/в SERVICE/пауза; разрешает при свободном DIALOGUE. Публичные методы сохранили сигнатуры; модельные команды по-прежнему не зависят от анимации.

ServicePanel: `set_conversation_context(active: bool) -> void` выбирает компактную нижнюю правую карточку без Shade при активном Runner, иначе прежнее полное меню. В компактном варианте показаны кнопки без отдельных описаний/разделителей, описания доступны как tooltip; оба TEST-напитка помещаются без прокрутки. Это только отображение; истинное состояние живёт в Session. `NavigationHUD.update_workstation(rig, exploration, dialogue: bool=false)` добавляет необязательный флаг для подсказок/видимости при разговоре, старые вызовы совместимы. Screen/Menu, используемые домом, сохраняются. FreeRoamCamera не изменялась.

Потребители: scripts/main/main.gd, scripts/session/narrative_session.gd, scripts/ui/{dialogue_bubble_panel,service_panel,navigation_hud}.gd; новый bar_service_dialogue_test и wrapper check_bar_service.ps1; тематические документы. Существующие тесты моделей/всего цикла остаются отдельной регрессией. Общие check.ps1/export runner намеренно не меняются в параллельном раунде; новый тест подключит координатор.
