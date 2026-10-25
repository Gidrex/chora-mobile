# ТЕХНИЧЕСКОЕ ЗАДАНИЕ (ТЗ) — `chora-mobile`

> **Инструкция для ИИ-агента / разработчика:**
> Этот документ написан максимально прямолинейно и пошагово. Не придумывай лишних абстракций, не меняй структуру папок `chora_dir` и строго следуй сигнатурам и пакетам, указанным ниже.

---

## 1. Обзор архитектуры

`chora-mobile` — это серверлесс (serverless) мобильное приложение под Android на **Flutter (Material 3)** с бэкендом на **Rust** (использующим оригинальную библиотеку `chora` из `../chora`) и встроенным бинарником **Syncthing** (`libsyncthing.so`), который синхронизирует **только** папку `chora_dir` между телефоном и ПК без облаков и без Git на телефоне.

### Структура хранилища `chora_dir` на телефоне:
По умолчанию: `/storage/emulated/0/Documents/chora` (либо внутренний app-dir `/data/user/0/dev.gidrex.chora_mobile/files/chora` — выбирается в настройках).
Внутри `chora_dir`:
- `index.md` — контекст и права доступа (`open`, `restricted`, `critical`) + `about` описания. Мобилка **только читает** `index.md` через `chora::index::Index::load(&root)`.
- `notes/<project>/.../*.md` — дерево markdown-заметок по проектам + свободные файлы `notes/*.md` (группа `(files)`).
- `to-agent/YYYY-MM-DD-<slug>.md` — задачи, делегированные ИИ-агенту с телефона (чтобы агент на ПК их разобрал).
- `events/YYYY-MM-DD.md` — события по дням (`## Заголовок`, `Time: HH:MM`, `Duration: 45m`, описание).
- `events/repeatable/<weekday>.md` — регулярные события по дням недели (`monday.md` .. `sunday.md`).
- `events/backlog/YYYY-MM-DD.md` — архив старых событий.
- `.stignore` — создаётся автоматически мобилкой для Syncthing (игнорирует `.git`, `sync.log`, `*.tmp`, `*.swp`).

---

## 2. Пошаговая инициализация проекта (через FVM)

> **ВАЖНО:** Проект использует **FVM** (Flutter Version Management). Никогда не вызывай голый `flutter` или `dart` — всегда используй `fvm flutter ...` и `fvm dart ...`. При работе с `flutter_rust_bridge_codegen` обязательно добавляй `.fvm/flutter_sdk/bin` в `PATH`, иначе кодогенератор упадёт с ошибкой `flutter: command not found`.

Выполнять команды строго по очереди в `/home/gidrex/Projects/chora-mobile`:

```bash
# 1. Зафиксировать версию Flutter в папке проекта (создаст .fvmrc и симлинк .fvm/flutter_sdk)
fvm use stable --force

# 2. Добавить .fvm/ в .gitignore (коммитить нужно только .fvmrc)
echo ".fvm/" >> .gitignore

# 3. Создать Flutter-проект (только Android) через FVM
fvm flutter create --org dev.gidrex --platforms android --project-name chora_mobile .

# 4. Установить генератор flutter_rust_bridge и инициализировать Rust-модуль
# (прокидываем PATH до FVM SDK, чтобы кодогенератор нашёл flutter и dart)
cargo install flutter_rust_bridge_codegen
PATH="$PWD/.fvm/flutter_sdk/bin:$PATH" flutter_rust_bridge_codegen create --rust-crate-dir rust --rust-crate-name chora_mobile_rust
```

Команда для регенерации бриджа после изменений в `rust/src/api.rs`:
```bash
PATH="$PWD/.fvm/flutter_sdk/bin:$PATH" flutter_rust_bridge_codegen generate
```

