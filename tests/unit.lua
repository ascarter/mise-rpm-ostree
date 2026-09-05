package.path = "./?.lua;./?/init.lua;" .. package.path

local calls = {}
local status = {
  deployments = {
    { osname = "fedora", checksum = string.rep("a", 64), serial = 0 },
  },
}

package.preload.cmd = function()
  return {
    exec = function(command)
      table.insert(calls, command)
      if command == "rpm-ostree status --json" then
        return "status fixture"
      end
      if command:match("^rpm %-%-root ") then
        return "bash\t5.2-1.fc42\nripgrep\t14.1.1-2.fc42\n"
      end
      return ""
    end,
  }
end

package.preload.json = function()
  return {
    decode = function(value)
      if value == "malformed" then
        error("invalid JSON")
      end
      return status
    end,
  }
end

local rpm_ostree = require("lib.rpm_ostree")

local function equal(actual, expected, label)
  if actual ~= expected then
    error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local result = rpm_ostree.installed({
  packages = {
    { name = "ripgrep", version = "14.1.1-2.fc42" },
    { name = "missing-package", version = "latest" },
    { name = "ripgrep", version = "latest" },
  },
})
equal(#calls, 2, "installed command count")
equal(calls[1], "rpm-ostree status --json", "status command")
equal(
  calls[2],
  "rpm --root /sysroot/ostree/deploy/fedora/deploy/" .. string.rep("a", 64)
    .. ".0 -qa --queryformat '%{NAME}\\t%{EVR}\\n'",
  "rpm command"
)
equal(#result.packages, 3, "result count")
equal(result.packages[1].state, "installed", "installed state")
equal(result.packages[1].version, "14.1.1-2.fc42", "installed version")
equal(result.packages[2].state, "missing", "missing state")
equal(result.packages[3].name, "ripgrep", "duplicate ordering")

local specs = rpm_ostree.specs({
  { name = "ripgrep", version = "latest" },
  { name = "bash", version = "1:5.2.37-1.fc42" },
})
equal(specs[1], "ripgrep", "latest package spec")
equal(specs[2], "bash-1:5.2.37-1.fc42", "exact package spec")

calls = {}
rpm_ostree.action(
  { packages = { { name = "ripgrep" }, { name = "podman-compose" } } },
  { "rpm-ostree", "install", "--idempotent" },
  "install"
)
equal(#calls, 1, "batched install count")
equal(calls[1], "rpm-ostree install --idempotent ripgrep podman-compose", "batched install")

calls = {}
rpm_ostree.action(
  {
    packages = {
      { name = "ripgrep", version = "14.1.1-2.fc42" },
      { name = "bash", version = "latest" },
    },
  },
  { "rpm-ostree", "install", "--idempotent" },
  "install",
  true
)
equal(#calls, 1, "versioned install count")
equal(calls[1], "rpm-ostree install --idempotent ripgrep-14.1.1-2.fc42 bash", "versioned install")

calls = {}
rpm_ostree.action(
  { packages = { { name = "ripgrep", version = "14.1.1-2.fc42" } } },
  { "rpm-ostree", "uninstall", "--allow-inactive", "--idempotent" },
  "uninstall"
)
equal(#calls, 1, "uninstall count")
equal(calls[1], "rpm-ostree uninstall --allow-inactive --idempotent ripgrep", "uninstall uses package name")

calls = {}
local printed = {}
local original_log = rpm_ostree.log
rpm_ostree.log = function(message)
  table.insert(printed, message)
end
rpm_ostree.refresh({ update = true, dry_run = true })
rpm_ostree.action(
  { dry_run = true, packages = { { name = "ripgrep", version = "14.1.1-2.fc42" } } },
  { "rpm-ostree", "install", "--idempotent" },
  "install",
  true
)
rpm_ostree.log = original_log
equal(#calls, 0, "dry-run command count")
equal(printed[1], "rpm-ostree refresh-md", "dry-run refresh")
equal(printed[2], "rpm-ostree install --idempotent ripgrep-14.1.1-2.fc42", "dry-run install")

calls = {}
local ok = pcall(rpm_ostree.names, { { name = "https://example.invalid/a.rpm" } })
equal(ok, false, "URL rejection")
equal(#calls, 0, "invalid identity command count")

ok = pcall(rpm_ostree.names, { { name = "ripgrep", version = ">=14.1.1" } })
equal(ok, false, "version range rejection")

ok = pcall(rpm_ostree.names, { { name = "ripgrep", version = "14.1.1 2.fc42" } })
equal(ok, false, "invalid version rejection")

ok = pcall(rpm_ostree.names, { { name = "ripgrep", version = "14.1.1-2.fc42" } })
equal(ok, true, "exact version acceptance")

status = { deployments = {} }
ok = pcall(rpm_ostree.installed, { packages = { { name = "ripgrep" } } })
equal(ok, false, "missing deployment rejection")

print("unit tests passed")
