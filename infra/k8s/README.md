# Kubernetes

One Helm chart per service under `charts/<service>/` plus a shared library chart, and platform charts. Values per environment: `values.yaml`, `values-local-k3s.yaml`, `values-demo-aws.yaml`, `values-home.yaml`.

Written in **M7**. Until then the only runtime is Docker Compose (`infra/compose`), and the OrbStack machine `hushold-k3s` (`make k3s-create`) only proves that a node comes up. See `docs/07-infrastructure.md`, section "Helm".
