# Markdown + Mermaid Tooling Exploration

Conversation transcript: 2026-05-06/07. Research and decisions on Neovim
markdown rendering, mermaid diagram support, and CLI preview tools.
Covers plugin selection, configuration, and the dependency on Kitty for
graphics-protocol features.

**Decisions recorded here supersede earlier notes in
`nix-home-manager-exploration.md` on the markdown tooling topic.**

---

## Starting point

Existing Neovim markdown stack at the start of this conversation:
- `render-markdown.nvim` — in-buffer rendering (headings, tables,
  callouts, bullets, code blocks). Well-tuned config. No mermaid support.
- `glow.nvim` — floating terminal preview via `glow` CLI (glamour library).
  Good for prose; does NOT render mermaid.
- `peek.nvim` — browser-based preview via Deno + local server. Installed
  but mermaid did not render (peek.nvim does not bundle mermaid.js).

Terminal context: WSL2 + Windows Terminal. No kitty graphics protocol.
Kitty available but not ergonomically set up (pre-GlazeWM).

---

## Constraint analysis

Three ways to display rendered mermaid in a terminal:

1. **Graphics protocol** (kitty/sixel) — renders mermaid → PNG in-buffer.
   Ruled out for now by Windows Terminal.
2. **ASCII/Unicode approximation** — text-art rendering. Exists but quality
   is poor for complex diagrams.
3. **Browser** — runs the mermaid.js layout engine. Best quality; leaves
   terminal.

Every plugin evaluated falls into one of these three categories.

---

## Plugin evaluations (Neovim)

### ascii-mermaid (kais-radwan/ascii-mermaid) ★ Added

**Rendering:** Pure Unicode box-drawing as virtual text, in-buffer.
**Terminal compat:** Works in Windows Terminal — plain text.
**Mermaid coverage:** Flowchart (13 node shapes, subgraphs), sequence,
state, class, ER, Gantt, pie, timeline.
**Keybinds:** None installed. Exposes only user-commands (`:MermaidRender`,
`:MermaidClear`, `:MermaidStyle`, `:MermaidMode`). Zero conflicts.
**Deps:** Node.js ≥ 18 (bundled engine).
**Status:** 34 stars, last push Feb 2026.
**Decision:** Add now. Best terminal-native in-buffer mermaid on Windows
Terminal.

### render-markdown.nvim (MeanderingProgrammer/render-markdown.nvim) — baseline

Already installed. **No mermaid support whatsoever** — confirmed zero
references in README and CHANGELOG. Mermaid fenced blocks render only as
styled code blocks (border + language label).

**Features not in original config (added in this session):**
- `latex` — inline math as Unicode approximation. Requires `utftex` (not
  in apt on Ubuntu — skip) or `latex2text` (`pipx install pylatexenc`).
  `converter = { 'utftex', 'latex2text' }` is a fallback chain; if utftex
  is absent, latex2text is used automatically.
- `html` — HTML comment concealing. Hides `<!-- ... -->` in normal mode.
- `yaml` — YAML frontmatter rendering.
- `wiki` — `[[wikilink]]` rendering.
- `inline_highlight` — `==text==` highlighting (Obsidian-style).
- `completions.lsp` — checkbox/callout completion in nvim-cmp/blink.cmp.
- `footnote` — `[^1]` footnote rendering.

Recent additions not yet in config:
- `:RenderMarkdown preview` — side-by-side rendered split (8.10.0).
- `vim.g.render_markdown_config` — configure via global var (8.10.0).

### md-render.nvim (delphinus/md-render.nvim) — bookmarked for post-Kitty

**Rendering:** Kitty graphics protocol (mermaid → PNG via `mmdc`).
**Terminal compat:** Requires Kitty. Inert on Windows Terminal.
**Status:** 118 stars, very active.
**Keybind note:** Suggests `<leader>mp` — conflicts with markdown-preview.nvim.
**Decision:** Bookmark. Add after Kitty becomes daily terminal. See
Chezmoi-38h.2.

### memd.nvim (ktrysmt/memd.nvim) — skip

Side-panel terminal preview via `memd-cli`. Requires `npm install -g
memd-cli`. 2 stars. ascii-mermaid covers the same niche better.

### mermaid-playground.nvim / markdown-preview.nvim (selimacerbas) ★ Replaces peek.nvim

Renamed to `selimacerbas/markdown-preview.nvim`. Browser-based.
- Markdown-it + mermaid.js + KaTeX served via embedded Lua HTTP server
  (`selimacerbas/live-server.nvim`).
- Optional Rust renderer: `cargo install mermaid-rs-renderer`, then
  `mermaid_renderer = "rust"` in setup (~400× faster).
- **No default keybinds.** Commands: `:MarkdownPreview`,
  `:MarkdownPreviewRefresh`, `:MarkdownPreviewStop`.
- CDN dependency for mermaid.js/KaTeX/highlight.js. First open after
  browser cache clear: 1–5s delay. Subsequent opens: instant.
  No self-hosted asset option documented.
- Keybind choices (no conflicts): `<leader>mp` (open), `<leader>mP`
  (stop), `<leader>mr` (refresh).
- **Decision:** Replaces peek.nvim. No reason to keep peek as fallback —
  markdown-preview.nvim is a strict superset.

### peek.nvim (toppair/peek.nvim) — removed

Does not bundle mermaid.js. Mermaid blocks render as code. Removed in
favor of markdown-preview.nvim.

