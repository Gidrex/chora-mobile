//! Mobile backend: a thin FFI layer over the `chora` library.
//!
//! Flutter enforces the PIN/biometric gate itself; every function here reads
//! with [`AccessLevel::Critical`] so the UI sees all projects and files.

use std::path::PathBuf;

use anyhow::Context;
use chora::{
    calendar::{load_marks, month_grid},
    event,
    index::{AccessLevel, Index},
    note,
    store::Store,
};
use chrono::{Datelike, NaiveDate};

/// Effective visibility of a note file or project, mirrored from [`AccessLevel`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SecurityLevel {
    /// Visible to everyone.
    Open,
    /// Needs the `restricted` clearance in the UI gate.
    Restricted,
    /// Needs the `critical` clearance (biometric/PIN) in the UI gate.
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

/// One `.md` file listed under a project, with headers for `#`-autocomplete.
#[derive(Debug, Clone)]
pub struct NoteFileDto {
    /// Root-relative path, e.g. `work/guides/deploy.md`.
    pub rel_path: String,
    /// File name only, e.g. `deploy.md`.
    pub file_name: String,
    /// Effective level from `index.md`.
    pub security: SecurityLevel,
    /// Explicit `about:` or the file's own h1, else empty.
    pub about: String,
    /// `#`-header titles in file order, for `#Section` autocomplete.
    pub headers: Vec<String>,
}

/// One top-level `notes/<dir>` project, or `(files)` for loose `notes/*.md`.
#[derive(Debug, Clone)]
pub struct ProjectDto {
    /// Dir name, or `(files)` for loose files.
    pub dir: String,
    /// Effective level of the dir itself.
    pub security: SecurityLevel,
    /// Explicit `about:` of the dir entry, else empty.
    pub about: String,
    /// Files under the dir, recursive.
    pub files: Vec<NoteFileDto>,
}

/// Full contents of one note file.
#[derive(Debug, Clone)]
pub struct NoteContentDto {
    /// Raw markdown text.
    pub text: String,
    /// Effective level from `index.md`.
    pub security: SecurityLevel,
    /// Explicit `about:` or the file's own h1, else empty.
    pub about: String,
}

/// One calendar event, either from a day file or a repeatable weekday file.
#[derive(Debug, Clone)]
pub struct EventDto {
    /// Position in [`event::parse_day`] sorted order within its own file.
    /// Day events: index for `update_single_event`. Repeatables: parse order.
    pub index: usize,
    /// The `##` header.
    pub title: String,
    /// `YYYY-MM-DD`.
    pub date_iso: String,
    /// `HH:MM`.
    pub time_hhmm: String,
    /// Compact duration, e.g. `45m`, `1h30m`.
    pub duration_str: String,
    /// Free-form body below the `Time:`/`Duration:` lines.
    pub context: String,
    /// True when read from `events/repeatable/<weekday>.md`.
    pub is_repeatable: bool,
}

/// One of the 42 calendar grid cells.
#[derive(Debug, Clone)]
pub struct CalendarCellDto {
    /// `YYYY-MM-DD`.
    pub date_iso: String,
    /// Day of month.
    pub day_num: u32,
    /// True when the date is inside the shown month.
    pub in_current_month: bool,
    /// First day-file event title, if any.
    pub day_title: Option<String>,
    /// First repeatable title, if any.
    pub repeat_title: Option<String>,
}

/// Raw day file plus its merged events (SPEC `get_day_events` pair).
#[derive(Debug, Clone)]
pub struct DayEventsDto {
    /// Raw `events/YYYY-MM-DD.md` markdown (template when the file is missing).
    pub raw_markdown: String,
    /// Day events (`is_repeatable = false`) plus the weekday's repeatables,
    /// sorted by time.
    pub events: Vec<EventDto>,
}

/// Capture priority, stored in the `to-agent/` file header.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Priority {
    /// Low priority.
    Low,
    /// Medium priority.
    Medium,
    /// High priority.
    High,
    /// Urgent priority.
    Urgent,
}

impl Priority {
    fn as_str(self) -> &'static str {
        match self {
            Self::Low => "low",
            Self::Medium => "medium",
            Self::High => "high",
            Self::Urgent => "urgent",
        }
    }
}