### 2.1. Зависимости Flutter (`pubspec.yaml`)
Добавить ровно эти пакеты:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_rust_bridge: ^2.7.0
  dynamic_color: ^1.7.0           # Системная палитра Material You (Monet)
  google_fonts: ^6.2.1            # Шрифты Onest, Golos Text, Martian Mono, IBM Plex Mono
  flutter_markdown: ^0.7.4        # Рендер Markdown с кликабельными чекбоксами
  local_auth: ^2.3.0              # Отпечаток пальца / биометрия Android
  flutter_secure_storage: ^9.2.2  # Хранение PIN-кода и API-ключа Syncthing
  shared_preferences: ^2.3.3      # Локальные настройки (скрытые проекты, шрифт, тема)
  flutter_local_notifications: ^18.0.1 # Напоминалки перед событиями
  android_intent_plus: ^5.2.0     # Вызов системного будильника Android (SET_ALARM)
  mobile_scanner: ^6.0.2          # Сканер QR-кода Device ID для Syncthing
  qr_flutter: ^4.1.0              # Генерация QR-кода своего Device ID
  http: ^1.2.2                    # Общение с локальным REST API Syncthing (127.0.0.1:8384)
  path_provider: ^2.1.5
```

### 2.2. Зависимости Rust-обёртки (`rust/Cargo.toml`)
```toml
[package]
name = "chora_mobile_rust"
version = "0.1.0"
edition = "2024"

[lib]
crate-type = ["cdylib", "staticlib"]

[dependencies]
anyhow = "1"
chrono = "0.4"
flutter_rust_bridge = "=2.7.0"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
# Оригинальная библиотека chora БЕЗ терминальных/CLI зависимостей:
chora = { path = "../../chora", default-features = false }
```

---

## 3. Спецификация Rust FFI API (`rust/src/api.rs`)

Весь бэкенд в `rust/src/api.rs` — это тонкая прослойка над крейтом `chora`. После написания этого файла нужно запустить `flutter_rust_bridge_codegen generate`.

### Структуры данных для передачи во Flutter:

```rust
use std::path::PathBuf;
use chrono::{NaiveDate, NaiveTime};
use chora::{
    calendar::{month_grid, load_marks},
    event::{self, Event},
    index::{AccessLevel, Index},
    note,
    store::Store,
};

#[derive(Debug, Clone)]
pub enum SecurityLevel {
    Open,
    Restricted,
    Critical,
}

impl From<AccessLevel> for SecurityLevel {
    fn from(level: AccessLevel) -> Self {
        match level {
            AccessLevel::Open => Self::Open,
            AccessLevel::Restricted => Self::Restricted,
            AccessLevel::Critical => Self::Critical,
        }
    }
}

#[derive(Debug, Clone)]
pub struct NoteFileDto {
    pub rel_path: String,       // Например: "work/guides/deploy.md"
    pub file_name: String,      // "deploy.md"
    pub security: SecurityLevel,
    pub about: String,
    pub headers: Vec<String>,   // Список заголовков для автокомплита "#Section"
}

#[derive(Debug, Clone)]
pub struct ProjectDto {
    pub dir: String,            // Имя папки в notes/ или "(files)"
    pub security: SecurityLevel,
    pub about: String,
    pub files: Vec<NoteFileDto>,
}

#[derive(Debug, Clone)]
pub struct EventDto {
    pub index: usize,           // Порядковый индекс секции в файле дня (для точечного редактирования)
    pub title: String,
    pub date_iso: String,       // "YYYY-MM-DD"
    pub time_hhmm: String,      // "HH:MM"
    pub duration_str: String,   // "45m", "1h30m"
    pub context: String,
    pub is_repeatable: bool,    // true, если пришло из events/repeatable/<weekday>.md
}

#[derive(Debug, Clone)]
pub struct CalendarCellDto {
    pub date_iso: String,       // "YYYY-MM-DD"
    pub day_num: u32,
    pub in_current_month: bool,
    pub day_title: Option<String>,    // Первое событие дня (зелёный / primary маркер)
    pub repeat_title: Option<String>, // Первое repeatable событие (синий / secondary маркер)
}

#[derive(Debug, Clone)]
pub enum Priority {
    Low,
    Medium,
    High,
    Urgent,
}

