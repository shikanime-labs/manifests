<!-- owner: shikanime | zone: internal | purpose: known failure modes and fixes -->

# Troubleshooting

## Pods stay unscheduled / crash on startup

The VPA controller must be present — every app and operator `base` ships a
`vpa.yaml`. Missing VPA leaves workloads without recommendations.

## KubeVirt VMs will not start

`/dev/kvm` must exist on the node (Intel `vmx` / AMD `svm` in
`/proc/cpuinfo`); for nested virt, enable it on the hypervisor. Absent `/dev/kvm`
falls back to slow emulation unless `useEmulation` is set. `virt-handler`
schedules off the `nodes.kubevirt.io/resource/kvm` label NFD publishes.

## SOPS field not decrypting

Only keys matched by the per-app `encrypted_regex` are ciphertext; the rest
stays plaintext. If a value is not decrypting, confirm it matches the regex
and that Flux's SOPS integration has the age key. Never commit the stripped
`.enc.` output — change the encrypted source.

## KubeVirt has no Helm chart

KubeVirt installs via the operator + CR manifest pair under
`infrastructure/kubevirt/`, diverging from the `HelmRelease` pattern used
elsewhere. Don't "fix" it to a chart; it is intentional.
