# Homebrew formula for ai-usagebar (prebuilt-binary — parallels the AUR
# `ai-usagebar-bin` package). This is the TEMPLATE kept in the main repo; the
# live copy belongs in the tap repo `Zenardi/homebrew-tap` so users can run
# `brew install Zenardi/tap/ai-usagebar`.
#
# Release process (see CLAUDE.md): after CI publishes the vX.Y.Z release, bump
# `version` here and replace the `sha256` placeholder with the real digest from
# the `ai-usagebar-darwin-arm64.tar.gz.sha256` asset, then push to the tap repo.
#
# Apple Silicon only — CI publishes an arm64 tarball. Intel Macs build from
# source (`cargo build --release`); GitHub's Intel macOS runners are scarce.
class AiUsagebar < Formula
  desc "Status-bar widget and tabbed TUI for AI plan usage (Anthropic/OpenAI/Z.AI/OpenRouter)"
  homepage "https://github.com/Zenardi/ai-usagebar"
  version "0.5.0"
  license "MIT"
  depends_on :macos
  depends_on arch: :arm64

  url "https://github.com/Zenardi/ai-usagebar/releases/download/v#{version}/ai-usagebar-darwin-arm64.tar.gz"
  sha256 "a939cfd81c76ee5f0dbbb3946d0d4ebe7730061bcccddb4e4ba215f9a6cdca2e"

  def install
    bin.install "ai-usagebar"
    bin.install "ai-usagebar-tui"
    pkgshare.install "config.example.toml"
    doc.install "README.md"
  end

  def caveats
    <<~EOS
      Anthropic/OpenAI use OAuth from the official CLIs — run `claude` and
      `codex login` once. Z.AI/OpenRouter use API keys (env var or config).

      For a SketchyBar module see packaging/sketchybar/ in the repo, and set
      under [ui] in ~/.config/ai-usagebar/config.toml:
        refresh_command = "sketchybar --trigger aibar_refresh"
    EOS
  end

  test do
    assert_match "ai-usagebar", shell_output("#{bin}/ai-usagebar --help")
  end
end