#[derive(Debug, Clone)]
pub struct CaptureRequest {
    pub root_dir: String,
    pub title: String,
    pub body: String,               // Включая чекбоксы "- [ ] ..."
    pub target_note_path: Option<String>, // Например "work/todo.md" (из автокомплита @)
    pub target_header: Option<String>,    // Например "Tasks" (из автокомплита #)
    pub delegate_to_agent: bool,    // Если true -> пишет в <root>/to-agent/
    pub create_as_event: bool,      // Если true -> пишет в events/YYYY-MM-DD.md
    pub event_date_iso: Option<String>,
    pub event_time_hhmm: Option<String>,
    pub event_duration: Option<String>,
    pub priority: Priority,
}
```

### Обязательные FFI-функции в `rust/src/api.rs`:

1. **`init_storage(root_dir: String) -> anyhow::Result<()>`**
   - Вызывает `Store::new(&root_dir).ensure_layout()` и создаёт `<root_dir>/to-agent`.
   - Создаёт `<root_dir>/.stignore` со строками:
     ```text
     .git
     sync.log
     *.swp
     *~
     *.tmp
     .DS_Store
     ```

2. **`list_all_projects(root_dir: String) -> anyhow::Result<Vec<ProjectDto>>`**
   - Загружает `Index::load(&root)`.
   - **ВАЖНО:** вызывает `note::dir_view` и `note::loose_files_view` с уровнем `AccessLevel::Critical` и `bodies = false`, чтобы мобилка видела **все** папки и файлы (включая `critical`), а проверку отпечатка пальца / PIN-кода выполнял сам Flutter перед открытием файла!
   - Для каждого файла читает заголовки через `note::read_headers(&text)`, чтобы автокомплит в Capture знал все `#Секции`.

3. **`read_note_file(root_dir: String, rel_path: String) -> anyhow::Result<NoteContentDto>`**
   - Безопасно строит путь через `note::join_safe(&store.notes_dir(), &rel_path)`.
   - Возвращает полный Markdown-текст, `SecurityLevel` и `about`.

4. **`save_note_file(root_dir: String, rel_path: String, new_body: String) -> anyhow::Result<()>`**
   - Перезаписывает `.md` файл (используется и при ручном редактировании, и при переключении чекбокса `- [ ]` -> `- [x]` в превью).

5. **`toggle_markdown_checkbox(root_dir: String, rel_path: String, line_index: usize) -> anyhow::Result<String>`**
   - Находит строку `line_index` (0-based) в файле: если в ней `- [ ] `, меняет на `- [x] `, и наоборот. Сохраняет файл и возвращает обновлённый текст.

6. **`submit_capture(req: CaptureRequest) -> anyhow::Result<String>`**
   - Логика маршрутизации GTD Capture:
     - **Ветка 1 (`req.delegate_to_agent == true`):** вызывает `store.write_agent_task(...)` — создаёт файл `to-agent/YYYY-MM-DD-<slug>.md` с шапкой:
       ```markdown
       # <title>
       Priority: <low|medium|high|urgent>
       Project: <target_note_path или none>

       <body>
       ```
     - **Ветка 2 (`req.create_as_event == true`):** парсит `event_date_iso`, `event_time_hhmm` (`event::parse_time_arg`), `event_duration` (`event::parse_duration`), формирует `Event`, рендерит через `event::render_section` и вызывает `store.append_section(date, &section)`.
     - **Ветка 3 (обычная заметка):** если указан `target_note_path`:
       - если указан `target_header` — читает файл, вызывает `note::insert_under(&text, header, &formatted_body)` и сохраняет;
       - если `target_header` не указан — дописывает блок в конец файла `notes/<target_note_path>`.
       - если не указан даже `target_note_path` — дописывает в `notes/inbox.md`.

7. **`get_calendar_month(root_dir: String, year: i32, month: u32, show_repeat: bool) -> anyhow::Result<Vec<CalendarCellDto>>`**
   - Вызывает `chora::calendar::month_grid(year, month)` и `chora::calendar::load_marks(&root, year, month, show_repeat)`. Возвращает ровно 42 ячейки.

8. **`get_day_events(root_dir: String, date_iso: String) -> anyhow::Result<(String, Vec<EventDto>)>`**
   - Возвращает `(raw_day_markdown, merged_events)`.
   - `merged_events` содержит события из `events/YYYY-MM-DD.md` (`is_repeatable = false` + точный `index` секции в файле дня) и события из `events/repeatable/<weekday>.md` (`is_repeatable = true`), отсортированные по `time`.

