local rpm_ostree = require("lib.rpm_ostree")

function PLUGIN:PackageInstall(ctx)
  rpm_ostree.names(ctx.packages)
  rpm_ostree.refresh(ctx)
  return rpm_ostree.action(ctx, { "rpm-ostree", "install", "--idempotent" }, "package installation")
end