/// One GTD capture from the mobile Capture screen.
#[derive(Debug, Clone)]
pub struct CaptureRequest {
    /// Storage root (`chora_dir`).
    pub root_dir: String,
    /// Capture title.
    pub title: String,
    /// Markdown body, including `- [ ]` checklists.
    pub body: String,
    /// Target note from `@`-autocomplete, e.g. `work/todo.md`.
    pub target_note_path: Option<String>,
    /// Target section from `#`-autocomplete, e.g. `Tasks`.
    pub target_header: Option<String>,
    /// When true, writes to `<root>/to-agent/` instead of notes/events.
    pub delegate_to_agent: bool,
    /// When true (and not delegated), appends to `events/<date>.md`.
    pub create_as_event: bool,
    /// Event date `YYYY-MM-DD` (defaults to today).
    pub event_date_iso: Option<String>,
    /// Event start `HH:MM`.
    pub event_time_hhmm: Option<String>,
    /// Event duration, e.g. `45m`.
    pub event_duration: Option<String>,
    /// Stored in the `to-agent/` file header.
    pub priority: Priority,
}

/// Bridge setup (thread pool, logs). Called once from Dart.
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// Create `events/`, `notes/`, `to-agent/` and a default `.stignore`.
/// Never overwrites an existing `.stignore`.
pub fn init_storage(root_dir: String) -> anyhow::Result<()> {
    let store = Store::new(root_dir);
    store.ensure_layout()?;
    std::fs::create_dir_all(store.to_agent_dir())
        .with_context(|| format!("failed to create {}", store.to_agent_dir().display()))?;
    let ignore = store.root().join(".stignore");
    if !ignore.exists() {
        std::fs::write(&ignore, ".git\nsync.log\n*.swp\n*~\n*.tmp\n.DS_Store\n")
            .with_context(|| format!("failed to write {}", ignore.display()))?;
    }
    Ok(())
}

/// All top-level projects plus `(files)`, with `Critical` clearance and
/// `#`-headers per file. Hidden-project filtering lives in Flutter.
pub fn list_all_projects(root_dir: String) -> anyhow::Result<Vec<ProjectDto>> {
    let root = PathBuf::from(&root_dir);
    let store = Store::new(&root);
    let index = Index::load(&root)?;
    let notes = store.notes_dir();
    let mut out = Vec::new();
    for dir in note::top_dirs(&notes)? {
        let view = note::dir_view(&root, &index, &dir, AccessLevel::Critical, false, &[])?;
        out.push(project_from_view(view, &notes)?);
    }
    let loose = note::loose_files_view(&root, &index, AccessLevel::Critical, false)?;
    out.push(project_from_view(loose, &notes)?);
    Ok(out)
}

/// Read one note file: full text plus its effective security/about.
pub fn read_note_file(root_dir: String, rel_path: String) -> anyhow::Result<NoteContentDto> {
    let store = Store::new(&root_dir);
    let path = note::join_safe(&store.notes_dir(), &rel_path)?;
    let text = std::fs::read_to_string(&path)
        .with_context(|| format!("failed to read {}", path.display()))?;
    let index = Index::load(store.root())?;
    Ok(NoteContentDto {
        text,
        security: SecurityLevel::from(index.security_for(&rel_path)),
        about: index.about_for(&rel_path).to_owned(),
    })
}

/// Overwrite one `.md` file (manual edits and checkbox toggles from preview).
pub fn save_note_file(root_dir: String, rel_path: String, new_body: String) -> anyhow::Result<()> {
    let store = Store::new(&root_dir);
    let path = note::join_safe(&store.notes_dir(), &rel_path)?;
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }
    std::fs::write(&path, new_body)
        .with_context(|| format!("failed to write {}", path.display()))?;
    Ok(())
}

