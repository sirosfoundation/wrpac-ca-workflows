# __DOMAIN__

The registrar and Access CA for wallet-relying parties in the __DOMAIN__
ecosystem. Registering here gets a party two certificates:

- a **WRPAC**, an X.509 access certificate (ETSI TS 119 411-8), and
- a **WRPRC**, a registration certificate as `rc-wrp+jwt` (ETSI TS 119 475),

which wallets use to authenticate the party and to check what it is registered
to ask for or to issue. Under CIR (EU) 2025/848 issuers of PIDs and attestations
are wallet-relying parties too, so this covers issuers as well as verifiers.

> Pilot infrastructure. Not a supervised trust service; certificates from this
> registrar have no standing outside the __DOMAIN__ ecosystem.

The registrar publishes at **https://__DOMAIN__/**: `crl.der`,
`status-list.jwt`, `register.json`, and the trust anchors as `lote.json`
(ETSI TS 119 602) and `tsl.xml` (ETSI TS 119 612). Issued certificates are in
[__STATE_REPO__](https://github.com/__STATE_REPO__) under `clients/<id>/`.

## Registering

1. **Generate a key and a CSR.** The key never leaves you; only the CSR is
   submitted. The registrar certifies the public key in it.

   ```sh
   openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
     -keyout <id>.key -out <id>.csr -subj "/CN=<your trade name>"
   ```

2. **Write the spec.** Copy [`examples/example-pid-provider.yaml`](examples/example-pid-provider.yaml)
   to `clients/<id>.yaml`, put the CSR beside it as `clients/<id>.csr`, and fill
   it in. `<id>` is yours for good: it ties every re-issuance to the same
   register entry. Lowercase, digits and hyphens.

3. **Open a pull request.** The `plan` check validates the spec and the CSR and
   comments with what would be issued. A member of the registrar team
   reviews; merging is the registration decision.

4. **Collect your certificates.** After the merge the CA signs and comments on
   your pull request with links to `wrpac.pem` and `wrprc.jwt`.

Changing anything in the spec re-issues both certificates under the same id and
revokes the previous ones. Set `revoked: true` to leave; do not delete the file,
deletion changes nothing on purpose.

## Who operates this

The registrar team is `@__TEAM__`. It reviews registrations and approves every
signing run. The tooling is [siros-wrpac-tool](https://github.com/sirosfoundation/siros-wrpac-tool)
driven by [wrpac-ca-workflows](https://github.com/sirosfoundation/wrpac-ca-workflows);
the keys are on a YubiHSM 2 that only a self-hosted runner can reach, and only
a job this team has approved carries the PIN.
