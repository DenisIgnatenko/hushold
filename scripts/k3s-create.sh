#!/usr/bin/env bash
# Creates the OrbStack Linux machine `hushold-k3s` and installs k3s in it (docs/07-infrastructure.md).
# Idempotent: re-running on an existing machine only verifies that the node is Ready.
# The machine is the rehearsal target for Helm and ArgoCD in M7; it is not used day to day before that.
set -euo pipefail

readonly MACHINE="hushold-k3s"
readonly DISTRO="ubuntu"
readonly KUBECONFIG_OUT="${HOME}/.kube/hushold-k3s.yaml"

if ! command -v orb >/dev/null 2>&1; then
  echo "OrbStack CLI 'orb' not found. Install OrbStack first." >&2
  exit 1
fi

if orb list | awk '{print $1}' | grep -qx "${MACHINE}"; then
  echo "Machine ${MACHINE} already exists."
  orb start "${MACHINE}" >/dev/null 2>&1 || true
else
  echo "Creating OrbStack machine ${MACHINE} (${DISTRO})..."
  orb create "${DISTRO}" "${MACHINE}"
fi

if orb -m "${MACHINE}" test -x /usr/local/bin/k3s; then
  echo "k3s already installed."
else
  echo "Installing k3s (stable channel)..."
  # The extra TLS SAN lets kubectl on the Mac reach the API server by its OrbStack hostname.
  orb -m "${MACHINE}" bash -c "curl -sfL https://get.k3s.io | \
    INSTALL_K3S_CHANNEL=stable \
    INSTALL_K3S_EXEC='server --tls-san ${MACHINE}.orb.local --write-kubeconfig-mode 0644' sh -"
fi

echo "Waiting for the node to become Ready..."
orb -m "${MACHINE}" sudo k3s kubectl wait --for=condition=Ready node --all --timeout=180s

# Export a kubeconfig for the Mac; the default one points at 127.0.0.1 inside the machine.
mkdir -p "$(dirname "${KUBECONFIG_OUT}")"
orb -m "${MACHINE}" cat /etc/rancher/k3s/k3s.yaml \
  | sed "s#https://127.0.0.1:6443#https://${MACHINE}.orb.local:6443#" > "${KUBECONFIG_OUT}"
chmod 600 "${KUBECONFIG_OUT}"

KUBECONFIG="${KUBECONFIG_OUT}" kubectl get nodes
echo "Kubeconfig written to ${KUBECONFIG_OUT}. Use: export KUBECONFIG=${KUBECONFIG_OUT}"
