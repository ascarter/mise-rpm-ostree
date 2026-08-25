local cmd = require("cmd")
local json = require("json")

local M = {}

local function fail(message)
  error("rpm-ostree package plugin: " .. message, 0)
end

local function exec(command, purpose)
  local ok, output = pcall(cmd.exec, command)
  if not ok then
    fail(purpose .. " failed: " .. tostring(output))
  end
  return output
end

local function validate_version(package)
  if package.version ~= nil and package.version ~= "latest" then
    fail("package " .. tostring(package.name) .. " must use version \"latest\"")
  end
end

function M.names(packages)
  local names = {}
  for _, package in ipairs(packages or {}) do
    local name = package.name
    if type(name) ~= "string" or not name:match("^[A-Za-z0-9][A-Za-z0-9+._-]*$") then
      fail("invalid repository package name: " .. tostring(name))
    end
    validate_version(package)
    table.insert(names, name)
  end
  return names
end

function M.command(parts)
  return table.concat(parts, " ")
end

function M.run(parts, purpose)
  return exec(M.command(parts), purpose)
end

function M.action(ctx, parts, purpose)
  if #(ctx.packages or {}) == 0 then
    return {}
  end
  local names = M.names(ctx.packages)
  for _, name in ipairs(names) do
    table.insert(parts, name)
  end
  local command = M.command(parts)
  if ctx.dry_run then
    print(command)
  else
    exec(command, purpose)
  end
  return {}
end

function M.refresh(ctx)
  if not ctx.update then
    return
  end
  local command = "rpm-ostree refresh-md"
  if ctx.dry_run then
    print(command)
  else
    exec(command, "metadata refresh")
  end
end

local function deployment_root()
  local output = exec("rpm-ostree status --json", "deployment status query")
  local ok, status = pcall(json.decode, output)
  if not ok then
    fail("could not parse rpm-ostree status JSON: " .. tostring(status))
  end
  if type(status) ~= "table" or type(status.deployments) ~= "table" then
    fail("status JSON has no deployments array")
  end
  local deployment = status.deployments[1]
  if type(deployment) ~= "table" then
    fail("status JSON has no default deployment")
  end
  local osname = deployment.osname
  local checksum = deployment.checksum
  local serial = deployment.serial
  if type(osname) ~= "string" or not osname:match("^[A-Za-z0-9._-]+$") then
    fail("default deployment has an invalid or missing osname")
  end
  if type(checksum) ~= "string" or #checksum ~= 64 or not checksum:match("^[0-9a-fA-F]+$") then
    fail("default deployment has an invalid or missing checksum")
  end
  if type(serial) ~= "number" or serial < 0 or serial ~= math.floor(serial) then
    fail("default deployment has an invalid or missing serial")
  end
  return "/sysroot/ostree/deploy/" .. osname .. "/deploy/" .. checksum .. "." .. serial
end

function M.installed(ctx)
  local names = M.names(ctx.packages)
  if #names == 0 then
    return { packages = {} }
  end
  local root = deployment_root()
  local output = exec(
    "rpm --root " .. root .. " -qa --queryformat '%{NAME}\\t%{EVR}\\n'",
    "package query for default deployment"
  )
  local installed = {}
  for line in (output .. "\n"):gmatch("([^\n]*)\n") do
    local name, version = line:match("^([^\t]+)\t(.+)$")
    if name and not installed[name] then
      installed[name] = version
    end
  end
  local results = {}
  for _, name in ipairs(names) do
    local version = installed[name]
    if version then
      table.insert(results, { name = name, state = "installed", version = version })
    else
      table.insert(results, { name = name, state = "missing" })
    end
  end
  return { packages = results }
end

return M
