local rpm_ostree = require("lib.rpm_ostree")

function PLUGIN:PackageUpgrade(ctx)
  rpm_ostree.names(ctx.packages)
  if #(ctx.packages or {}) == 0 then
    return {}
  end
  local command = "rpm-ostree upgrade"
  if ctx.dry_run then
    print(command)
  else
    rpm_ostree.run({ "rpm-ostree", "upgrade" }, "system upgrade")
  end
  return {}
end
