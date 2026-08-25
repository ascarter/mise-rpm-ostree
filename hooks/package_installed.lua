local rpm_ostree = require("lib.rpm_ostree")

function PLUGIN:PackageInstalled(ctx)
  return rpm_ostree.installed(ctx)
end
