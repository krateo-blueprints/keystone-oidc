# keystone-oidc

OpenStack Keystone **2025.1** with Apache's `mod_auth_openidc`, published as:

```
ghcr.io/krateo-blueprints/keystone-oidc:2025.1-ubuntu_jammy
```

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

Push a bare-semver git tag. CI builds `linux/amd64,linux/arm64` and pushes:

| tag | meaning |
|---|---|
| `2025.1-ubuntu_jammy` | the contract tag blueprints pin — must keep working |
| `2025.1-ubuntu_jammy-<version>` | immutable per-release tag for pinning or rollback |

The build fails if `mod_auth_openidc.so` is absent — the one thing this image exists
for — and warns if the package is not anonymously pullable, since the child's kubelet
pulls it without credentials.

## Upgrading Keystone

Change the base tag and digest together, then release. The OpenStack release and the
base OS both appear in the tag, so `2026.1-ubuntu_noble` would be a new contract tag
and a coordinated change in the consuming blueprints — not a silent move.
