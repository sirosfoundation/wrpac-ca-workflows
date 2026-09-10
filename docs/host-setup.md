# Signer host setup for a registrar instance

Same host as the other SIROS signers (see `apt.siros.org/RUNNER-SETUP.md`);
this adds what the WRPAC CA needs. Ubuntu 22.04 or 24.04.

```sh
sudo apt-get install -y yubihsm-connector yubihsm-shell yubihsm-pkcs11 libyubihsm-usb1 libyubihsm-http1 file jq
sudo systemctl enable --now yubihsm-connector       # binds 127.0.0.1:12345 by default; keep it there
yubihsm-shell -a get-device-info

# The PKCS#11 module reads this path from YUBIHSM_PKCS11_CONF, which the
# workflows set. No PIN here, ever.
sudo tee /etc/yubihsm_pkcs11.conf >/dev/null <<EOF2
connector = http://127.0.0.1:12345
debug = 0
EOF2
```

`gh` 2.49 or newer lets `install-tool.sh` verify release attestations; older
prints a warning and relies on the pinned digest alone.

## Runner

Register on the organization, into the `signers` runner group, ephemeral, as
the existing `runner` user. Ephemeral means every job starts on a clean
runner; the `svc.sh` service re-registers after each job with a just-in-time
config, or use a small loop around `config.sh --ephemeral` with a fresh token.

```sh
./config.sh --url https://github.com/sirosfoundation --token <registration token> \
  --runnergroup signers --labels wrpac --name wrpac-signer-01 --ephemeral --unattended
```

The workflows select `runs-on: {group: signers, labels: [self-hosted, Linux]}`;
the extra `wrpac` label is for humans reading the runner list.

## Standby

Install identically, replicate the keys per the ceremony, and **do not
register the runner**. Failover is registering it and unregistering the
primary. Nothing else changes: the register names key labels, not devices.
