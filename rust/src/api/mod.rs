//! Bridge surface scanned by `flutter_rust_bridge`: DTOs, the error type and
//! the [`vault::Vault`] handle. Domain logic lives in the `chora` crate; this
//! module only maps between it and the DTOs.

mod convert;
mod demo;
pub mod error;
pub mod types;
pub mod vault;
