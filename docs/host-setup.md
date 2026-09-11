# Signer host setup for a registrar instance

Same shape as the other SIROS signer (`apt.siros.org/RUNNER-SETUP.md`), scripted
in [`scripts/host-setup.sh`](../scripts/host-setup.sh). Ubuntu 22.04 or 24.04
with the YubiHSM 2 on USB.

```sh
# on your machine: a one-hour registration token for the organization
gh api -X POST orgs/sirosfoundation/actions/runners/registration-token --jq .token

# on the host
sudo ./host-setup.sh --runner-token <token> --name wrpac-signer-01 --group signers --labels wrpac
```

What it does, idempotently:

- installs `yubihsm-connector`, `yubihsm-shell`, `yubihsm-pkcs11`, `gh` (2.49+
  so the runner can verify release attestations and comment on PRs), `jq`, `file`;
- enables the connector on `127.0.0.1:12345` and writes
  `/etc/yubihsm_pkcs11.conf` with the connector URL and nothing else;
- creates the `runner` user, installs the latest actions runner, registers it
  in the `signers` group with the extra label `wrpac`, and installs it as a
  systemd service. `YUBIHSM_PKCS11_CONF` is set in the runner's `.env` so every
  job sees it.

The runner is persistent, as the org's existing signer is: an ephemeral runner
needs an organization credential on the host to fetch a fresh registration per
job, which is a worse secret to keep there than a runner credential that can
only take jobs. Workflows check out fresh each run.

The workflows select `runs-on: {group: signers, labels: [self-hosted, Linux]}`.

## Standby

Run the same script **without** `--runner-token` after replicating the keys per
the ceremony: everything is installed, nothing is registered. Failover is
registering it and unregistering the primary. Nothing else changes: the
register names key labels, not devices.
