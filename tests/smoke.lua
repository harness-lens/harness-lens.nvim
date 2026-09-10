-- SPDX-License-Identifier: MPL-2.0
-- Copyright © 2026 Cristian Camargo Filho

local server = arg[#arg]
assert(server and server ~= "", "pass the harness-lens-lsp path as the first argument")
assert(vim.fn.executable(server) == 1, "language server is not executable: " .. server)

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.fn.writefile({ "version = 1" }, root .. "/harness-lens.toml")
vim.fn.writefile({ "Always always verify the evidence." }, root .. "/AGENTS.md")

require("harness-lens").setup({
  cmd = { server },
})
vim.cmd.edit(vim.fn.fnameescape(root .. "/AGENTS.md"))
local bufnr = vim.api.nvim_get_current_buf()

local attached = vim.wait(10000, function()
  return #vim.lsp.get_clients({ bufnr = bufnr, name = "harness_lens" }) > 0
end, 20)
assert(attached, "Harness Lens did not attach within 10 seconds")

local diagnosed = vim.wait(10000, function()
  for _, diagnostic in ipairs(vim.diagnostic.get(bufnr)) do
    if diagnostic.source == "harness-lens" and diagnostic.code == "HL010" then
      return true
    end
  end
  return false
end, 20)
assert(diagnosed, "Harness Lens did not publish the expected HL010 diagnostic")

for _, client in ipairs(vim.lsp.get_clients({ name = "harness_lens" })) do
  client:stop(true)
end
vim.fn.delete(root, "rf")
print("ok - native harness-lens-lsp smoke")
vim.cmd("quitall!")
