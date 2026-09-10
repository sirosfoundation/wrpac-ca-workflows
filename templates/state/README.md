# __DOMAIN__ · CA state

The deployment directory of the __DOMAIN__ registrar, written only by the CA
through the workflows in [__REGISTRY_REPO__](https://github.com/__REGISTRY_REPO__).
Humans do not push here; a ruleset enforces it and the CA's deploy key is the
sole bypass.

| Path | What |
|---|---|
| `deployment/register.json` | the register: entries, CRL number, status indices, key *references* (never a PIN) |
| `deployment/ca.pem`, `deployment/registrar.pem` | the Access CA and registration certificate provider certificates; their keys are on the HSM |
| `deployment/issued/<serial>.pem` | every WRPAC ever issued |
| `deployment/public/` | what https://__DOMAIN__/ serves: `crl.der`, `status-list.jwt`, `register.json`, `lote.json`, `tsl.xml` |
| `clients/<id>/wrpac.pem`, `clients/<id>/wrprc.jwt` | current certificates per registered party |

Nothing in this repository is secret. With the keys on a PKCS#11 token the tool
writes no key file, and the bootstrap workflow aborts if one ever appears.

`git log` is the CA's audit trail; each commit names the registry commit or
workflow run that caused it.