9. **`update_single_event(root_dir: String, date_iso: String, section_index: usize, updated: EventDto) -> anyhow::Result<()>`**
   - Вызывает новую функцию `chora::event::replace_section`, которая меняет в файле `events/YYYY-MM-DD.md` только одну секцию `section_index`, не трогая остальные задачи дня и свободные заметки.

10. **`create_event(root_dir: String, event: EventDto) -> anyhow::Result<()>`**
    - Вызывает `store.append_section(date, &event::render_section(&ev))`.

11. **`get_repeatable_weekday(root_dir: String, weekday: String) -> anyhow::Result<Vec<EventDto>>`** и **`save_repeatable_weekday(...)`**
    - Чтение и запись `events/repeatable/<monday..sunday>.md`.

---

## 4. Встраивание демона Syncthing внутрь Android-приложения

Пользователь **не ставит** отдельное приложение Syncthing. Демон работает внутри `chora-mobile` и управляется галочкой в настройках.

### 4.1. Где лежит бинарник
Скомпилированный `libsyncthing.so` (из `syncthing-android` / `gobuild`) кладётся в:
- `android/app/src/main/jniLibs/arm64-v8a/libsyncthing.so`
- `android/app/src/main/jniLibs/x86_64/libsyncthing.so` (для эмулятора)

В `android/app/build.gradle`:
```groovy
android {
    packagingOptions {
        jniLibs {
            useLegacyPackaging = true // Обязательно! Чтобы Android распаковал libsyncthing.so в nativeLibraryDir с правами +x
        }
    }
}
```

### 4.2. Разрешения в `AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="com.android.alarm.permission.SET_ALARM" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

### 4.3. ForegroundService (`SyncthingService.kt`)
1. При первом включении тумблера «Syncthing Sync» в настройках:
   - Сервис создаёт приватную папку конфигурации: `val stHome = File(filesDir, "syncthing_home")`.
   - Если `config.xml` ещё нет — запускает:
     `ProcessBuilder("$nativeLibraryDir/libsyncthing.so", "-generate=${stHome.absolutePath}").start().waitFor()`
   - Парсит/обновляет `config.xml`:
     - Выставляет фиксированный `<gui enabled="true"><address>127.0.0.1:8384</address><apikey>CHORA_LOCAL_KEY</apikey></gui>`.
     - Удаляет дефолтную папку `default` и прописывает **ровно одну папку**:
       ```xml
       <folder id="chora-root" label="Chora" path="/путь/к/chora_dir" type="sendreceive" rescanIntervalS="3600" fsWatcherEnabled="true" fsWatcherDelayS="5">
       ```
2. Когда тумблер включён — стартует `ForegroundService` с типом `FOREGROUND_SERVICE_TYPE_DATA_SYNC` и тихим уведомлением `"Chora Sync активен"`.
3. Процесс запускается командой:
   ```kotlin
   ProcessBuilder(
       "${applicationInfo.nativeLibraryDir}/libsyncthing.so",
       "-home=${stHome.absolutePath}",
       "-no-browser",
       "-no-restart"
   ).start()
   ```
4. Когда тумблер выключают — сервис шлёт `POST http://127.0.0.1:8384/rest/system/shutdown` с заголовком `X-API-Key` и останавливает `ForegroundService`.
5. **Привязка ПК внутри приложения:**
   - Flutter запрашивает `GET http://127.0.0.1:8384/rest/system/status` → берёт `myID` → рисует QR-код.
   - При сканировании QR-кода ПК вызывается `GET /rest/config`, в массив `devices` добавляется `deviceID` компьютера, и в папку `chora-root` добавляется `<device id="..."/>`, после чего шлётся `PUT /rest/config`. Никакого веб-интерфейса Syncthing юзеру открывать не нужно.

---

## 5. Дизайн-система и UX (Material 3 + Референсы Opal / Luma / Layers)

### 5.1. Что взято из референсов и как это реализовать во Flutter:
1. **Opal (iOS) вайб:**
   - Высококонтрастные поверхности, моноширинные акценты для времени/счётчиков/статусов, ощущение «инструмента для фокуса».
   - Тактильные переключатели и минималистичный экран блокировки (PIN / Biometric) с крупными круглыми кнопками без рамок.
