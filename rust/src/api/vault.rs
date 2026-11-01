//! [`Vault`]: the one handle Dart holds. Each method maps DTOs onto the
//! `chora` library (`store`, `note`, `edit`, `conflict`, `calendar`).

use std::path::PathBuf;

use chora::calendar::{load_marks, month_grid};
use chora::edit::{self, EventFile};
use chora::index::{AccessLevel, Index};
use chora::store::Store;
use chora::{conflict, fsx, note};
use chrono::Datelike;
use flutter_rust_bridge::frb;

use crate::api::convert::{self, date, iso};
use crate::api::error::{ApiError, ApiResult};
use crate::api::types::{
    AgentTask, CalendarCellDto, ConflictChoice, ConflictDto, EventDto, EventSource, NoteCapture,
    NoteDto, OldEventPolicy, ProjectDto, SecurityLevel, SweepDto, Weekday,
};

/// Longest range one [`Vault::range`] call may read, in days.
const MAX_RANGE_DAYS: i64 = 92;
const DEFAULT_STIGNORE: &str = ".git\nsync.log\n*.swp\n*~\n*.tmp\n.DS_Store\n";

/// Bridge setup (thread pool, panic hook). Runs once from `RustLib.init`.
#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// An opened storage root (`notes/`, `events/`, `to-agent/`, `index.md`).
#[frb(opaque)]
pub struct Vault {
    root: PathBuf,
}

impl Vault {
    /// Open an absolute storage path; lays out a new one (never overwrites `.stignore`).
    pub fn open(root: String) -> ApiResult<Vault> {
        let root = PathBuf::from(root.trim());
        if !root.is_absolute() {
            return Err(ApiError::invalid(format!(
                "storage path must be absolute: {}",
                root.display()
            )));
        }
        let store = Store::new(&root);
        store.ensure_layout()?;
        std::fs::create_dir_all(store.to_agent_dir())?;
        let ignore = root.join(".stignore");
        if fsx::read_opt(&ignore)?.is_none() {
            fsx::write_atomic(&ignore, DEFAULT_STIGNORE)?;
        }
        Ok(Self { root })
    }

    /// Absolute storage path.
    #[frb(sync, getter)]
    pub fn root(&self) -> String {
        self.root.to_string_lossy().into_owned()
    }

    /// Metadata fingerprint; reload only when it changes.
    pub fn stamp(&self) -> ApiResult<u64> {
        self.run(|| Ok(conflict::stamp(&self.root)?))
    }

    /// All projects plus the loose files group, with headers per file
    /// (critical clearance: the Flutter gate decides what to show).
    pub fn projects(&self) -> ApiResult<Vec<ProjectDto>> {
        self.run(|| {
            let index = Index::load(&self.root)?;
            let mut out = Vec::new();
            for dir in note::top_dirs(&self.notes())? {
                let view =
                    note::dir_view(&self.root, &index, &dir, AccessLevel::Critical, true, &[])?;
                out.push(convert::project(view, false));
            }
            let loose = note::loose_files_view(&self.root, &index, AccessLevel::Critical, true)?;
            out.push(convert::project(loose, true));
            Ok(out)
        })
    }

    /// One note by path relative to `notes/`.
    pub fn read_note(&self, rel_path: String) -> ApiResult<NoteDto> {
        self.run(|| {
            let path = note::join_safe(&self.notes(), &rel_path)?;
            let text = fsx::read_opt(&path)?
                .ok_or_else(|| ApiError::not_found(format!("no note {rel_path}")))?;
            let index = Index::load(&self.root)?;
            Ok(NoteDto {
                security: SecurityLevel::from(index.security_for(&rel_path)),
                about: index.about_for(&rel_path).to_owned(),
                rel_path,
                text,
            })
        })
    }

    /// Overwrite a note; `base` is the text it was edited from (`Changed` when the file moved on).
    pub fn save_note(&self, rel_path: String, text: String, base: String) -> ApiResult<()> {
        self.run(|| {
            note::require_md(&rel_path)?;
            Ok(edit::save_note(
                &note::join_safe(&self.notes(), &rel_path)?,
                &rel_path,
                &text,
                &base,
            )?)
        })
    }

    /// Flip the task checkbox on raw line `line` of `base`; returns the new text.
    pub fn toggle_task(&self, rel_path: String, line: u32, base: String) -> ApiResult<String> {
        self.run(|| {
            let path = note::join_safe(&self.notes(), &rel_path)?;
            Ok(edit::toggle_task(&path, &rel_path, line as usize, &base)?)
        })
    }

