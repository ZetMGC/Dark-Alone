# JOURNAL-02: интерактивные пометки

DA-066 — текущий контракт поверх прежнего annotations: [JOURNAL_REASONING](../../JOURNAL_REASONING.md)/ADR-0029. Свободный текст/блоки/стрелки DA-065 отменены; known terms → closed stroke → authored conclusion, required_conclusions у ответов. Notebook — только legacy; новый progress optional conclusions с evidence. PaperPages.bind принимает Journal, Writer/TextEdit отсутствует. Прежние семантические пометки слов сохранены.

DA-065 (2026-10-28) расширяет и уточняет этот исторический контракт: [PERSONAL_JOURNAL](../../PERSONAL_JOURNAL.md), ADR-0028. Journal.notebook / опциональный notebook в progress; личные заметки/стрелки/рецепты теперь реализованы. Search/Section/Count/Matches/InkTool/InkUndo/InkRedo удалены из сцены, Close хранит контекст в tooltip_text; select_section/set_ink_tool заменяют управление. Ниже прежний контракт annotations остаётся действующим, прежние утверждения о сохранении поиска/отсутствии личного текста заменены DA-065.

Дата 2026-10-27, прямое поручение второго участника после визуального ориентира. Новые публичные методы Journal:

```gdscript
signal annotations_changed(term_id: StringName)
func get_annotations(term_id: StringName) -> Array
func add_annotation(term_id: StringName, kind: StringName, start: int, end: int) -> bool
func erase_annotation(term_id: StringName, index: int) -> bool
func can_undo_annotations(term_id: StringName) -> bool
func can_redo_annotations(term_id: StringName) -> bool
func undo_annotations(term_id: StringName, redo: bool = false) -> bool
```

Доступны только известные термины; вид underline/circle, диапазон [start,end) в символах исходного description. Отрицательные/пустые/выходящие за текст диапазоны, дубликаты и более 64 пометок на запись отклоняются. Getter — глубокая копия. Сигнал внутри общей защиты _mutating, вложенные изменения запрещены. Удаление по текущему индексу снимка; UI выбирает верхнюю подходящую пометку. История undo/redo до 32 изменений на запись в памяти; новая операция очищает redo. Новая игра/новый Journal не получает старых пометок.

Journal.export_progress сохраняет прежние entries/selected и добавляет **опциональный** annotations только при непустом наборе. Пример:

```json
{"annotations":{"test_signal":[{"kind":"underline","start":0,"end":6}]}}
```

restore_progress принимает прежние два ключа и три с annotations; неизвестные/лишние ключи и неверные диапазоны/типы/ID/дубли отклоняются атомарно до изменения модели. JSON-числа должны быть конечными целыми, после валидации нормализуются в int. Старые файлы без annotations совместимы. CheckpointCodec/Store/версия 1/отпечаток контента/граница записи не меняются: новый раздел проходит через прежние encode/decode и Journal.restore_progress. Старый исполняемый файл может не принять новую запись с пометками; обещается чтение старых данных новой версией, не обратная совместимость исполняемых файлов. История отмен не сохраняется.

JournalPanel.render/сигналы/публичный API Session прежние. Потребители нового API: JournalPanel, новый journal_ink_test; косвенные — CheckpointCodec/Store и перенос Journal следующей смены. Модель не хранит Control/пиксели/страницы/BBCode. UI команды повторно проверяют screen.visible, отсутствие анимации/ожидаемой пагинации и совпадение ID показанного текста с selected_term_id. Это исключает пометку старого текста после выбора другой записи. Search/Index/Bookmark и расходы времени прежние.

Description в journal_panel.tscn теперь Control со scripts/journal/journal_ink_text.gd, а не RichTextLabel. Сохраняются имя и theme-ключи normal_font/normal_font_size. set_content(page_text,source_start,entry_id), set_marks(Array), set_tool(StringName) и range_rects(start,end) — локальные методы представления; сигналы annotation_requested/erase_requested/selection_changed направляются Panel. Текст, hit-test и контуры используют одинаковую раскладку TextParagraph/TextServer. BookPaginator учитывает те же шрифт/отступы/ширину, а длинная обводка делится по строкам. Листание, resize и скрытие отменяют незавершённый drag. Инструменты имеют постоянную высоту во включённом/выключенном состоянии, чтобы анимация не меняла текстовую область.

Свободное рисование/собственный текст/досье/сюжетные связи и сохранение посреди смены не входят в этот контракт. Сверка API: [TextParagraph](https://docs.godotengine.org/en/stable/classes/class_textparagraph.html), [TextServer selection](https://docs.godotengine.org/en/stable/classes/class_textserver.html#class-textserver-method-shaped-text-get-selection). Общие реестры переносит координатор при интеграции.