2. **Luma (iOS) вайб:**
   - «Тёплый минимализм» в списках событий и карточках: отказ от стандартных Material-теней (`elevation: 0` везде!).
   - Вместо теней — чистая обводка `Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1.0)` и радиус `BorderRadius.circular(16)`.
   - Компактные бейджи метаданных (плашки `09:00`, `45m`, `[restricted]`) с фоном `colorScheme.surfaceContainerHighest` и скруглением `6px`.
3. **Layers (Budgeting App) вайб:**
   - Плотная сетка (Bento-grid): важные переключатели (Приоритет, Делегировать агенту, Записать как Event) оформлены не скучными чекбоксами в столбик, а компактными плитками-чипами в 2 колонки.
   - Плавающая нижняя панель навигации (Floating Pill Bar) с отступом `16px` от краёв экрана.

### 5.2. Цветовая палитра (System Dynamic по дефолту + Пресеты)
Использовать `DynamicColorBuilder` из пакета `dynamic_color`:
- **Пресет 1 (По дефолту): `System Dynamic`** — берёт `lightDynamic` / `darkDynamic` прямо из системы Android 12+ (Material You).
- **Пресет 2: `Opal Obsidian`** — фон `#090A0C`, карточки `#121418`, обводка `#22262E`, акцент `#A3FF12` (кислотный лайм).
- **Пресет 3: `Luma Warm`** — тёмный: фон `#141312`, карточки `#1E1C1A`, акцент `#FF6B4A` (тёплый коралл); светлый: фон `#FAF8F5`, карточки `#FFFFFF`, обводка `#E6E2DC`.
- **Пресет 4: `Monochrome Ink`** — чисто чёрно-белый высококонтрастный режим.

### 5.3. Типографика (4 шрифта на выбор в Settings)
В настройках выбирается основной шрифт приложения (`google_fonts`):
1. `Onest` *(по дефолту — современный гротеск с отличной кириллицей)*
2. `Golos Text` *(строгий читаемый гротеск)*
3. `Martian Mono` *(брутальный моноширинный)*
4. `IBM Plex Mono` *(инженерный моноширинный)*

**Правило комбинирования:** даже если выбран `Onest` или `Golos Text`, все пути файлов (`work/arch.md`), уровни доступа (`[critical]`), время (`11:00 · 45m`) и попап автокомплита рендерятся моноширинным (`IBM Plex Mono` или `Martian Mono`).

---

## 6. Подробное ТЗ по каждому экрану

Главный каркас (`MainScaffold`) содержит `PageView` на 4 экрана (можно свайпать влево/вправо) и нижний бар:
`[ Capture ]` • `[ Notes ]` • `[ Events ]` • `[ Settings ]`.
**При каждом холодном запуске приложения всегда открывается вкладка 0 — `Capture`.**

---

### Экран 0: Проверка безопасности (PIN / Biometric Gate)
В настройках задаётся `Security Threshold`:
- `none` — никогда не спрашивать PIN/отпечаток.
- `open` — спрашивать сразу при входе в приложение (блокирует всё приложение на старте).
- `restricted` — пускать в Capture и Events сразу, но при попытке открыть заметку `restricted` или `critical` требовать отпечаток пальца (`local_auth`) или 4-значный PIN-код.
- `critical` *(дефолт)* — все проекты и файлы видны в дереве, `open` и `restricted` открываются сразу, а тап на заметку с уровнем `critical` вызывает отпечаток пальца или PIN-экран.

---

### Экран 1: `Capture` (GTD Inbox — стартовый экран)

Цель: записать мысль, чеклист, задачу агенту или событие за 3 секунды.

#### Элементы экрана (сверху вниз):
1. **Top Bar:**
   - Слева: название `Capture` + маленький индикатор статуса Syncthing (зелёная точка = синхронизировано).
   - Справа: акцентная кнопка `[ Save -> ]` (или `Ctrl+Enter`).
2. **Поле ввода `Title`:**
   - Крупный шрифт (`20sp`, `FontWeight.w600`), placeholder: `"Что нужно сделать или запомнить?"`.