    /// Append a capture (default `inbox.md`); returns the path relative to `notes/`.
    pub fn capture_note(&self, capture: NoteCapture) -> ApiResult<String> {
        self.run(|| {
            let (title, body) = (capture.title.trim(), capture.body.trim());
            let block = match (title.is_empty(), body.is_empty()) {
                (true, true) => {
                    return Err(ApiError::invalid("capture is empty: add a title or text"));
                }
                (true, false) => body.to_owned(),
                (false, true) => format!("## {title}"),
                (false, false) => format!("## {title}\n\n{body}"),
            };
            let rel = non_empty(capture.note_path.as_deref()).unwrap_or("inbox.md");
            note::require_md(rel)?;
            let path = note::join_safe(&self.notes(), rel)?;
            edit::append_note(&path, rel, non_empty(capture.header.as_deref()), &block)?;
            Ok(rel.to_owned())
        })
    }

    /// Write a task for the agent; returns the path relative to the root.
    pub fn delegate(&self, task: AgentTask) -> ApiResult<String> {
        self.run(|| {
            let title = task.title.trim();
            if title.is_empty() {
                return Err(ApiError::invalid("a task for the agent needs a title"));
            }
            let path = Store::new(&self.root).write_agent_task(
                chrono::Local::now().date_naive(),
                title,
                task.priority.as_str(),
                non_empty(task.project.as_deref()),
                &task.body,
            )?;
            Ok(note::rel_of(&self.root, &path))
        })
    }

    /// 42 month-grid cells with first-event titles.
    pub fn month(
        &self,
        year: i32,
        month: u32,
        show_weekly: bool,
    ) -> ApiResult<Vec<CalendarCellDto>> {
        self.run(|| {
            let cells =
                month_grid(year, month).ok_or_else(|| ApiError::invalid("month out of range"))?;
            let marks = load_marks(&self.root, year, month, show_weekly)?;
            Ok(cells
                .into_iter()
                .zip(marks)
                .map(|(cell, mark)| CalendarCellDto {
                    date_iso: iso(cell.date),
                    day: cell.date.day(),
                    in_month: cell.current,
                    day_title: mark.day_title,
                    repeat_title: mark.repeat_title,
                })
                .collect())
        })
    }

    /// Events of one day (day file + weekly), by start time.
    pub fn day(&self, date_iso: String) -> ApiResult<Vec<EventDto>> {
        self.run(|| self.events_on(date(&date_iso)?))
    }

    /// Events of every day in `from..=to` (at most 92 days), by date then time.
    pub fn range(&self, from_iso: String, to_iso: String) -> ApiResult<Vec<EventDto>> {
        self.run(|| {
            let (from, to) = (date(&from_iso)?, date(&to_iso)?);
            let span = (to - from).num_days();
            if !(0..MAX_RANGE_DAYS).contains(&span) {
                return Err(ApiError::invalid(format!(
                    "range must be 1..={MAX_RANGE_DAYS} days"
                )));
            }
            let mut out = Vec::new();
            for day in from.iter_days().take(span as usize + 1) {
                out.extend(self.events_on(day)?);
            }
            Ok(out)
        })
    }

    /// Weekly events of `weekday`, dated on its next occurrence from today.
    pub fn weekly(&self, weekday: Weekday) -> ApiResult<Vec<EventDto>> {
        self.run(|| {
            let target = convert::weekday(weekday);
            let today = chrono::Local::now().date_naive();
            let ahead =
                (7 + target.num_days_from_monday() - today.weekday().num_days_from_monday()) % 7;
            let date = today + chrono::Days::new(u64::from(ahead));
            let store = Store::new(&self.root);
            Ok(edit::read_events(&store, EventFile::Weekly(target), date)?
                .iter()
                .enumerate()
                .map(|(i, ev)| convert::to_dto(ev, EventSource::Weekly, i))
                .collect())
        })
    }

    /// Add an event (`index` ignored).
    pub fn add_event(&self, event: EventDto) -> ApiResult<()> {
        self.run(|| {
            let (file, ev) = convert::from_dto(&event)?;
            Ok(edit::add_event(&Store::new(&self.root), file, &ev)?)
        })
    }

    /// Replace `original` (exactly as read) with `updated`; moves across days and weekly.
    pub fn update_event(&self, original: EventDto, updated: EventDto) -> ApiResult<()> {
        self.run(|| {
            let (from, expected) = convert::from_dto(&original)?;
            let (to, ev) = convert::from_dto(&updated)?;
            let store = Store::new(&self.root);
            Ok(edit::update_event(
                &store,
                from,
                &expected,
                original.index as usize,
                to,
                &ev,
            )?)
        })
    }