/// Flip `- [ ]` <-> `- [x]` on line `line_index` (0-based). Returns full text.
pub fn toggle_markdown_checkbox(
    root_dir: String,
    rel_path: String,
    line_index: usize,
) -> anyhow::Result<String> {
    let store = Store::new(&root_dir);
    let path = note::join_safe(&store.notes_dir(), &rel_path)?;
    let text = std::fs::read_to_string(&path)
        .with_context(|| format!("failed to read {}", path.display()))?;
    let mut lines: Vec<String> = text.lines().map(str::to_owned).collect();
    let line = lines
        .get_mut(line_index)
        .ok_or_else(|| anyhow::anyhow!("line index {line_index} out of bounds"))?;
    if line.contains("- [ ]") {
        *line = line.replacen("- [ ]", "- [x]", 1);
    } else if line.contains("- [x]") {
        *line = line.replacen("- [x]", "- [ ]", 1);
    } else if line.contains("- [X]") {
        *line = line.replacen("- [X]", "- [ ]", 1);
    } else {
        anyhow::bail!("line {} has no markdown checkbox", line_index + 1);
    }
    let mut out = lines.join("\n");
    if text.ends_with('\n') {
        out.push('\n');
    }
    std::fs::write(&path, &out).with_context(|| format!("failed to write {}", path.display()))?;
    Ok(out)
}

/// Route one capture: `to-agent/` file, day event, or note append.
/// Returns the created/affected file path.
pub fn submit_capture(req: CaptureRequest) -> anyhow::Result<String> {
    if req.title.trim().is_empty() && req.body.trim().is_empty() {
        anyhow::bail!("capture is empty: need a title or a body");
    }
    let store = Store::new(&req.root_dir);
    if req.delegate_to_agent {
        let path = store.write_agent_task(
            chrono::Local::now().date_naive(),
            req.title.trim(),
            req.priority.as_str(),
            req.target_note_path
                .as_deref()
                .map(str::trim)
                .filter(|s| !s.is_empty()),
            &req.body,
        )?;
        return Ok(path.to_string_lossy().into_owned());
    }
    if req.create_as_event {
        let date = match req.event_date_iso.as_deref().map(str::trim) {
            Some(raw) if !raw.is_empty() => NaiveDate::parse_from_str(raw, "%Y-%m-%d")
                .with_context(|| format!("bad event date `{raw}`: expected YYYY-MM-DD"))?,
            _ => chrono::Local::now().date_naive(),
        };
        let time = match req.event_time_hhmm.as_deref().map(str::trim) {
            Some(raw) if !raw.is_empty() => event::parse_time_arg(raw)?,
            _ => anyhow::bail!("event needs a start time HH:MM"),
        };
        let duration = match req.event_duration.as_deref().map(str::trim) {
            Some(raw) if !raw.is_empty() => event::parse_duration(raw)?,
            _ => anyhow::bail!("event needs a duration like 45m"),
        };
        let ev = event::Event {
            title: req.title.trim().to_owned(),
            date,
            time,
            duration,
            context: req.body.trim().to_owned(),
        };
        store.append_section(date, &event::render_section(&ev))?;
        return Ok(store.day_path(date).to_string_lossy().into_owned());
    }
    let block = if req.title.trim().is_empty() {
        req.body.trim().to_owned()
    } else if req.body.trim().is_empty() {
        format!("## {}", req.title.trim())
    } else {
        format!("## {}\n\n{}", req.title.trim(), req.body.trim())
    };
    let rel = req
        .target_note_path
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or("inbox.md");
    note::require_md(rel)?;
    let path = note::join_safe(&store.notes_dir(), rel)?;
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }
    if path.exists() {
        let text = std::fs::read_to_string(&path)
            .with_context(|| format!("failed to read {}", path.display()))?;
        let updated = match req.target_header.as_deref().map(str::trim) {
            Some(header) if !header.is_empty() => note::insert_under(&text, header, &block)?,
            _ => append_block(&text, &block),
        };
        std::fs::write(&path, updated)
            .with_context(|| format!("failed to write {}", path.display()))?;
    } else if req
        .target_header
        .as_deref()
        .is_some_and(|h| !h.trim().is_empty())
    {
        anyhow::bail!("no such file `{rel}`: `#header` needs an existing file");
    } else {
        std::fs::write(&path, format!("{block}\n"))
            .with_context(|| format!("failed to write {}", path.display()))?;
    }
    Ok(path.to_string_lossy().into_owned())
}