3. **Редактор `Body` (Markdown + IDE Autocomplete):**
   - Многострочное поле.
   - **Панель быстрых кнопок прямо над клавиатурой (Quick Bar):**
     - `[ ☑ Checkbox ]` — вставляет `- [ ] ` в начало текущей строки. При нажатии `Enter` на строке с `- [ ] текст` следующая строка автоматически начинается с `- [ ] `.
     - `[ @ Project ]` — вставляет символ `@` и открывает попап IDE-автокомплита.
     - `[ # Section ]` — вставляет `#` для выбора секции внутри выбранного `.md` файла.
4. **Как должен работать IDE-автокомплит проектов (`@`):**
   - Когда пользователь печатает `@` (или выбирает чип проекта), прямо над курсором появляется всплывающее окно в стиле автокомплита кода VS Code:
     - Фон `surfaceContainerHigh`, обводка `1px solid primary`, шрифт **моноширинный**.
     - Список всех проектов и `.md` файлов из `notes/` **кроме тех проектов, которые скрыты шестерёнкой во вкладке Notes**.
     - Формат строки в автокомплите: `иконка_папки  chora/store.md   [restricted]`.
     - Если после выбора файла пользователь пишет `#` (например `@chora/store.md#`), автокомплит предлагает список заголовков (`MdHeader`) из этого файла (`# Tasks`, `## Bugs`).
     - Выбранная связка отображается как аккуратный чип-токен: `@chora/store.md#Tasks`.
5. **Блок переключателей (Bento-плитки под полем ввода):**
   - **Плитка 1: `Delegate to Agent` (чекбокс/тумблер):**
     - Подпись: `-> to-agent/`.
     - Если включено: при сохранении заметка улетает в `chora_dir/to-agent/YYYY-MM-DD-<slug>.md` (даже если указан `@проект`, проект запишется в поле `Project:` внутри файла для контекста агенту на ПК).
   - **Плитка 2: `Record as Event` (чекбокс/тумблер):**
     - Если включено: под плиткой плавно раскрывается строка из 3 пикеров:
       - `[ Дата: Сегодня ]` (тап открывает выбор даты, стрелки `<-` `->` сдвигают на ±1 день).
       - `[ Время: 14:15 ]` (кнопки `-15m` / `+15m` используют логику `snap_quarter` из `chora`).
       - `[ Длит: 45m ]` (пресеты `15m`, `30m`, `45m`, `1h`, `2h` + ручной ввод).
   - **Полоса выбора `Priority` (Segmented Chips):**
     - `[ Low ]  [ Med ]  [ High ]  [ ! Urgent ]` — сохраняется в метаданные задачи.

---

### Экран 2: `Notes` (Проекты и дерево файлов)

Никаких переходов на 5 экранов вглубь для навигации по папкам — дерево разворачивается **прямо на этом же экране**.

#### Элементы экрана:
1. **Top Bar:**
   - Заголовок `Notes`.
   - Поле быстрого фильтра по имени файла/проекта.
   - Справа сверху: иконка шестерёнки `[ ⚙ ]` (**Visibility Settings**).
2. **Модалка шестерёнки `[ ⚙ ]` (Скрытие проектов):**
   - Открывает `ModalBottomSheet` со списком всех папок верхнего уровня из `notes/`.
   - Напротив каждой папки — `Switch` (вкл/выкл).
   - Скрытые папки сохраняются в `SharedPreferences` (`hidden_projects: List<String>`).
   - **Эффект:** скрытый проект не показывается в списке `Notes` (пока не нажмёшь «Показать скрытые» внизу) и **полностью исключается из автокомплита `@` на экране Capture**.
3. **Аккордеон проектов и дерева `.md` файлов:**
   - Каждый проект верхнего уровня (`notes/<dirname>`) — карточка с бордером `1px`:
     - Название папки, бейдж уровня безопасности (`open` — нейтральный, `restricted` — янтарный, `critical` — красный с иконкой замка 🔒) и текст `about` из `index.md`.
   - При нажатии на проект карточка раскрывается вниз прямо в списке, рисуя дерево вложенных папок и `.md` файлов с вертикальными линиями отступа (`├─`, `└─`).
   - Свободные файлы в корне `notes/*.md` отображаются внизу в группе `(files)`.