    /// Delete `original` (exactly as read).
    pub fn delete_event(&self, original: EventDto) -> ApiResult<()> {
        self.run(|| {
            let (file, expected) = convert::from_dto(&original)?;
            Ok(edit::delete_event(
                &Store::new(&self.root),
                file,
                &expected,
                original.index as usize,
            )?)
        })
    }

    /// Syncthing conflict copies.
    pub fn conflicts(&self) -> ApiResult<Vec<ConflictDto>> {
        self.run(|| {
            Ok(conflict::list(&self.root)?
                .into_iter()
                .map(|c| ConflictDto {
                    path: c.path,
                    original: c.original,
                })
                .collect())
        })
    }

    /// Resolve one conflict copy (path relative to the root).
    pub fn resolve_conflict(&self, path: String, choice: ConflictChoice) -> ApiResult<()> {
        self.run(|| {
            Ok(conflict::resolve(
                &self.root,
                &path,
                choice == ConflictChoice::KeepCopy,
            )?)
        })
    }

    /// Delete or archive past day files.
    pub fn sweep_old_events(&self, policy: OldEventPolicy) -> ApiResult<SweepDto> {
        use chora::config::OldEventPolicy as Policy;
        self.run(|| {
            let policy = match policy {
                OldEventPolicy::Keep => Policy::Nothing,
                OldEventPolicy::Backlog => Policy::Backlog,
                OldEventPolicy::Delete => Policy::Delete,
            };
            let report = Store::new(&self.root)
                .sweep_old_events(policy, chrono::Local::now().date_naive())?;
            Ok(SweepDto {
                deleted: u32::try_from(report.deleted).unwrap_or(u32::MAX),
                backlogged: u32::try_from(report.backlogged).unwrap_or(u32::MAX),
            })
        })
    }

    /// Sample content for an empty storage; false when notes already exist.
    pub fn seed_demo(&self) -> ApiResult<bool> {
        self.run(|| crate::api::demo::seed(&self.root, chrono::Local::now().date_naive()))
    }

    fn notes(&self) -> PathBuf {
        self.root.join("notes")
    }

    /// Day-file events plus the weekday's weekly events, by start time.
    fn events_on(&self, day: chrono::NaiveDate) -> ApiResult<Vec<EventDto>> {
        let store = Store::new(&self.root);
        let mut out = Vec::new();
        for (file, source) in [
            (EventFile::Day(day), EventSource::Day),
            (EventFile::Weekly(day.weekday()), EventSource::Weekly),
        ] {
            let events = edit::read_events(&store, file, day)?;
            out.extend(
                events
                    .iter()
                    .enumerate()
                    .map(|(i, ev)| convert::to_dto(ev, source, i)),
            );
        }
        out.sort_by_key(|dto| dto.start_min);
        Ok(out)
    }

    /// Run a call; error messages show paths relative to the root.
    fn run<T>(&self, call: impl FnOnce() -> ApiResult<T>) -> ApiResult<T> {
        call().map_err(|err| {
            let prefix = format!("{}/", self.root.display());
            ApiError::new(err.kind, err.message.replace(&prefix, ""))
        })
    }
}