/// 42 calendar cells with day/repeatable markers, in grid order.
pub fn get_calendar_month(
    root_dir: String,
    year: i32,
    month: u32,
    show_repeat: bool,
) -> anyhow::Result<Vec<CalendarCellDto>> {
    let root = PathBuf::from(&root_dir);
    let cells = month_grid(year, month).ok_or_else(|| anyhow::anyhow!("date out of range"))?;
    let marks = load_marks(&root, year, month, show_repeat)?;
    Ok(cells
        .into_iter()
        .zip(marks)
        .map(|(cell, mark)| CalendarCellDto {
            date_iso: cell.date.format("%Y-%m-%d").to_string(),
            day_num: cell.date.day(),
            in_current_month: cell.current,
            day_title: mark.day_title,
            repeat_title: mark.repeat_title,
        })
        .collect())
}

/// Raw day markdown plus day events and the weekday's repeatables by time.
pub fn get_day_events(root_dir: String, date_iso: String) -> anyhow::Result<DayEventsDto> {
    let store = Store::new(&root_dir);
    let date = parse_date(&date_iso)?;
    let raw_markdown = store.read_day(date)?;
    let mut events: Vec<EventDto> = event::parse_day(date, &raw_markdown)
        .iter()
        .enumerate()
        .map(|(index, ev)| event_to_dto(ev, index, false))
        .collect();
    for (index, ev) in store.read_repeatables(date)?.iter().enumerate() {
        events.push(event_to_dto(ev, index, true));
    }
    events.sort_by_key(|dto| dto.time_hhmm.clone());
    Ok(DayEventsDto {
        raw_markdown,
        events,
    })
}

/// Rewrite only the `section_index`-th event section of a day file.
pub fn update_single_event(
    root_dir: String,
    date_iso: String,
    section_index: usize,
    updated: EventDto,
) -> anyhow::Result<()> {
    let store = Store::new(&root_dir);
    let date = parse_date(&date_iso)?;
    let day_path = store.day_path(date);
    let text = std::fs::read_to_string(&day_path)
        .with_context(|| format!("failed to read {}", day_path.display()))?;
    let ev = dto_to_event(&updated, date)?;
    let out = event::replace_section(&text, section_index, &ev)?;
    std::fs::write(&day_path, out)
        .with_context(|| format!("failed to write {}", day_path.display()))?;
    Ok(())
}

/// Delete only the `section_index`-th event section of a day file.
pub fn delete_single_event(
    root_dir: String,
    date_iso: String,
    section_index: usize,
) -> anyhow::Result<()> {
    let store = Store::new(&root_dir);
    let date = parse_date(&date_iso)?;
    let day_path = store.day_path(date);
    let text = std::fs::read_to_string(&day_path)
        .with_context(|| format!("failed to read {}", day_path.display()))?;
    let out = event::remove_section(&text, section_index)?;
    std::fs::write(&day_path, out)
        .with_context(|| format!("failed to write {}", day_path.display()))?;
    Ok(())
}

/// Append one event section to a day file.
pub fn create_event(root_dir: String, event: EventDto) -> anyhow::Result<()> {
    let store = Store::new(&root_dir);
    let date = parse_date(&event.date_iso)?;
    let ev = dto_to_event(&event, date)?;
    store.append_section(date, &event::render_section(&ev))?;
    Ok(())
}

/// Events of `events/repeatable/<weekday>.md` (`monday`..`sunday`).
pub fn get_repeatable_weekday(root_dir: String, weekday: String) -> anyhow::Result<Vec<EventDto>> {
    let store = Store::new(&root_dir);
    let date = weekday_to_date(&weekday)?;
    Ok(store
        .read_repeatables(date)?
        .iter()
        .enumerate()
        .map(|(index, ev)| event_to_dto(ev, index, true))
        .collect())
}

/// Rewrite `events/repeatable/<weekday>.md` from the given events.
/// Plain-text sections of the old file are not preserved.
pub fn save_repeatable_weekday(
    root_dir: String,
    weekday: String,
    events: Vec<EventDto>,
) -> anyhow::Result<()> {
    let store = Store::new(&root_dir);
    let date = weekday_to_date(&weekday)?;
    let dir = store.events_dir().join("repeatable");
    std::fs::create_dir_all(&dir).with_context(|| format!("failed to create {}", dir.display()))?;
    let mut sections = Vec::with_capacity(events.len());
    for dto in &events {
        sections.push(
            event::render_section(&dto_to_event(dto, date)?)
                .trim()
                .to_owned(),
        );
    }
    let name = weekday.trim().to_lowercase();
    let title = format!("{}{}", name[..1].to_uppercase(), &name[1..]);
    let text = if sections.is_empty() {
        format!("# {title}\n")
    } else {
        format!("# {title}\n\n{}\n", sections.join("\n\n"))
    };
    let path = dir.join(format!("{name}.md"));
    std::fs::write(&path, text).with_context(|| format!("failed to write {}", path.display()))?;
    Ok(())
}

