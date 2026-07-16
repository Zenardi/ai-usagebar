# PREFIX defaults to /usr/local. On Apple Silicon macOS, Homebrew lives under
# /opt/homebrew, so use `make install PREFIX=/opt/homebrew` (or $HOME/.local).
PREFIX ?= /usr/local

.PHONY: build install uninstall test smoke clippy fmt clean

build:
	cargo build --release

# `install -D` (auto-create parent dirs) is a GNU coreutils extension that BSD
# `install` (macOS) lacks, so create the dirs explicitly and use the portable
# `-m MODE` form that both GNU and BSD install accept.
install: build
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	mkdir -p $(DESTDIR)$(PREFIX)/share/ai-usagebar
	mkdir -p $(DESTDIR)$(PREFIX)/share/doc/ai-usagebar
	mkdir -p $(DESTDIR)$(PREFIX)/share/licenses/ai-usagebar
	install -m 755 target/release/ai-usagebar     $(DESTDIR)$(PREFIX)/bin/ai-usagebar
	install -m 755 target/release/ai-usagebar-tui $(DESTDIR)$(PREFIX)/bin/ai-usagebar-tui
	install -m 644 config.example.toml            $(DESTDIR)$(PREFIX)/share/ai-usagebar/config.example.toml
	install -m 644 README.md                      $(DESTDIR)$(PREFIX)/share/doc/ai-usagebar/README.md
	install -m 644 LICENSE                        $(DESTDIR)$(PREFIX)/share/licenses/ai-usagebar/LICENSE

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/ai-usagebar
	rm -f $(DESTDIR)$(PREFIX)/bin/ai-usagebar-tui
	rm -rf $(DESTDIR)$(PREFIX)/share/ai-usagebar
	rm -rf $(DESTDIR)$(PREFIX)/share/doc/ai-usagebar
	rm -rf $(DESTDIR)$(PREFIX)/share/licenses/ai-usagebar

test:
	cargo test

smoke:
	@echo "Running live API smoke tests (requires creds in shell env)..."
	cargo test --test live -- --ignored --nocapture

clippy:
	cargo clippy --all-targets -- -D warnings

fmt:
	cargo fmt

clean:
	cargo clean