4. **Просмотр и редактирование `.md` заметки:**
   - При нажатии на `.md` файл:
     - Если эффективный `security` файла `>= порога безопасности` (по дефолту `critical`), сначала вызывается `local_auth` (отпечаток пальца / PIN).
     - Открывается экран/панель заметки с **Markdown-рендером** (`flutter_markdown`):
       - Заголовки, блоки кода с моноширинным шрифтом, таблицы, списки.
       - **Интерактивные чекбоксы:** тап по чекбоксу `- [ ]` прямо в режиме чтения вызывает `toggle_markdown_checkbox` в Rust и мгновенно обновляет файл на диске.
       - Кнопка `[ Edit ]` в правом верхнем углу переключает в режим редактирования сырого Markdown с моноширинным шрифтом и кнопкой `[ Save ]`.

---

### Экран 3: `Events` (Календарь с облачком + Список + Будильники)

#### Элементы экрана:
1. **Top Bar:**
   - Слева: заголовок `Events`.
   - По центру/справа: переключатель вида `[ Календарь | Список ]`.
   - Справа: кнопка шестерёнки `[ ⚙ ]` (Настройки уведомлений и авто-будильника).
2. **Верхний свёрнутый Dropdown `Repeatable`:**
   - По дефолту свёрнут в одну компактную полоску: `[ ▸ Repeatable (регулярные по дням недели) ]`.
   - При нажатии разворачивается: 7 горизонтальных табов `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, `Sun`.
   - Под выбранным днём недели — список его секций из `events/repeatable/<weekday>.md` + кнопка `[ + Добавить в этот день недели ]`.
3. **Вид 1: Календарь в стиле TUI с всплывающим «Облачком» (Popover Bubble):**
   - **Сетка календаря (`CalendarGridWidget` — изолированный виджет с заделом под системный Android AppWidget):**
     - Строгая плоская сетка 7x6 (42 ячейки, как в `chora/src/calendar.rs`), разделённая тонкими линиями `1px`.
     - В каждой ячейке сверху — укороченное название первого события дня (`day_color`, зелёный/primary) или repeatable (`repeat_color`, синий/secondary), снизу — число месяца.
     - Даты соседних месяцев приглушены (`opacity: 0.35`), сегодняшний день выделен жирной точкой/инверсией.
   - **Поведение при нажатии на дату (Облачко с обводкой):**
     - При тапе на любую ячейку даты поверх сетки календаря (перекрывая соседние даты, с привязкой стрелочки/якоря к выбранной ячейке через `CompositedTransformTarget` / `OverlayPortal`) с пружинной анимацией (`ScaleTransition` + `FadeTransition`, `Curves.easeOutBack`, `220ms`) появляется **облачко (Popover Card)**:
       - Фон: `colorScheme.surfaceContainerHigh`.
       - **Чёткая обводка:** `Border.all(color: colorScheme.primary, width: 1.5)` и скругление `16px`.
       - В шапке облачка: `# YYYY-MM-DD`, кнопка `[ Raw MD ]` (показать сырой markdown всего дня) и кнопка `[ + ]` (добавить задачу на этот день).
       - Внутри облачка — отрендеренный список всех событий этого дня (`Time`, `Duration`, `Title`, `Context`, иконка `⟳` для repeatable).
   - **Поведение при нажатии на конкретную задачу внутри облачка:**
     - Нажатие на одну конкретную задачу плавно переключает (через `AnimatedSize` + `AnimatedSwitcher`) содержимое облачка в **форму редактирования только этой одной задачи**:
       - Поля: `Title`, `Time (HH:MM с шагом ±15m)`, `Duration`, `Context`.
       - Кнопки `[ Сохранить ]` (вызывает `update_single_event`, который правит только эту `##` секцию в `events/YYYY-MM-DD.md`) и `[ Удалить ]`.
4. **Вид 2: Список (`List View`):**
   - Хронологический список всех дней (`store.list_days()`), сгруппированный по датам, с карточками событий в стиле Luma.
5. **Кнопка `[ + ]` (FAB):**
   - Открывает форму создания нового события (поля как в TUI `chora event`: `Title`, `Date`, `Time` с шагом 15 минут, `Duration`, `Context`). Если введена дата в прошлом — показывает пасхалку из оригинального TUI: грустную ASCII-рожицу `<'(o.o)'>` (`src/tui.rs:116`).
