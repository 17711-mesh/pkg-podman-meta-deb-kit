#!/usr/bin/env bash
set -euo pipefail

# Build a Debian meta package that registers an existing Podman stack.
# Usage: sudo ./build-podman-meta-deb.sh /opt/podman-v5.7.0
#
# The resulting .deb will:
#  - Create /opt/podman -> /opt/podman-<version> symlink (or manufacture one from /usr/local if needed)
#  - Install PATH + ld.so snippets
#  - Create/ensure ops user, subuid/subgid, linger
#  - Install systemd units pointing to /opt/podman/bin/podman (NOT /usr/local)
#  - Configure containers.conf + registries.conf if absent
#  - Set capabilities on passt/pasta
#  - Enable podman.socket by default

PREFIX_SRC="${1:-}"
if [[ -z "${PREFIX_SRC}" ]]; then
  echo "Usage: $0 /opt/podman-<version>"; exit 1
fi
if [[ ! -d "${PREFIX_SRC}" ]]; then
  echo "Prefix not found: ${PREFIX_SRC}" >&2; exit 2
fi

PREFIX_SRC="$(readlink -f "${PREFIX_SRC}")"
BASENAME="$(basename "${PREFIX_SRC}")"
PODMAN_VERSION="${BASENAME#podman-}"

ARCH_DEB="$(dpkg --print-architecture)"
case "${ARCH_DEB}" in
  amd64|arm64) ;;
  *) echo "Unsupported architecture: ${ARCH_DEB}" >&2; exit 3 ;;
esac

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

PKGROOT="${WORKDIR}/podman-meta_${PODMAN_VERSION}"
mkdir -p "${PKGROOT}/DEBIAN"

cat > "${PKGROOT}/DEBIAN/control" <<EOF
Package: podman-meta
Version: ${PODMAN_VERSION#v}
Section: admin
Priority: optional
Architecture: ${ARCH_DEB}
Maintainer: Local Builder <root@localhost>
Depends: adduser, libc6, systemd, policykit-1, dbus-user-session, uidmap, iptables, slirp4netns, fuse-overlayfs
Provides: podman-meta
Description: Podman full-stack (meta) wrapper for /opt/podman-${PODMAN_VERSION}
 Registers a versioned Podman stack under /opt, sets system integration, enables podman.socket.
EOF

# Pass PODMAN_VERSION into maintainer scripts via simple substitution
for s in preinst postinst prerm postrm; do
  sed "s|@@PODMAN_VERSION@@|${PODMAN_VERSION}|g" "$(dirname "$0")/debian-scripts/${s}" > "${PKGROOT}/DEBIAN/${s}"
  chmod 0755 "${PKGROOT}/DEBIAN/${s}"
done

# /etc files
install -d "${PKGROOT}/etc/profile.d" "${PKGROOT}/etc/ld.so.conf.d" "${PKGROOT}/etc/podman-meta"
cat > "${PKGROOT}/etc/profile.d/zz-podman.sh" <<'EOF'
# Podman meta: add versioned prefix to PATH
export PATH=/opt/podman/bin:/opt/podman/libexec:$PATH
EOF
echo "/opt/podman/lib" > "${PKGROOT}/etc/ld.so.conf.d/podman.conf"
echo "${PREFIX_SRC}" > "${PKGROOT}/etc/podman-meta/prefix"

OUT="$(pwd)/podman-meta-${PODMAN_VERSION}_${ARCH_DEB}.deb"
fakeroot dpkg-deb --build "${PKGROOT}" "${OUT}"
echo "Built: ${OUT}"
