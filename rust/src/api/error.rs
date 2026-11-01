//! The one error type that crosses the bridge. Dart switches on [`ErrorKind`]
//! and shows [`ApiError::message`] as-is.

use chora::error::ChoraError;

/// What went wrong, so the UI can branch without parsing text.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrorKind {
    /// Bad input from the UI: date, time, duration, path, empty title.
    Invalid,
    /// The file or section does not exist.
    NotFound,
    /// The file changed on disk since the UI read it (sync). Reload, then retry.
    Changed,
    /// Disk or permission failure.
    Io,
}

/// Error returned by every fallible bridge call.
#[derive(Debug, Clone)]
pub struct ApiError {
    /// Category for UI branching.
    pub kind: ErrorKind,
    /// One human-readable line.
    pub message: String,
}

/// Result of every fallible bridge call.
pub type ApiResult<T> = Result<T, ApiError>;

impl ApiError {
    pub(crate) fn new(kind: ErrorKind, message: impl Into<String>) -> Self {
        Self {
            kind,
            message: message.into(),
        }
    }

    pub(crate) fn invalid(message: impl Into<String>) -> Self {
        Self::new(ErrorKind::Invalid, message)
    }

    pub(crate) fn not_found(message: impl Into<String>) -> Self {
        Self::new(ErrorKind::NotFound, message)
    }
}

impl From<std::io::Error> for ApiError {
    fn from(err: std::io::Error) -> Self {
        let kind = match err.kind() {
            std::io::ErrorKind::NotFound => ErrorKind::NotFound,
            _ => ErrorKind::Io,
        };
        Self::new(kind, err.to_string())
    }
}

impl From<ChoraError> for ApiError {
    fn from(err: ChoraError) -> Self {
        Self::from(anyhow::Error::from(err))
    }
}

impl From<anyhow::Error> for ApiError {
    fn from(err: anyhow::Error) -> Self {
        let message = format!("{err:#}");
        match err.downcast_ref::<ChoraError>() {
            Some(ChoraError::Changed(_)) => return Self::new(ErrorKind::Changed, message),
            Some(_) => return Self::invalid(message),
            None => {}
        }
        let io = err
            .chain()
            .find_map(|cause| cause.downcast_ref::<std::io::Error>());
        let kind = match io.map(std::io::Error::kind) {
            Some(std::io::ErrorKind::NotFound) => ErrorKind::NotFound,
            _ => ErrorKind::Io,
        };
        Self::new(kind, message)
    }
}
