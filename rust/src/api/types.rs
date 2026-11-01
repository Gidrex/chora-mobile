//! Plain data that crosses the bridge. No logic beyond conversions.

use chora::index::AccessLevel;

/// Effective visibility of a note, from `index.md`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SecurityLevel {
    /// Visible without a gate.
    Open,
    /// Gated when the app threshold is `restricted` or lower.
    Restricted,
    /// Gated unless the app threshold is `none`.
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

/// One `.md` file inside a project.
#[derive(Debug, Clone)]
pub struct NoteFileDto {
    /// Path relative to `notes/`, e.g. `work/guides/deploy.md`.
    pub rel_path: String,
    /// File name only, e.g. `deploy.md`.
    pub name: String,
    /// The file's own `# h1`, else empty.
    pub title: String,
    /// Effective level from `index.md`.
    pub security: SecurityLevel,
    /// Explicit `about:` or the file's own h1, else empty.
    pub about: String,
    /// `#` header titles in file order, for section autocomplete.
    pub headers: Vec<String>,
}

/// One top-level `notes/<dir>`, or the loose `notes/*.md` files.
#[derive(Debug, Clone)]
pub struct ProjectDto {
    /// Dir name; empty for loose files.
    pub name: String,
    /// True for the group of loose `notes/*.md` files.
    pub is_loose: bool,
    /// Effective level of the dir itself.
    pub security: SecurityLevel,
    /// Explicit `about:` of the dir, else empty.
    pub about: String,
    /// Files under the dir, recursive.
    pub files: Vec<NoteFileDto>,
}

/// Full contents of one note file.
#[derive(Debug, Clone)]
pub struct NoteDto {
    /// Path relative to `notes/`.
    pub rel_path: String,
    /// Raw markdown. Pass it back as `base` when writing.
    pub text: String,
    /// Effective level from `index.md`.
    pub security: SecurityLevel,
    /// Explicit `about:` or the file's own h1, else empty.
    pub about: String,
}

/// Which file an event lives in.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EventSource {
    /// `events/YYYY-MM-DD.md`.
    Day,
    /// `events/repeatable/<weekday>.md`, the weekday of `date_iso`.
    Weekly,
}

/// One calendar event. Pass a read event back unchanged as `original`
/// to update or delete it; the backend refuses when the file changed since.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EventDto {
    /// The `##` header.
    pub title: String,
    /// `YYYY-MM-DD`. For weekly events, the date it is shown on.
    pub date_iso: String,
    /// Start, minutes since midnight.
    pub start_min: u32,
    /// Length in seconds, at least 1.
    pub duration_secs: u32,
    /// Free text below `Time:`/`Duration:`.
    pub context: String,
    /// Day file or weekly file.
    pub source: EventSource,
    /// Position among the valid events of its file (time order); ignored on create.
    pub index: u32,
}

/// One of the 42 month-grid cells.
#[derive(Debug, Clone)]
pub struct CalendarCellDto {
    /// `YYYY-MM-DD`.
    pub date_iso: String,
    /// Day of month.
    pub day: u32,
    /// True when the date belongs to the shown month.
    pub in_month: bool,
    /// First day-file event title, if any.
    pub day_title: Option<String>,
    /// First weekly event title, if any (only when requested).
    pub repeat_title: Option<String>,
}

/// Priority of a task delegated to the agent inbox.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Priority {
    /// Low.
    Low,
    /// Medium.
    Medium,
    /// High.
    High,
    /// Urgent.
    Urgent,
}

impl Priority {
    pub(crate) fn as_str(self) -> &'static str {
        match self {
            Self::Low => "low",
            Self::Medium => "medium",
            Self::High => "high",
            Self::Urgent => "urgent",
        }
    }
}

/// Append a block to a note (default `inbox.md`), optionally under a header.
#[derive(Debug, Clone)]
pub struct NoteCapture {
    /// Becomes a `## title` line; may be empty when `body` is not.
    pub title: String,
    /// Markdown body.
    pub body: String,
    /// Target relative to `notes/`; `None` = `inbox.md`.
    pub note_path: Option<String>,
    /// Existing header to append under (`Header` or `Parent/Child`).
    pub header: Option<String>,
}

/// A task file for the PC agent in `to-agent/`.
#[derive(Debug, Clone)]
pub struct AgentTask {
    /// Task title (required).
    pub title: String,
    /// Markdown body.
    pub body: String,
    /// Stored in the file header.
    pub priority: Priority,
    /// Related note path, stored as `Project:`.
    pub project: Option<String>,
}

/// One Syncthing conflict copy.
#[derive(Debug, Clone)]
pub struct ConflictDto {
    /// Conflict copy, relative to the storage root.
    pub path: String,
    /// The file it conflicts with, relative to the storage root.
    pub original: String,
}

/// How to resolve a conflict copy.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConflictChoice {
    /// Keep the current file, delete the copy.
    KeepCurrent,
    /// Replace the current file with the copy.
    KeepCopy,
}

/// What to do with past day files.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OldEventPolicy {
    /// Leave them.
    Keep,
    /// Move them to `events/backlog/`.
    Backlog,
    /// Delete them.
    Delete,
}

/// Result of a sweep over past day files.
#[derive(Debug, Clone, Copy)]
pub struct SweepDto {
    /// Day files deleted.
    pub deleted: u32,
    /// Day files moved to the backlog.
    pub backlogged: u32,
}

/// Day of week for weekly events.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Weekday {
    /// Monday.
    Monday,
    /// Tuesday.
    Tuesday,
    /// Wednesday.
    Wednesday,
    /// Thursday.
    Thursday,
    /// Friday.
    Friday,
    /// Saturday.
    Saturday,
    /// Sunday.
    Sunday,
}
