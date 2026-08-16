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
#   PROJECT      keystone            PROJECT_REF  stable/2025.1
#   PROFILES     fluent apache ldap  PIP_PACKAGES python-openstackclient
#   base OS      Ubuntu 22.04 jammy  UID/GID      42424
#
# PROVENANCE. This Dockerfile was RECOVERED, not written from scratch. The
# original image (ghcr.io/braghettos/keystone-oidc:2025.1-ubuntu_jammy) had no
# source repository anywhere. It was reconstructed on 2026-08-16 by reading the
# published image's OCI config: its layer history gave the LOCI build arguments
# above and the single RUN below. The reconstruction was then verified by layer
# digest comparison — 7 of the original's 8 layers match this base exactly, and
# the base contributes no layer the original lacked. The 8th is the RUN here.

FROM quay.io/airshipit/keystone:2025.1-ubuntu_jammy@sha256:4c88eb8078750819324132cb05055786bdcc64122c38e3cef5442a68f1c13a82

USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends libapache2-mod-auth-openidc \
 && rm -rf /var/lib/apt/lists/*

# Deliberately left as root. The recovered image's OCI config records User=root,
# and Apache needs it to bind :80. Do not "improve" this to the 42424 openstack
# user — that changes runtime identity from the image this replaces.
