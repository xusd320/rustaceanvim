---@mod rustaceanvim.config.server LSP configuration utility

local server = {}

---Read the content of a file
---@param filename string
---@return string|nil content
local function read_file(filename)
  local content
  local f = io.open(filename, 'r')
  if f then
    content = f:read('*a')
    f:close()
  end
  return content
end

---@class LoadRASettingsOpts
---@field settings_file_pattern string|nil File name or pattern to search for. Defaults to 'rust-analyzer.json'
---@field default_settings table|nil Default settings to merge the loaded settings into

--- Load rust-analyzer settings from a JSON file,
--- falling back to the default settings if none is found or if it cannot be decoded.
---@param project_root string|nil The project root
---@param opts LoadRASettingsOpts|nil
---@return table server_settings
---@see https://rust-analyzer.github.io/manual.html#configuration
function server.load_rust_analyzer_settings(project_root, opts)
  local config = require('rustaceanvim.config.internal')
  local compat = require('rustaceanvim.compat')

  local default_opts = { settings_file_pattern = 'rust-analyzer.json' }
  opts = vim.tbl_deep_extend('force', {}, default_opts, opts or {})
  local default_settings = opts.default_settings or config.server.default_settings
  local use_clippy = config.tools.enable_clippy and vim.fn.executable('cargo-clippy') == 1
  ---@diagnostic disable-next-line: undefined-field
  if default_settings['rust-analyzer'].checkOnSave == nil and use_clippy then
    ---@diagnostic disable-next-line: inject-field
    default_settings['rust-analyzer'].checkOnSave = {
      allFeatures = true,
      command = 'clippy',
      extraArgs = { '--no-deps' },
    }
  end
  if not project_root then
    return default_settings
  end
  local results = vim.fn.glob(compat.joinpath(project_root, opts.settings_file_pattern), true, true)
  if #results == 0 then
    return default_settings
  end
  local config_json = results[1]
  local content = read_file(config_json)
  local success, rust_analyzer_settings = pcall(vim.json.decode, content)
  if not success or not rust_analyzer_settings then
    local msg = 'Could not decode ' .. config_json .. '. Falling back to default settings.'
    vim.notify('rustaceanvim: ' .. msg, vim.log.levels.ERROR)
    return default_settings
  end
  local ra_key = 'rust-analyzer'
  if rust_analyzer_settings[ra_key] then
    -- Settings json with "rust-analyzer" key
    default_settings[ra_key] = rust_analyzer_settings[ra_key]
  else
    -- "rust-analyzer" settings are top level
    default_settings[ra_key] = rust_analyzer_settings
  end
  return default_settings
end

return server
