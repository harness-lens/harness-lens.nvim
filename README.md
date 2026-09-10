<!-- SPDX-License-Identifier: MPL-2.0 -->
<!-- Copyright © 2026 Cristian Camargo Filho -->

# harness-lens.nvim

Lua integration for using [Harness Lens](https://github.com/harness-lens/harness-lens)
from Neovim and LazyVim.

The plugin is intentionally a thin editor adapter. It recognizes harness and
runtime-evidence files, selects the nearest workspace root, and starts the
existing `harness-lens-lsp` process over standard input/output. Analysis,
scoring, discovery, UTF-16 conversion, and CodeBurn correlation remain in the
Harness Lens SDK and language server.

## Requirements

- Neovim 0.10 or newer;
- `harness-lens-lsp` installed on `PATH`, or an explicit `cmd` setting.

Until native release artifacts are available, build the server from its owning
repository:

```bash
git clone https://github.com/harness-lens/language-server.git harness-lens-language-server
cargo install --locked --path harness-lens-language-server/rust
```

The plugin never downloads or updates the server.

## LazyVim / lazy.nvim

Create `lua/plugins/harness-lens.lua`:

```lua
return {
  {
    "harness-lens/harness-lens.nvim",
    main = "harness-lens",
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
  },
}
```

For local development before the repository is published, replace the GitHub
name with a local checkout:

```lua
return {
  {
    dir = "/absolute/path/to/harness-lens.nvim",
    name = "harness-lens.nvim",
    main = "harness-lens",
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
  },
}
```

## Plain Neovim

Install the checkout as a native package:

```bash
git clone https://github.com/harness-lens/harness-lens.nvim.git \
  ~/.local/share/nvim/site/pack/harness-lens/start/harness-lens.nvim
```

Then configure it in `init.lua`:

```lua
require("harness-lens").setup()
```

Neovim renders the server's standard diagnostics using its normal diagnostic
UI. Virtual text is an editor-wide preference and is not changed by this
plugin; enable it yourself if desired:

```lua
vim.diagnostic.config({ virtual_text = true })
```

## Configuration

Defaults are shown below. List options replace their defaults when supplied.

```lua
require("harness-lens").setup({
  enabled = true,
  autostart = true,
  name = "harness_lens",
  cmd = { "harness-lens-lsp" },
  root_markers = { "harness-lens.toml", ".git" },

  file_names = { "AGENTS.md", "CLAUDE.md", "GEMINI.md" },
  path_suffixes = { ".github/copilot-instructions.md" },
  directory_suffixes = { ".cursor/rules" },

  runtime_metrics = true,
  code_lens = true,
  runtime_paths = {
    ".codex/config.toml",
    ".claude/settings.json",
    ".claude/settings.local.json",
    ".cursor/mcp.json",
    "opencode.json",
    "opencode.jsonc",
  },

  -- Optional fixed root or function(bufnr, path) -> root.
  root_dir = nil,

  -- Optional final path decision. `matched` is the built-in result.
  filter = function(path, bufnr, matched)
    return matched
  end,

  -- Extra vim.lsp.ClientConfig fields such as capabilities, on_attach, or env.
  lsp = {},
})
```

If `harness-lens.toml` adds custom discovery names or directories, mirror those
selectors in the adapter options so Neovim knows which buffers should attach.
The language server remains authoritative for whether a discovered file is
actually analyzed.

To use a server outside `PATH`:

```lua
require("harness-lens").setup({
  cmd = { "/absolute/path/to/harness-lens-lsp" },
})
```

Optional CodeBurn environment settings can be passed without changing the
process command:

```lua
require("harness-lens").setup({
  lsp = {
    cmd_env = {
      HARNESS_METRICS_CODEBURN_EXECUTABLE = "codeburn",
      HARNESS_METRICS_CODEBURN_PERIOD = "30days",
    },
  },
})
```

## Commands

- `:HarnessLensStart` starts or reuses a server for the current recognized file.
- `:HarnessLensRestart` restarts the current workspace's attached server.
- `:HarnessLensRefresh` requests a fresh optional CodeBurn snapshot.

CodeBurn failure is handled by the language server and does not suppress
deterministic `HL...` diagnostics.

## What the Lua adapter owns

```text
recognized Neovim buffer
  -> harness-lens.nvim (root selection and process lifecycle)
  -> harness-lens-lsp (workspace overlays and protocol conversion)
  -> SDK/Core (discovery, evidence, findings, and scores)
  -> standard Neovim diagnostics, hover, and code lenses
```

It does not copy validation rules, parse reports, upload source, select a model
provider, or silently install executables. This keeps editor behavior
provider-neutral and preserves Harness Lens's local-first boundary.

## Development

Run the headless Lua tests:

```bash
make test
```

The tests exercise path selection, Windows-style separators, runtime-evidence
opt-out, command registration, and workspace-root selection without starting a
real server or accessing the network.

When a native server build is available, run the end-to-end LSP smoke too:

```bash
make smoke SERVER=/absolute/path/to/harness-lens-lsp
```

## License

MPL-2.0. See [LICENSING](LICENSING.md), [COPYRIGHT](COPYRIGHT), and
[TRADEMARKS](TRADEMARKS).
