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
//! `~/Library/...` would silently diverge from all of that. On Linux this is
//! byte-identical to what `directories::BaseDirs` returned before.

use std::path::PathBuf;

use crate::error::{AppError, Result};

const APP_DIR: &str = "ai-usagebar";

fn home() -> Result<PathBuf> {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .filter(|h| !h.as_os_str().is_empty())
        .ok_or_else(|| AppError::Other("could not resolve HOME".into()))
}

/// Resolve an XDG base dir from `$VAR` (used only when it holds an absolute
/// path, per the XDG spec) falling back to `$HOME/<fallback>`.
fn xdg_base(var: &str, fallback: &str) -> Result<PathBuf> {
    if let Some(v) = std::env::var_os(var) {
        let p = PathBuf::from(v);
        if p.is_absolute() {
            return Ok(p);
        }
    }
    Ok(home()?.join(fallback))
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

    /// Guard against concurrent env mutation in this module's tests.
    fn with_env<F: FnOnce()>(vars: &[(&str, Option<&str>)], f: F) {
        use std::sync::Mutex;
        static LOCK: Mutex<()> = Mutex::new(());
        let _g = LOCK.lock().unwrap();

        let saved: Vec<(String, Option<std::ffi::OsString>)> = vars
            .iter()
            .map(|(k, _)| (k.to_string(), std::env::var_os(k)))
            .collect();
        for (k, v) in vars {
            match v {
                Some(val) => unsafe { std::env::set_var(k, val) },
                None => unsafe { std::env::remove_var(k) },
            }
        }
        f();
        for (k, v) in saved {
            match v {
                Some(val) => unsafe { std::env::set_var(&k, val) },
                None => unsafe { std::env::remove_var(&k) },
            }
        }
    }

    #[test]
    fn cache_base_prefers_xdg_when_absolute() {
        with_env(
            &[("XDG_CACHE_HOME", Some("/xdg/cache")), ("HOME", Some("/home/u"))],
            || {
                assert_eq!(cache_base().unwrap(), PathBuf::from("/xdg/cache"));
            },
        );
    }

    #[test]
    fn cache_base_falls_back_to_home_dotcache() {
        with_env(&[("XDG_CACHE_HOME", None), ("HOME", Some("/home/u"))], || {
            assert_eq!(cache_base().unwrap(), PathBuf::from("/home/u/.cache"));
        });
    }

    #[test]
    fn relative_xdg_is_ignored_per_spec() {
        with_env(
            &[("XDG_CONFIG_HOME", Some("relative/path")), ("HOME", Some("/home/u"))],
            || {
                assert_eq!(
                    config_dir().unwrap(),
                    PathBuf::from("/home/u/.config/ai-usagebar")
                );
            },
        );
    }

    #[test]
    fn config_file_is_under_config_dir() {
        with_env(&[("XDG_CONFIG_HOME", None), ("HOME", Some("/home/u"))], || {
            assert_eq!(
                config_file().unwrap(),
                PathBuf::from("/home/u/.config/ai-usagebar/config.toml")
            );
        });
    }
}
