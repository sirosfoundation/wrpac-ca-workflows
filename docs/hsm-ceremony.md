# Key ceremony for a registrar instance

Two P-256 signing keys on the YubiHSM 2, one operational auth key that can do
nothing but sign with them, and a wrapped copy of both keys on the standby
device. Decide at generation whether the keys may ever be backed up:
`exportable-under-wrap` cannot be added later.

Domain 3 is used below; pick an unused one per instance so the operational
auth key cannot see another instance's keys on a shared device.

**Check the argument order before typing.** yubihsm-shell's positional syntax
has changed between releases (Yubico's reference lists `put authkey` as
`session, id, label, domains, capabilities, algorithm, key` in one version and
`..., capabilities, delegated_capabilities, password` in another). Run
`help put authkey`, `help generate wrapkey`, `help get wrapped`, `help put
wrapped` and `help put option` on the installed version and adapt. What must
not change: the labels, the domain, `sign-ecdsa` as the only capability on the
operational key, and `exportable-under-wrap` on the two signing keys.

## On the primary

```
yubihsm-shell
> connect
> session open 1 <admin password>

# Wrap key for backup, AES-256, ceremony-only.
> generate wrapkey 0 0x0300 wrpac-wrap 3 export-wrapped,import-wrapped sign-ecdsa,exportable-under-wrap aes256

# The two signing keys. Labels are what the register records.
> generate asymmetric 0 0x0301 wrpac-ca        3 sign-ecdsa,exportable-under-wrap ecp256
> generate asymmetric 0 0x0302 wrpac-registrar 3 sign-ecdsa,exportable-under-wrap ecp256

# Operational auth key: sign only, domain 3, no delegated capabilities.
# Its ID in hex followed by its password is the PIN the workflows use.
> put authkey 0 0x0310 wrpac-ops 3 sign-ecdsa none <ops password>

# Enable the audit log and make it blocking for signatures (the device
# refuses to sign when the log is full and unread), then read it regularly.
> put option force-audit 01

> get pubkey 0 0x0301
> get pubkey 0 0x0302

# Backup: wrapped export of both keys.
> get wrapped 0 0x0300 asymmetric-key 0x0301 wrpac-ca.wrapped
> get wrapped 0 0x0300 asymmetric-key 0x0302 wrpac-registrar.wrapped
> session close 0
```

Export the wrap key material for the standby by splitting it: `yubihsm-setup`
does Shamir shares, or generate the wrap key from known material with
`put wrapkey` on both devices instead of `generate wrapkey`. Either way the
material never touches the runner host in the clear after the ceremony.

## On the standby

```
> put wrapkey 0 0x0300 wrpac-wrap 3 export-wrapped,import-wrapped sign-ecdsa,exportable-under-wrap <32 bytes hex>
> put wrapped 0 0x0300 wrpac-ca.wrapped
> put wrapped 0 0x0300 wrpac-registrar.wrapped
> put authkey 0 0x0310 wrpac-ops 3 sign-ecdsa none <same ops password>
```

Object IDs and labels survive import, so `KeyByLabel` finds the same key on
either device.

## Afterwards

- `YUBIHSM_PIN` Environment secret = `0310` + ops password.
- Store the admin password, the wrap shares and the `.wrapped` files offline,
  separately. Delete them from every host.
- The tool creates no keys: `bootstrap` certifies these two.