**peek.nvim `config` function pitfall (for future reference):**
In lazy.nvim, providing a custom `config` function replaces the default
`require(plugin).setup(opts)` behavior entirely. The GitHub-recommended
snippet called `require("peek").setup()` with no args, discarding all
configured opts. Correct pattern:
```lua
config = function(_, opts)
  require("peek").setup(opts)
  -- user commands here
end,
```

---

## CLI tool evaluations

### termaid (fasouto/termaid) ★ Recommended

**Rendering:** Pure Python, Unicode box-drawing + ANSI color (Rich).
No graphics protocol.
**Terminal compat:** Works in Windows Terminal.
**Mermaid coverage:** 18 diagram types (flowchart, sequence, class, ER,
state, gitGraph, Gantt, mindmap, timeline, kanban, quadrant, XY chart,
pie, treemap, architecture, user journey, packet, block).
**Install:** `pip install termaid` or `uvx termaid diagram.mmd`.
**Neovim:** `:!termaid %` for `.mmd` files. Needs extraction wrapper for
fenced blocks in markdown.
**Status:** 299 stars, April 2026.
**Decision:** Best default CLI mermaid tool. Install independently of
Neovim setup.

### mmdflux (kevinswiber/mmdflux) ★ Recommended for layout quality

**Rendering:** Native Rust layout engine, orthogonal edge routing. Unicode
+ ANSI. No graphics protocol.
**Terminal compat:** Works in Windows Terminal.
**Mermaid coverage:** Flowchart, class, sequence, state. Narrower than
termaid.
**Install:** `cargo install mmdflux`.
**Pitfall:** Does not parse markdown. Expects raw mermaid source (`.mmd`
file or stdin). Running against a `.md` file produces "Unknown diagram
type" — the file header is read as the diagram type declaration. Extract
fenced blocks first.
**Status:** 50 stars, very active (pushed 2026-05-06).
**Decision:** Complement to termaid when layout quality matters for
flowcharts/class/sequence.

### glowm (atani/glowm) — deferred until Kitty

**Rendering:** Glamour (same as glow) for prose; headless Chrome → PNG
displayed via iTerm2/Kitty/Ghostty protocol for mermaid. Sixel NOT
supported.
**Terminal compat on Windows Terminal:** Mermaid falls back to code block.
No improvement over glow.
**Deps:** Chromium binary on WSL side (~hundreds of MB).
**Decision:** Skip until Kitty is daily terminal. See Chezmoi-38h.4.

---

## Treesitter grammars added

The following parsers were added to `ensure_installed` in this session,
with confirmed names from SUPPORTED_LANGUAGES.md:

- `mermaid`, `markdown`, `markdown_inline`, `html`, `vimdoc`
- `python` (covers Python 2 + 3), `bash`, `zsh` (separate parser exists),
  `lua`, `luadoc`
- `go`, `rust`
- `yaml`, `json`, `toml`, `ini` (covers INI/conf; no standalone `conf` parser)
- `make` (Makefiles; NOT `makefile`), `just` (Justfiles)
- `gotmpl` (Go templates, including chezmoi `.tmpl` files)
- `gitcommit`, `gitignore`, `dockerfile`, `regex`, `comment`, `vim`

Note: `zsh` IS a separate parser (georgeharker/tree-sitter-zsh), contrary
to earlier advice in this session.

---

## Terminal-conditional image feature pattern

For Kitty-protocol-dependent plugins (image.nvim, diagram.nvim,
md-render.nvim, Telescope image previews), use lazy.nvim's `cond` field:

```lua
{
  "3rd/image.nvim",
  cond = function()
    return vim.env.KITTY_WINDOW_ID ~= nil
  end,
  -- ... rest of spec
}
```

`$KITTY_WINDOW_ID` is set by Kitty in all its windows and survives through
tmux. Nothing else sets it. This prevents the plugin from loading at all
in non-Kitty terminals, which is why the `enabled = false` approach caused
noisy errors — the plugin still loaded and attempted terminal detection.

---

## Bead tracking

| Bead | Description |
|---|---|
| Chezmoi-0lg | Install GlazeWM, write minimal config, validate Kitty ergonomics — **gate for all Kitty and Chezmoi integration work** |
| Chezmoi-38h | Configure Kitty for ergonomic WSL2 use (blocked by Chezmoi-0lg) |
| Chezmoi-38h.1 | Enable image.nvim (KITTY_WINDOW_ID cond) |
| Chezmoi-38h.2 | Enable md-render.nvim |
| Chezmoi-38h.3 | Enable Telescope image/browser previews |
| Chezmoi-38h.4 | Install and configure glowm |
| Chezmoi-c0i | Windows integration epic: GlazeWM + Chezmoi mirror (blocked by Chezmoi-0lg on c0i.3–c0i.8) |

---

## Installation notes

**pylatexenc (for render-markdown latex converter):**
```bash
pipx install pylatexenc
# installs: latex2text binary
```
utftex is NOT in standard Ubuntu apt repos — use pylatexenc only.

**mermaid-rs-renderer (for markdown-preview.nvim Rust backend):**
```bash
cargo install mermaid-rs-renderer
# then set mermaid_renderer = "rust" in plugin setup
```

**termaid:**
```bash
pip install 'termaid[rich,textual]'
# or: uvx termaid (no install)
```

**mmdflux:**
```bash
cargo install mmdflux
```