fn project_from_view(view: note::DirView, notes: &std::path::Path) -> anyhow::Result<ProjectDto> {
    let mut files = Vec::with_capacity(view.files.len());
    for file in &view.files {
        let abs = note::join_safe(notes, &file.path)?;
        let text = std::fs::read_to_string(&abs).unwrap_or_default();
        files.push(NoteFileDto {
            file_name: file
                .path
                .rsplit('/')
                .next()
                .unwrap_or(&file.path)
                .to_owned(),
            rel_path: file.path.clone(),
            security: SecurityLevel::from(file.security),
            about: file.about.clone(),
            headers: note::read_headers(&text)
                .into_iter()
                .map(|header| header.title)
                .collect(),
        });
    }
    Ok(ProjectDto {
        dir: view.dir,
        security: SecurityLevel::from(view.security),
        about: view.about,
        files,
    })
}

fn event_to_dto(ev: &event::Event, index: usize, is_repeatable: bool) -> EventDto {
    EventDto {
        index,
        title: ev.title.clone(),
        date_iso: ev.date.format("%Y-%m-%d").to_string(),
        time_hhmm: ev.time.format("%H:%M").to_string(),
        duration_str: event::format_duration(ev.duration),
        context: ev.context.clone(),
        is_repeatable,
    }
}

fn dto_to_event(dto: &EventDto, fallback_date: NaiveDate) -> anyhow::Result<event::Event> {
    let date = match dto.date_iso.trim() {
        "" => fallback_date,
        raw => parse_date(raw)?,
    };
    Ok(event::Event {
        title: dto.title.trim().to_owned(),
        date,
        time: event::parse_time_arg(dto.time_hhmm.trim())?,
        duration: event::parse_duration(dto.duration_str.trim())?,
        context: dto.context.trim().to_owned(),
    })
}

fn parse_date(raw: &str) -> anyhow::Result<NaiveDate> {
    NaiveDate::parse_from_str(raw.trim(), "%Y-%m-%d")
        .with_context(|| format!("bad date `{raw}`: expected YYYY-MM-DD"))
}

/// A recent date (today or up to 6 days back) falling on `weekday`.
fn weekday_to_date(weekday: &str) -> anyhow::Result<NaiveDate> {
    let want = weekday.trim().to_lowercase();
    let names = [
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday",
    ];
    if !names.contains(&want.as_str()) {
        anyhow::bail!("bad weekday `{weekday}`: expected monday..sunday");
    }
    let mut date = chrono::Local::now().date_naive();
    for _ in 0..7 {
        if date.format("%A").to_string().to_lowercase() == want {
            return Ok(date);
        }
        date = date
            .pred_opt()
            .ok_or_else(|| anyhow::anyhow!("date out of range"))?;
    }
    anyhow::bail!("bad weekday `{weekday}`: expected monday..sunday")
}

/// Delete or archive past day files per policy (`nothing`|`backlog`|`delete`).
/// Returns a short human summary.
pub fn sweep_old_events(root_dir: String, policy: String) -> anyhow::Result<String> {
    use chora::config::OldEventPolicy;
    let store = Store::new(&root_dir);
    let policy = match policy.trim().to_lowercase().as_str() {
        "delete" => OldEventPolicy::Delete,
        "backlog" => OldEventPolicy::Backlog,
        _ => OldEventPolicy::Nothing,
    };
    let report = store.sweep_old_events(policy, chrono::Local::now().date_naive())?;
    Ok(format!(
        "deleted {}, backlogged {}",
        report.deleted, report.backlogged
    ))
}

