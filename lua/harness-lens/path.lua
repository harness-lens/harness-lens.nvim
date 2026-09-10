-- SPDX-License-Identifier: MPL-2.0
-- Copyright © 2026 Cristian Camargo Filho

local M = {}

local function normalize(path)
  return path:gsub("\\", "/"):gsub("/+", "/")
end

local function basename(path)
  return normalize(path):match("([^/]+)$") or ""
end

local function has_suffix(path, suffix)
  path = normalize(path)
  suffix = normalize(suffix):gsub("^/+", ""):gsub("/+$", "")
  return path == suffix or path:sub(-#suffix - 1) == "/" .. suffix
end

local function contains_directory(path, directory)
  path = "/" .. normalize(path):gsub("^/+", ""):gsub("/+$", "") .. "/"
  directory = "/" .. normalize(directory):gsub("^/+", ""):gsub("/+$", "") .. "/"
  return path:find(directory, 1, true) ~= nil
end

local function contains(values, candidate)
  for _, value in ipairs(values) do
    if value == candidate then
      return true
    end
  end
  return false
end

---Return whether a filesystem path is handled by Harness Lens.
---@param path string
---@param config table
---@return boolean
function M.matches(path, config)
  if path == "" then
    return false
  end

  local name = basename(path)
  if contains(config.file_names, name) then
    return true
  end

  for _, suffix in ipairs(config.path_suffixes) do
    if has_suffix(path, suffix) then
      return true
    end
  end

  for _, directory in ipairs(config.directory_suffixes) do
    if contains_directory(path, directory) then
      return true
    end
  end

  if not config.runtime_metrics then
    return false
  end

  if name == "SKILL.md" then
    return true
  end
  for _, suffix in ipairs(config.runtime_paths) do
    if has_suffix(path, suffix) then
      return true
    end
  end

  return false
end

return M
