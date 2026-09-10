-- SPDX-License-Identifier: MPL-2.0
-- Copyright © 2026 Cristian Camargo Filho

local paths = require("harness-lens.path")

local M = {}

local defaults = {
  enabled = true,
  autostart = true,
  name = "harness_lens",
  cmd = { "harness-lens-lsp" },
  root_markers = { "harness-lens.toml", ".git" },
  root_dir = nil,
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
  filter = nil,
  lsp = {},
}

local list_options = {
  "cmd",
  "root_markers",
  "file_names",
  "path_suffixes",
  "directory_suffixes",
  "runtime_paths",
}

local state = {
  config = vim.deepcopy(defaults),
  missing_executable = nil,
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Harness Lens" })
end

local function resolved_config(opts)
  opts = opts or {}
  local config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
  for _, key in ipairs(list_options) do
    if opts[key] ~= nil then
      config[key] = vim.deepcopy(opts[key])
    end
  end
  return config
end

local function buffer_path(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
    return nil
  end
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    return nil
  end
  return vim.fs.normalize(path)
end

local function matches(bufnr, path)
  local matched = paths.matches(path, state.config)
  if state.config.filter then
    return state.config.filter(path, bufnr, matched) == true
  end
  return matched
end

local function root_for(bufnr, path)
  local root_dir = state.config.root_dir
  if type(root_dir) == "function" then
    return root_dir(bufnr, path)
  end
  if type(root_dir) == "string" and root_dir ~= "" then
    return vim.fs.normalize(root_dir)
  end
  return vim.fs.root(path, state.config.root_markers) or vim.fs.dirname(path)
end

local function executable_available()
  local executable = state.config.cmd[1]
  if type(executable) ~= "string" or executable == "" then
    notify("`cmd` must begin with a language-server executable", vim.log.levels.ERROR)
    return false
  end
  if vim.fn.executable(executable) == 1 then
    state.missing_executable = nil
    return true
  end
  if state.missing_executable ~= executable then
    state.missing_executable = executable
    notify(
      ("Could not find `%s`. Install harness-lens-lsp or set `cmd` in setup()."):format(executable),
      vim.log.levels.WARN
    )
  end
  return false
end

local function clients(bufnr)
  local result = {}
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.name == state.config.name then
      result[#result + 1] = client
    end
  end
  return result
end

---Start or reuse Harness Lens for a recognized buffer.
---@param bufnr? integer
---@return integer? client_id
function M.start(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not state.config.enabled then
    return nil
  end
  local path = buffer_path(bufnr)
  if not path or not matches(bufnr, path) or not executable_available() then
    return nil
  end
  local root_dir = root_for(bufnr, path)
  if not root_dir then
    notify(("Could not determine a workspace root for `%s`"):format(path), vim.log.levels.WARN)
    return nil
  end

  local config = vim.tbl_deep_extend("force", {}, state.config.lsp)
  config.name = state.config.name
  config.cmd = vim.deepcopy(state.config.cmd)
  config.root_dir = root_dir
  return vim.lsp.start(config, { bufnr = bufnr })
end

---Restart Harness Lens clients attached to the current buffer.
---@param bufnr? integer
function M.restart(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local attached = clients(bufnr)
  if #attached == 0 then
    M.start(bufnr)
    return
  end

  local buffers = {}
  for _, client in ipairs(attached) do
    for _, info in ipairs(vim.fn.getbufinfo({ bufloaded = 1 })) do
      if vim.lsp.buf_is_attached(info.bufnr, client.id) then
        buffers[info.bufnr] = true
      end
    end
    client:stop()
  end

  vim.defer_fn(function()
    for buffer, _ in pairs(buffers) do
      if vim.api.nvim_buf_is_valid(buffer) then
        M.start(buffer)
      end
    end
  end, 100)
end

---Ask the server to refresh its optional CodeBurn snapshot.
---@param bufnr? integer
function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local attached = clients(bufnr)
  if #attached == 0 then
    notify("Harness Lens is not attached to this buffer", vim.log.levels.WARN)
    return
  end
  for _, client in ipairs(attached) do
    client:request("workspace/executeCommand", {
      command = "harnessMetrics.refreshCodeBurn",
      arguments = {},
    }, function(error)
      if error then
        notify(("CodeBurn refresh failed: %s"):format(error.message or tostring(error)), vim.log.levels.ERROR)
      end
    end, bufnr)
  end
end

local function define_commands()
  vim.api.nvim_create_user_command("HarnessLensStart", function()
    M.start(0)
  end, { desc = "Start Harness Lens for the current buffer", force = true })
  vim.api.nvim_create_user_command("HarnessLensRestart", function()
    M.restart(0)
  end, { desc = "Restart Harness Lens for the current workspace", force = true })
  vim.api.nvim_create_user_command("HarnessLensRefresh", function()
    M.refresh(0)
  end, { desc = "Refresh Harness Lens CodeBurn evidence", force = true })
end

local function enable_code_lens(bufnr)
  if not state.config.code_lens then
    return
  end
  if vim.lsp.codelens.enable then
    vim.lsp.codelens.enable(true, { bufnr = bufnr })
  else
    vim.lsp.codelens.refresh({ bufnr = bufnr })
  end
end

---Configure the Harness Lens Neovim adapter.
---@param opts? table
function M.setup(opts)
  state.config = resolved_config(opts)
  state.missing_executable = nil
  define_commands()

  local group = vim.api.nvim_create_augroup("HarnessLens", { clear = true })
  if not state.config.enabled then
    return
  end
  if state.config.autostart then
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
      group = group,
      callback = function(args)
        M.start(args.buf)
      end,
      desc = "Start Harness Lens for recognized harness files",
    })
  end
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.name == state.config.name then
        enable_code_lens(args.buf)
      end
    end,
    desc = "Enable Harness Lens code lenses",
  })
  if not vim.lsp.codelens.enable then
    vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
      group = group,
      callback = function(args)
        if #clients(args.buf) > 0 then
          enable_code_lens(args.buf)
        end
      end,
      desc = "Refresh Harness Lens code lenses",
    })
  end

  if state.config.autostart then
    vim.schedule(function()
      for _, info in ipairs(vim.fn.getbufinfo({ bufloaded = 1 })) do
        M.start(info.bufnr)
      end
    end)
  end
end

return M