/// Append a block after a blank separator, mirroring `chora note add`.
fn append_block(text: &str, block: &str) -> String {
    let mut out = text.to_owned();
    if !out.ends_with('\n') {
        out.push('\n');
    }
    out.push('\n');
    out.push_str(block.trim_matches('\n'));
    out.push('\n');
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU64, Ordering};

    static COUNTER: AtomicU64 = AtomicU64::new(0);

    fn tmp_root() -> String {
        let dir = std::env::temp_dir().join(format!(
            "chora-mobile-test-{}-{}",
            std::process::id(),
            COUNTER.fetch_add(1, Ordering::SeqCst)
        ));
        std::fs::create_dir_all(&dir).unwrap();
        dir.to_string_lossy().into_owned()
    }

    fn capture(title: &str, body: &str) -> CaptureRequest {
        CaptureRequest {
            root_dir: String::new(),
            title: title.to_owned(),
            body: body.to_owned(),
            target_note_path: None,
            target_header: None,
            delegate_to_agent: false,
            create_as_event: false,
            event_date_iso: None,
            event_time_hhmm: None,
            event_duration: None,
            priority: Priority::Medium,
        }
    }

    #[test]
    fn init_creates_layout_and_default_stignore() {
        let root = tmp_root();
        init_storage(root.clone()).unwrap();
        for dir in ["events", "notes", "to-agent"] {
            assert!(PathBuf::from(&root).join(dir).is_dir(), "{dir}");
        }
        let ignore = std::fs::read_to_string(PathBuf::from(&root).join(".stignore")).unwrap();
        assert!(ignore.lines().any(|line| line == ".git"), "{ignore}");
        std::fs::write(PathBuf::from(&root).join(".stignore"), "custom\n").unwrap();
        init_storage(root.clone()).unwrap();
        assert_eq!(
            std::fs::read_to_string(PathBuf::from(&root).join(".stignore")).unwrap(),
            "custom\n"
        );
    }

    #[test]
    fn capture_note_goes_to_inbox_then_under_header() {
        let root = tmp_root();
        init_storage(root.clone()).unwrap();
        let mut req = capture("Buy milk", "- [ ] milk");
        req.root_dir = root.clone();
        let path = submit_capture(req).unwrap();
        assert!(path.ends_with("notes/inbox.md"), "{path}");
        let text = std::fs::read_to_string(&path).unwrap();
        assert!(text.contains("## Buy milk"), "{text}");

        let mut req = capture("More", "oats");
        req.root_dir = root.clone();
        req.target_note_path = Some("inbox.md".to_owned());
        req.target_header = Some("Buy milk".to_owned());
        submit_capture(req).unwrap();
        let text = std::fs::read_to_string(&path).unwrap();
        assert!(text.contains("oats"), "{text}");
        assert!(text.contains("## Buy milk"), "{text}");
    }

    #[test]
    fn capture_delegate_writes_agent_file_with_metadata() {
        let root = tmp_root();
        init_storage(root.clone()).unwrap();
        let mut req = capture("Fix bug", "details");
        req.root_dir = root.clone();
        req.delegate_to_agent = true;
        req.priority = Priority::High;
        req.target_note_path = Some("work/todo.md".to_owned());
        let path = submit_capture(req).unwrap();
        assert!(path.contains("to-agent/"), "{path}");
        let text = std::fs::read_to_string(&path).unwrap();
        assert!(text.contains("Priority: high"), "{text}");
        assert!(text.contains("Project: work/todo.md"), "{text}");
    }

    #[test]
    fn capture_event_appends_day_section() {
        let root = tmp_root();
        init_storage(root.clone()).unwrap();
        let mut req = capture("Standup", "agenda");
        req.root_dir = root.clone();
        req.create_as_event = true;
        req.event_date_iso = Some("2026-11-20".to_owned());
        req.event_time_hhmm = Some("11:00".to_owned());
        req.event_duration = Some("45m".to_owned());
        let path = submit_capture(req).unwrap();
        assert!(path.ends_with("events/2026-11-20.md"), "{path}");

        let day = get_day_events(root.clone(), "2026-11-20".to_owned()).unwrap();
        assert_eq!(day.events.len(), 1);
        assert_eq!(day.events[0].title, "Standup");
        assert_eq!(day.events[0].time_hhmm, "11:00");
        assert_eq!(day.events[0].duration_str, "45m");
        assert!(!day.events[0].is_repeatable);
        assert!(
            day.raw_markdown.contains("## Standup"),
            "{}",
            day.raw_markdown
        );
    }

    #[test]
    fn checkbox_toggle_flips_marker() {
        let root = tmp_root();
        init_storage(root.clone()).unwrap();
        save_note_file(
            root.clone(),
            "inbox.md".to_owned(),
            "- [ ] milk\nplain\n".to_owned(),
        )
        .unwrap();
        let out = toggle_markdown_checkbox(root.clone(), "inbox.md".to_owned(), 0).unwrap();
        assert!(out.contains("- [x] milk"), "{out}");
        let out = toggle_markdown_checkbox(root.clone(), "inbox.md".to_owned(), 0).unwrap();
        assert!(out.contains("- [ ] milk"), "{out}");
        assert!(toggle_markdown_checkbox(root, "inbox.md".to_owned(), 1).is_err());
    }

    #[test]
    fn calendar_month_has_42_cells() {
        let root = tmp_root();
        init_storage(root.clone()).unwrap();
        let cells = get_calendar_month(root, 2026, 10, true).unwrap();
        assert_eq!(cells.len(), 42);
        assert!(
            cells
                .iter()
                .any(|cell| cell.in_current_month && cell.day_num == 1)
        );
        assert!(get_calendar_month(tmp_root(), 2026, 13, true).is_err());
    }

    #[test]
    fn update_event_rewrites_single_section() {
        let root = tmp_root();
        init_storage(root.clone()).unwrap();
        for (title, time) in [("Early", "09:00"), ("Late", "18:00")] {
            create_event(
                root.clone(),
                EventDto {
                    index: 0,
                    title: title.to_owned(),
                    date_iso: "2026-11-20".to_owned(),
                    time_hhmm: time.to_owned(),
                    duration_str: "30m".to_owned(),
                    context: String::new(),
                    is_repeatable: false,
                },
            )
            .unwrap();
        }
        let day = get_day_events(root.clone(), "2026-11-20".to_owned()).unwrap();
        assert_eq!(day.events[0].title, "Early");
        let mut updated = day.events[0].clone();
        updated.title = "Early fixed".to_owned();
        update_single_event(root.clone(), "2026-11-20".to_owned(), 0, updated).unwrap();
        let day = get_day_events(root.clone(), "2026-11-20".to_owned()).unwrap();
        assert_eq!(day.events.len(), 2);
        assert_eq!(day.events[0].title, "Early fixed");
        assert_eq!(day.events[1].title, "Late");
        delete_single_event(root.clone(), "2026-11-20".to_owned(), 1).unwrap();
        let day = get_day_events(root, "2026-11-20".to_owned()).unwrap();
        assert_eq!(day.events.len(), 1);
        assert_eq!(day.events[0].title, "Early fixed");
    }

    #[test]
    fn sweep_delete_removes_only_past_days() {
        let root = tmp_root();
        init_storage(root.clone()).unwrap();
        let store = Store::new(&root);
        let past = chrono::Local::now().date_naive().pred_opt().unwrap();
        std::fs::write(
            store.day_path(past),
            format!("# {}\n", past.format("%Y-%m-%d")),
        )
        .unwrap();
        let summary = sweep_old_events(root.clone(), "delete".to_owned()).unwrap();
        assert!(summary.contains("deleted 1"), "{summary}");
        assert!(!store.day_path(past).exists());
    }

    #[test]
    fn repeatable_weekday_roundtrips() {
        let root = tmp_root();
        init_storage(root.clone()).unwrap();
        assert!(get_repeatable_weekday(root.clone(), "funday".to_owned()).is_err());
        save_repeatable_weekday(
            root.clone(),
            "monday".to_owned(),
            vec![EventDto {
                index: 0,
                title: "Gym".to_owned(),
                date_iso: String::new(),
                time_hhmm: "19:00".to_owned(),
                duration_str: "1h".to_owned(),
                context: String::new(),
                is_repeatable: true,
            }],
        )
        .unwrap();
        let events = get_repeatable_weekday(root, "monday".to_owned()).unwrap();
        assert_eq!(events.len(), 1);
        assert_eq!(events[0].title, "Gym");
        assert!(events[0].is_repeatable);
    }
}