fn non_empty(raw: Option<&str>) -> Option<&str> {
    raw.map(str::trim).filter(|s| !s.is_empty())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::error::ErrorKind;
    use crate::api::types::Priority;
    use std::sync::atomic::{AtomicU64, Ordering};

    static COUNTER: AtomicU64 = AtomicU64::new(0);

    fn vault() -> Vault {
        let dir = std::env::temp_dir().join(format!(
            "chora-mobile-test-{}-{}",
            std::process::id(),
            COUNTER.fetch_add(1, Ordering::SeqCst)
        ));
        let _ = std::fs::remove_dir_all(&dir);
        Vault::open(dir.to_string_lossy().into_owned()).unwrap()
    }

    fn ev(title: &str, date: &str, start_min: u32, source: EventSource) -> EventDto {
        EventDto {
            title: title.into(),
            date_iso: date.into(),
            start_min,
            duration_secs: 1800,
            context: String::new(),
            source,
            index: 0,
        }
    }

    fn titles(v: &Vault, date: &str) -> Vec<String> {
        v.day(date.into())
            .unwrap()
            .into_iter()
            .map(|e| e.title)
            .collect()
    }

    #[test]
    fn open_lays_out_and_rejects_relative_paths() {
        let v = vault();
        for dir in ["events", "notes", "to-agent"] {
            assert!(v.root.join(dir).is_dir(), "{dir}");
        }
        assert!(v.root.join(".stignore").is_file());
        assert!(Vault::open("relative/dir".into()).is_err());
    }

    #[test]
    fn capture_lands_under_header_and_errors_are_relative() {
        let v = vault();
        let capture = |title: &str, path: Option<&str>, header: Option<&str>| NoteCapture {
            title: title.into(),
            body: String::new(),
            note_path: path.map(Into::into),
            header: header.map(Into::into),
        };
        assert_eq!(
            v.capture_note(capture("Idea", None, None)).unwrap(),
            "inbox.md"
        );
        let todo = "# Todo\n\n## Tasks\n\n## Bugs\n";
        v.save_note("w/todo.md".into(), todo.into(), String::new())
            .unwrap();
        v.capture_note(capture("New", Some("w/todo.md"), Some("Tasks")))
            .unwrap();
        let text = v.read_note("w/todo.md".into()).unwrap().text;
        assert!(
            text.find("## New").unwrap() < text.find("## Bugs").unwrap(),
            "{text}"
        );
        assert!(v.capture_note(capture("", None, None)).is_err());
        assert!(
            v.capture_note(capture("x", Some("../evil.md"), None))
                .is_err()
        );
        let err = v
            .save_note("w/todo.md".into(), "x".into(), "stale".into())
            .unwrap_err();
        assert_eq!(err.kind, ErrorKind::Changed);
        assert!(!err.message.contains(&v.root()), "{}", err.message);
    }

    #[test]
    fn events_move_between_days_and_weekly_by_value() {
        let v = vault();
        v.add_event(ev("A1", "2026-11-02", 600, EventSource::Day))
            .unwrap();
        v.add_event(ev("A2", "2026-11-02", 700, EventSource::Day))
            .unwrap();
        v.add_event(ev("B1", "2026-11-03", 600, EventSource::Day))
            .unwrap();
        let a2 = v.day("2026-11-02".into()).unwrap().remove(1);
        let mut moved = a2.clone();
        moved.date_iso = "2026-11-03".into();
        v.update_event(a2.clone(), moved).unwrap();
        assert_eq!(titles(&v, "2026-11-02"), ["A1"]);
        assert_eq!(titles(&v, "2026-11-03"), ["B1", "A2"]);
        let err = v.delete_event(a2).unwrap_err();
        assert_eq!(err.kind, ErrorKind::Changed);
        let a1 = v.day("2026-11-02".into()).unwrap().remove(0);
        let mut weekly = a1.clone();
        weekly.source = EventSource::Weekly;
        v.update_event(a1, weekly).unwrap();
        assert_eq!(titles(&v, "2026-11-09"), ["A1"], "Mondays repeat it");
        assert_eq!(
            v.range("2026-11-01".into(), "2026-11-09".into())
                .unwrap()
                .len(),
            4
        );
        assert!(v.range("2026-11-09".into(), "2026-11-01".into()).is_err());
        assert!(
            v.add_event(ev(" ", "2026-11-02", 600, EventSource::Day))
                .is_err()
        );
        assert!(
            v.add_event(ev("x", "2026-11-02", 24 * 60, EventSource::Day))
                .is_err()
        );
    }

    #[test]
    fn projects_toggle_delegate_conflicts_demo() {
        let v = vault();
        assert!(v.seed_demo().unwrap());
        assert!(!v.seed_demo().unwrap());
        let projects = v.projects().unwrap();
        assert_eq!(
            projects.last().map(|p| (p.is_loose, p.about.as_str())),
            Some((true, ""))
        );
        // demo projects sort as home, work, loose: work/todo.md has `# Todo`.
        let work = projects.iter().find(|p| p.name == "work").unwrap();
        let todo_file = work.files.iter().find(|f| f.name == "todo.md").unwrap();
        assert_eq!(todo_file.title, "Todo");
        let todo = v.read_note("work/todo.md".into()).unwrap().text;
        let line = todo.lines().position(|l| l.starts_with("- [ ]")).unwrap() as u32;
        assert!(
            v.toggle_task("work/todo.md".into(), line, todo)
                .unwrap()
                .contains("- [x] Review")
        );
        let task = AgentTask {
            title: "Fix".into(),
            body: String::new(),
            priority: Priority::High,
            project: None,
        };
        assert!(v.delegate(task).unwrap().starts_with("to-agent/"));
        let copy = "notes/inbox.sync-conflict-20261101-101010-ABC.md";
        std::fs::write(v.root.join(copy), "theirs").unwrap();
        assert_eq!(v.conflicts().unwrap()[0].original, "notes/inbox.md");
        v.resolve_conflict(copy.into(), ConflictChoice::KeepCopy)
            .unwrap();
        assert_eq!(v.read_note("inbox.md".into()).unwrap().text, "theirs");
        let before = v.stamp().unwrap();
        assert_eq!(before, v.stamp().unwrap());
    }
}
