# mise rpm-ostree package plugin

A Linux-only [mise package-manager plugin](https://mise.jdx.dev/package-plugin-development.html) for repository RPMs on Fedora Atomic and other rpm-ostree systems. It stages package changes in the default next-boot deployment and leaves reboot timing to you.

## Configuration

```toml
[bootstrap.plugins]
rpm-ostree = "https://github.com/ascarter/mise-rpm-ostree"

[bootstrap.packages]
"rpm-ostree:ripgrep" = "latest"
"rpm-ostree:podman-compose" = "latest"
```

Only repository package names are supported, and the version must be `"latest"`. Local RPM paths, URLs, package provides, and version pins are rejected.

## Usage

```sh
mise bootstrap plugins apply
mise bootstrap packages status --manager rpm-ostree
mise bootstrap packages apply --manager rpm-ostree
mise bootstrap packages upgrade --manager rpm-ostree
mise bootstrap packages prune --manager rpm-ostree
```

`apply` batches missing packages into `rpm-ostree install --idempotent`. Add `--update` to refresh repository metadata first. `upgrade` deliberately runs one whole-system `rpm-ostree upgrade`, updating the base image and layered packages together. `prune` removes only the concrete package batch approved by mise; it does not clean deployments, remove overrides, or infer removals from absent configuration.

All changes use rpm-ostree's normal transactional behavior. The plugin does not use live application, reboot, rebase, rollback, or deployment cleanup. Reboot after a successful apply, upgrade, or prune to boot the staged deployment, then check status again.

Package plugins cannot elevate and this plugin never invokes `sudo`. Run mise as root or arrange suitable polkit authorization for rpm-ostree transactions. Authorization failures and conflicting transactions are returned as errors.

Dry runs print the exact commands without executing them:

```sh
mise bootstrap packages apply --manager rpm-ostree --update --dry-run
mise bootstrap packages upgrade --manager rpm-ostree --dry-run
```

## Fedora Atomic smoke test

On a disposable VM, configure a harmless package and run apply, reboot, status, prune, and reboot again. Confirm after each reboot that the requested package state matches the configuration. Do not perform this test on a machine whose staged deployment you need to preserve.

## License

MIT
