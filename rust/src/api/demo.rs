//! Sample content for a first look at an empty storage (debug builds offer it).

use std::path::Path;

use chora::edit::{self, EventFile};
use chora::event::Event;
use chora::fsx;
use chora::store::Store;
use chrono::{NaiveDate, NaiveTime};

use crate::api::error::ApiResult;

const NOTES: [(&str, &str); 4] = [
    (
        "work/todo.md",
        "# Todo\n\n## Tasks\n\n- [ ] Review the new capture flow\n- [x] Read the storage spec\n\n## Bugs\n\n- [ ] Checkbox tap area too small\n",
    ),
    (
        "work/guides/deploy.md",
        "# Deploy\n\n## Steps\n\n1. Build the APK\n2. Install on the device\n",
    ),
    (
        "home/shopping.md",
        "# Shopping\n\n- [ ] Milk\n- [ ] Bread\n- [ ] Coffee\n",
    ),
    ("inbox.md", "# Inbox\n"),
];

/// Write sample notes and events unless `notes/` already has content.
pub(crate) fn seed(root: &Path, today: NaiveDate) -> ApiResult<bool> {
    let notes = root.join("notes");
    if std::fs::read_dir(&notes).is_ok_and(|mut dir| dir.next().is_some()) {
        return Ok(false);
    }
    for (rel, text) in NOTES {
        fsx::write_atomic(&notes.join(rel), text)?;
    }
    let tomorrow = today.succ_opt().unwrap_or(today);
    let store = Store::new(root);
    let samples = [
        ("Standup", today, (11, 0), 15, "What is cooking.", false),
        ("Demo day", today, (15, 0), 60, "Show the app.", false),
        ("Dentist", tomorrow, (9, 30), 45, "", false),
        ("Gym", today, (19, 0), 90, "Legs day.", true),
    ];
    for (title, date, (h, m), minutes, context, weekly) in samples {
        let ev = Event {
            title: title.into(),
            date,
            time: NaiveTime::from_hms_opt(h, m, 0).unwrap_or_default(),
            duration: std::time::Duration::from_secs(minutes * 60),
            context: context.into(),
        };
        let file = if weekly {
            edit::file_of(&ev, true)
        } else {
            EventFile::Day(date)
        };
        edit::add_event(&store, file, &ev)?;
    }
    Ok(true)
}
