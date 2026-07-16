//! Cross-platform application directory resolution.
//!
//! We deliberately use XDG-style paths (`$XDG_CONFIG_HOME` / `~/.config` and
//! `$XDG_CACHE_HOME` / `~/.cache`) on *all* Unix platforms, macOS included —
//! not the platform-native `~/Library/...` dirs a crate like `directories`
//! would return on macOS.
//!
//! Rationale: the credential files this widget reads
//! (`~/.claude/.credentials.json`, `~/.codex/auth.json`) follow the dotfile
//! convention on macOS too, and every user-facing message and the README
//! document `~/.config/ai-usagebar` / `~/.cache/ai-usagebar`. Using
//! `~/Library/...` would silently diverge from all of that. On Linux, with
//! `$HOME` set, this matches what `directories::BaseDirs` returned before; we
//! deliberately don't replicate that crate's `getpwuid` fallback for the rare
//! case where `$HOME` is unset (the widget then shows its `⚠` fallback).

use std::path::PathBuf;

use crate::error::{AppError, Result};

const APP_DIR: &str = "ai-usagebar";

/// Resolve a home directory from a `$HOME` value. Split from env reading so
/// tests exercise the logic without mutating the process-global environment
/// (which is UB under multi-threaded `cargo test`).
fn home_from(raw: Option<std::ffi::OsString>) -> Result<PathBuf> {
    raw.map(PathBuf::from)
        .filter(|h| !h.as_os_str().is_empty())
        .ok_or_else(|| AppError::Other("could not resolve HOME".into()))
}

/// Resolve an XDG base dir from `$VAR` (used only when it holds an absolute
/// path, per the XDG spec) falling back to `$HOME/<fallback>`.
fn xdg_base(var: &str, fallback: &str) -> Result<PathBuf> {
    xdg_base_from(std::env::var_os(var), std::env::var_os("HOME"), fallback)
}

/// Pure core of [`xdg_base`] — tested directly, without touching global env.
fn xdg_base_from(
    var: Option<std::ffi::OsString>,
    home: Option<std::ffi::OsString>,
    fallback: &str,
) -> Result<PathBuf> {
    if let Some(v) = var {
        let p = PathBuf::from(v);
        if p.is_absolute() {
            return Ok(p);
        }
    }
    Ok(home_from(home)?.join(fallback))
}

/// Base cache directory (no app segment): `$XDG_CACHE_HOME` or `~/.cache`.
pub fn cache_base() -> Result<PathBuf> {
    xdg_base("XDG_CACHE_HOME", ".cache")
}

/// Application config directory: `$XDG_CONFIG_HOME/ai-usagebar` or
/// `~/.config/ai-usagebar`.
pub fn config_dir() -> Result<PathBuf> {
    Ok(xdg_base("XDG_CONFIG_HOME", ".config")?.join(APP_DIR))
}

/// Application config file: `<config_dir>/config.toml`.
pub fn config_file() -> Result<PathBuf> {
    Ok(config_dir()?.join("config.toml"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::OsString;

    fn os(s: &str) -> OsString {
        OsString::from(s)
    }

    #[test]
    fn xdg_prefers_absolute_var() {
        assert_eq!(
            xdg_base_from(Some(os("/xdg/cache")), Some(os("/home/u")), ".cache").unwrap(),
            PathBuf::from("/xdg/cache")
        );
    }

    #[test]
    fn xdg_falls_back_to_home_dotdir() {
        assert_eq!(
            xdg_base_from(None, Some(os("/home/u")), ".cache").unwrap(),
            PathBuf::from("/home/u/.cache")
        );
    }

    #[test]
    fn relative_or_empty_var_is_ignored_per_spec() {
        // XDG spec: a non-absolute value must be ignored.
        assert_eq!(
            xdg_base_from(Some(os("relative/path")), Some(os("/home/u")), ".config").unwrap(),
            PathBuf::from("/home/u/.config")
        );
        assert_eq!(
            xdg_base_from(Some(os("")), Some(os("/home/u")), ".cache").unwrap(),
            PathBuf::from("/home/u/.cache")
        );
    }

    #[test]
    fn home_unset_or_empty_errors() {
        assert!(home_from(None).is_err());
        assert!(home_from(Some(os(""))).is_err());
        assert_eq!(
            home_from(Some(os("/home/u"))).unwrap(),
            PathBuf::from("/home/u")
        );
    }
}
