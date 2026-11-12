# keystone-oidc

OpenStack Keystone with Apache's `mod_auth_openidc`, one contract tag per OpenStack series:

```
ghcr.io/krateo-blueprints/keystone-oidc:2026.1-ubuntu_noble   # current: Keystone 29.x, mod_auth_openidc 2.4.15
ghcr.io/krateo-blueprints/keystone-oidc:2025.1-ubuntu_jammy   # previous: Keystone 27.x, mod_auth_openidc 2.4.11, no longer rebuilt
```

Use the tag whose series matches the Keystone the rest of the deployment runs. keystone-api
is the only container that runs this image; db-sync, bootstrap and the other keystone jobs
run the stock base, and a series mismatch runs keystone-api against a schema another release
migrated.

Stock Keystone cannot speak OIDC. Federating a child Krateo's Keycloak into
OpenStack needs `mod_auth_openidc`, which upstream Keystone images do not ship.
This image is a public LOCI base plus exactly one apt layer — nothing else.

Consumed by `krateo-blueprints/child-sso-federation` (`keystoneImage`) and, through
it, by `krateo-selfservice-blueprint` when provisioning an SSO-federated child.

## Why this repository exists

The image existed before this repo did, at `ghcr.io/braghettos/keystone-oidc`, with
**no source anywhere** — no Dockerfile, no build workflow, in any organisation. It
could be pulled but not rebuilt, which meant it could not be patched when Keystone
or the OIDC module needed a security update, and it made the `braghettos` package
unsafe to delete.

A related failure had already been introduced: a commit sweeping `braghettos` →
`krateo-blueprints` across the blueprints repointed `keystoneImage` at an org where
the image had never been published. The text moved; the artifact did not. Any child
built from `krateo-selfservice-blueprint` 0.2.9 would fail to pull Keystone.

## How the Dockerfile was recovered

Not rewritten from guesswork — reconstructed from the published image itself
(2026-08-16):

1. **Read the OCI config** of `ghcr.io/braghettos/keystone-oidc:2025.1-ubuntu_jammy`.
   Its `history` records every build instruction, which gave the full LOCI argument
   set (`PROJECT=keystone`, `PROJECT_REF=stable/2025.1`, `PROFILES=fluent apache ldap`,
   `PIP_PACKAGES=python-openstackclient`, Ubuntu 22.04, UID/GID 42424) and the single
   custom `RUN` that installs `libapache2-mod-auth-openidc`.
2. **Located the base.** `openstackhelm/keystone` publishes no 2025.1 tags, but the
   Airship project's LOCI build does: `quay.io/airshipit/keystone:2025.1-ubuntu_jammy`.
3. **Proved it by digest.** 7 of the original's 8 layer digests match that base
   exactly, and the base contributes no layer the original lacks. The 8th layer is
   the `RUN` above. The base is therefore identified, not assumed.

The base is pinned by digest as well as tag, because Airship rebuilds that tag
periodically — tag alone would silently change what ships.

`USER` is deliberately left as `root`, matching the recovered image's config; Apache
needs it to bind `:80`.

## Releasing

Push a bare-semver git tag. CI builds `linux/amd64` (the only architecture the base
publishes) and pushes:

| tag | meaning |
|---|---|
| `<series>-ubuntu_<distro>`, e.g. `2026.1-ubuntu_noble` | the contract tag blueprints pin |
| `<series>-ubuntu_<distro>-<version>` | immutable per-release tag for pinning or rollback |

The contract tag is derived from the Dockerfile's `FROM` line, not written in the
workflow, so it always names the series inside the image. The build fails when:
- `FROM` is not a single digest-pinned `quay.io/airshipit/keystone:<series>-ubuntu_<distro>`;
- `mod_auth_openidc.so` is absent, the one thing this image exists for;
- the Keystone major version or the OS codename inside the image disagrees with the tag.

It warns if the package is not anonymously pullable, since the child's kubelet pulls
it without credentials.

## Upgrading Keystone

Change the base tag and digest together in `FROM`, then release. The OpenStack release
and the base OS both appear in the tag, so a new series is a new contract tag and a
coordinated change in the consuming blueprints, not a silent move. A tag already
published keeps the image it had. For a series the workflow does not yet know, add its
Keystone major version to the verification step (openstack/releases lists it).
