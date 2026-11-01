//! DTO <-> `chora` type mapping. No IO, no decisions.

use std::time::Duration;

use chora::edit::{self, EventFile};
use chora::event::Event;
use chora::note::DirView;
use chrono::{NaiveDate, NaiveTime, Timelike};

use crate::api::error::{ApiError, ApiResult};
use crate::api::types::{EventDto, EventSource, NoteFileDto, ProjectDto, Weekday};

pub(crate) fn project(view: DirView, is_loose: bool) -> ProjectDto {
    ProjectDto {
        name: if is_loose { String::new() } else { view.dir },
        is_loose,
        security: view.security.into(),
        // The loose group's about is chora CLI wording, not UI text.
        about: if is_loose { String::new() } else { view.about },
        files: view
            .files
            .into_iter()
            .map(|file| NoteFileDto {
                name: file
                    .path
                    .rsplit('/')
                    .next()
                    .unwrap_or(&file.path)
                    .to_owned(),
                title: chora::note::first_h1(&file.body).unwrap_or_default(),
                headers: chora::note::read_headers(&file.body)
                    .into_iter()
                    .map(|h| h.title)
                    .collect(),
                rel_path: file.path,
                security: file.security.into(),
                about: file.about,
            })
            .collect(),
    }
}

pub(crate) fn to_dto(ev: &Event, source: EventSource, index: usize) -> EventDto {
    EventDto {
        title: ev.title.clone(),
        date_iso: iso(ev.date),
        start_min: ev.time.hour() * 60 + ev.time.minute(),
        duration_secs: u32::try_from(ev.duration.as_secs()).unwrap_or(u32::MAX),
        context: ev.context.clone(),
        source,
        index: u32::try_from(index).unwrap_or(u32::MAX),
    }
}

/// Validated event plus the file it belongs to.
pub(crate) fn from_dto(dto: &EventDto) -> ApiResult<(EventFile, Event)> {
    let title = dto.title.split_whitespace().collect::<Vec<_>>().join(" ");
    if title.is_empty() || title.starts_with('#') {
        return Err(ApiError::invalid("event needs a title"));
    }
    let time = NaiveTime::from_hms_opt(dto.start_min / 60, dto.start_min % 60, 0)
        .ok_or_else(|| ApiError::invalid("start time out of range"))?;
    if dto.duration_secs == 0 {
        return Err(ApiError::invalid("duration must be positive"));
    }
    let ev = Event {
        title,
        date: date(&dto.date_iso)?,
        time,
        duration: Duration::from_secs(u64::from(dto.duration_secs)),
        context: dto.context.trim().to_owned(),
    };
    Ok((edit::file_of(&ev, dto.source == EventSource::Weekly), ev))
}

pub(crate) fn date(raw: &str) -> ApiResult<NaiveDate> {
    NaiveDate::parse_from_str(raw.trim(), "%Y-%m-%d")
        .map_err(|_| ApiError::invalid(format!("bad date \"{raw}\", expected YYYY-MM-DD")))
}

pub(crate) fn iso(date: NaiveDate) -> String {
    date.format("%Y-%m-%d").to_string()
}

pub(crate) fn weekday(day: Weekday) -> chrono::Weekday {
    match day {
        Weekday::Monday => chrono::Weekday::Mon,
        Weekday::Tuesday => chrono::Weekday::Tue,
        Weekday::Wednesday => chrono::Weekday::Wed,
        Weekday::Thursday => chrono::Weekday::Thu,
        Weekday::Friday => chrono::Weekday::Fri,
        Weekday::Saturday => chrono::Weekday::Sat,
        Weekday::Sunday => chrono::Weekday::Sun,
    }
}
