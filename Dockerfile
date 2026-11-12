# Keystone with mod_auth_openidc — OIDC federation for Krateo CMP child clusters.
#
# Stock Keystone cannot speak OIDC. Federating a child Krateo's Keycloak into
# OpenStack requires Apache's mod_auth_openidc, which upstream Keystone images do
# not ship. This image is that base plus exactly one apt layer.
#
# BASE. quay.io/airshipit/keystone is the OpenStack LOCI build published by the
# Airship project. Pinned by tag *and* digest: the tag is rebuilt periodically
# upstream, so tag alone would silently change what we ship.
#
#   PROJECT      keystone            PROJECT_REF  stable/2026.1
#   base OS      Ubuntu 24.04 noble
#
# SERIES. The base must be the same OpenStack series as the Keystone the blueprint
# runs everywhere else (quay.io/airshipit/keystone:<series> for db-sync, bootstrap,
# fernet and credential jobs). keystone-api is the only container that runs this
# image, so a different series here runs keystone-api against a schema migrated by
# another release. The published tag is derived from this FROM line (release.yaml),
# so the tag always names the series that is inside it.
#
# PROVENANCE. The first build (2025.1, Ubuntu 22.04 jammy, LOCI profiles fluent
# apache ldap, PIP_PACKAGES python-openstackclient, UID/GID 42424) was RECOVERED,
# not written from scratch; its image stays published as 2025.1-ubuntu_jammy. The
# original image (ghcr.io/braghettos/keystone-oidc:2025.1-ubuntu_jammy) had no
# source repository anywhere. It was reconstructed on 2026-08-16 by reading the
# published image's OCI config: its layer history gave the LOCI build arguments
# above and the single RUN below. The reconstruction was then verified by layer
# digest comparison — 7 of the original's 8 layers match this base exactly, and
# the base contributes no layer the original lacked. The 8th is the RUN here.

FROM quay.io/airshipit/keystone:2026.1-ubuntu_noble@sha256:3071781eaa875a12a3e01334f2f58317b99ec3b792e704abecbc0a969cedc9e7

USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends libapache2-mod-auth-openidc \
 && rm -rf /var/lib/apt/lists/*

# Deliberately left as root. The recovered image's OCI config records User=root,
# and Apache needs it to bind :80. Do not "improve" this to the 42424 openstack
# user — that changes runtime identity from the image this replaces.
