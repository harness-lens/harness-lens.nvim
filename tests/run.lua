-- SPDX-License-Identifier: MPL-2.0
-- Copyright © 2026 Cristian Camargo Filho

local path = require("harness-lens.path")
local harness_lens = require("harness-lens")

local failures = 0
local tests = 0

local function test(name, body)
  tests = tests + 1
  local ok, error = pcall(body)
  if ok then
    print("ok - " .. name)
  else
    failures = failures + 1
    print("not ok - " .. name .. ": " .. tostring(error))
  end
end

local function assert_equal(actual, expected)
  if actual ~= expected then
    error(("expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual)))
  end
end

local match_config = {
  file_names = { "AGENTS.md", "CLAUDE.md", "GEMINI.md" },
  path_suffixes = { ".github/copilot-instructions.md" },
  directory_suffixes = { ".cursor/rules" },
  runtime_metrics = true,
  runtime_paths = { ".codex/config.toml", "opencode.json" },
}

test("recognizes default harness files", function()
  assert_equal(path.matches("/repo/AGENTS.md", match_config), true)
  assert_equal(path.matches("C:\\repo\\.github\\copilot-instructions.md", match_config), true)
  assert_equal(path.matches("/repo/.cursor/rules/rust.md", match_config), true)
  assert_equal(path.matches("/repo/src/AGENTS.md.bak", match_config), false)
end)

test("recognizes optional runtime evidence files", function()
  assert_equal(path.matches("/repo/.agents/skills/review/SKILL.md", match_config), true)
  assert_equal(path.matches("/repo/.codex/config.toml", match_config), true)
  assert_equal(path.matches("/repo/opencode.json", match_config), true)
  assert_equal(path.matches("/repo/src/lib.rs", match_config), false)
end)

test("can disable runtime evidence matching", function()
  local config = vim.tbl_deep_extend("force", {}, match_config, { runtime_metrics = false })
  assert_equal(path.matches("/repo/SKILL.md", config), false)
  assert_equal(path.matches("/repo/AGENTS.md", config), true)
end)

test("starts the server at the nearest configured root", function()
  local root = vim.fn.tempname()
  local nested = root .. "/docs"
  vim.fn.mkdir(nested, "p")
  vim.fn.writefile({ "version = 1" }, root .. "/harness-lens.toml")
  vim.fn.writefile({ "# Instructions" }, nested .. "/AGENTS.md")
  local bufnr = vim.fn.bufadd(nested .. "/AGENTS.md")
  vim.fn.bufload(bufnr)

  local original_start = vim.lsp.start
  local captured
  vim.lsp.start = function(config, options)
    captured = { config = config, options = options }
    return 42
  end
  harness_lens.setup({ autostart = false, cmd = { vim.v.progpath, "--headless" } })
  local client_id = harness_lens.start(bufnr)
  vim.lsp.start = original_start

  assert_equal(client_id, 42)
  assert_equal(captured.config.name, "harness_lens")
  assert_equal(captured.config.root_dir, vim.fs.normalize(root))
  assert_equal(captured.options.bufnr, bufnr)
  assert_equal(vim.fn.exists(":HarnessLensRefresh"), 2)
  vim.fn.delete(root, "rf")
end)

print(("%d tests, %d failures"):format(tests, failures))
if failures > 0 then
  vim.cmd("cquit " .. failures)
else
  vim.cmd("quitall!")
end
