local rpm_ostree = require("lib.rpm_ostree")

function PLUGIN:PackageUninstall(ctx)
  return rpm_ostree.action(
    ctx,
    { "rpm-ostree", "uninstall", "--allow-inactive", "--idempotent" },
    "package removal"
  )
end