6. **Шестерёнка `[ ⚙ ]` в Events (Напоминалки и Авто-будильник):**
   - **Уведомления о задачах:** тумблер Вкл/Выкл + выбор за сколько минут предупреждать (`За 5 мин`, `За 15 мин`, `За 30 мин`, `В момент начала`). Планируется через `flutter_local_notifications` при каждом сохранении/синке событий.
   - **Автоматический системный будильник Android:**
     - Тумблер `Ставить системный будильник автоматически`.
     - Настройка: `По первому событию дня` или `По событиям с тегом #alarm`, со сдвигом `За N минут до события` (например, за 30 минут).
     - Реализация: вызывает системный `Intent(AlarmClock.ACTION_SET_ALARM)` с `EXTRA_HOUR`, `EXTRA_MINUTES`, `EXTRA_MESSAGE = event.title`, `EXTRA_SKIP_UI = true`.

---

### Экран 4: `Settings` (Все настройки приложения)

Разбит на 4 чистых блока-карточки:

1. **Appearance (Внешний вид):**
   - **Цветовая палитра:** выбор между `System Dynamic (Default)`, `Opal Obsidian`, `Luma Warm`, `Monochrome Ink`.
   - **Тема:** `System` / `Light` / `Dark`.
   - **Шрифт:** радио-выбор из 4 шрифтов: `Onest`, `Golos Text`, `Martian Mono`, `IBM Plex Mono` (меняется реактивно без перезапуска).
   - **Календарь:** переключатель `Показывать Repeatable на сетке` (`show_repeat`), `Квадратные ячейки` (`fixed_cells`).
2. **Security (Безопасность и доступ):**
   - **Порог запроса PIN / Биометрии:** сегментированный контрол:
     `None` | `Open` | `Restricted` | `Critical (Default)`.
   - Тумблер `Разблокировка отпечатком пальца` (`local_auth`).
   - Кнопка `Установить / Изменить PIN-код` (сохраняет хеш в `flutter_secure_storage`).
3. **Syncthing (P2P синхронизация `chora_dir`):**
   - **Главный тумблер:** `Включить синхронизацию (Syncthing Daemon)` — запускает/останавливает `SyncthingService`.
   - **Статус демона:** `Работает • Папка: chora-root • Онлайн: 1 устр.`
   - **Мой Device ID:** моноширинная строка с кнопкой `[ Копировать ]` и `[ Показать QR-код ]`.
   - **Подключённые устройства (ПК):** список привязанных устройств + кнопка `[ + Привязать ПК по QR / ID ]`.
   - **Конфликты синхронизации:** если в `chora_dir` найдены файлы `*.sync-conflict-*`, появляется жёлтая плашка с кнопкой выбора, какую версию оставить.
4. **Storage & Maintenance:**
   - Путь к `chora_dir` на телефоне.
   - Политика старых событий (`manage_old_event`): `Nothing` | `Backlog (в events/backlog/)` | `Delete` + кнопка `[ Очистить старые дни сейчас ]` (вызывает `store.sweep_old_events`).

---

## 7. Чек-лист приёмки (Definition of Done для `chora-mobile`)

1. `cargo test` внутри `rust/` проходит без ошибок.
2. `fvm dart format --output=none --set-exit-if-changed .` и `fvm flutter analyze` выдают 0 предупреждений, `fvm flutter test` проходит.
3. Приложение стартует сразу на экране `Capture`.
4. Ввод `@` в `Capture` открывает моноширинный список проектов из `notes/`, не включая скрытые через шестерёнку в `Notes`.
5. Запись с галочкой `Delegate to Agent` создаёт валидный `.md` файл в `<chora_dir>/to-agent/`.
6. В `Notes` видны все проекты (`open`, `restricted`, `critical`), но открытие `critical` файла требует биометрию/PIN.
7. В `Events` нажатие на дату в сетке календаря открывает поверх соседних дат облачко с обводкой, а нажатие на задачу в облачке редактирует ровно одну `##` секцию файла дня.
8. Включение тумблера Syncthing поднимает `libsyncthing.so` только для `chora_dir` и создаёт `.stignore` с `.git`.
