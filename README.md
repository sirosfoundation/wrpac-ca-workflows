# wrpac-ca-workflows

Reusable GitHub Actions workflows that run a [siros-wrpac-tool](https://github.com/sirosfoundation/siros-wrpac-tool)
Access CA and Registrar as a GitHub-operated service, with the signing keys on
a YubiHSM 2 behind a self-hosted runner.

One copy of these workflows serves every instance. An instance is two
repositories and a set of parameters:

| Repository | Written by | Holds |
|---|---|---|
| `<domain>` (registry) | humans, by pull request | `clients/<id>.yaml` + `clients/<id>.csr`, one per wallet-relying party |
| `<domain>-state` | the CA, via a deploy key | the deployment directory verbatim, issued material per client, and the GitHub Pages site serving the CRL, status list, register, LoTE and TSL at `https://<domain>/` |

With keys on a PKCS#11 token the deployment directory contains no secret, so
the whole CA state lives in git. GitHub carries authorization (who may propose
a registration, which team approves it and releases the signing job) and the
audit trail. The runner host carries possession of the token. The PIN is an
Environment secret released only to approved jobs, and the token is reachable
only from the host, so neither side alone can sign.

## Workflows

| Workflow | Runs on | Trigger in the registry repo | Does |
|---|---|---|---|
| `plan.yml` | GitHub-hosted | `pull_request` | validates specs and CSRs, posts the `apply --dry-run` plan as a PR comment, fails on an unintended re-registration |
| `apply.yml` | HSM runner, Environment-gated | `push` to `main` under `clients/**` | reconciles the register, republishes, commits state, reports serials back on the PR |
| `publish.yml` | HSM runner, Environment-gated | `schedule` | re-signs CRL, status list, LoTE and TSL inside their validity |
| `revoke.yml` | HSM runner, Environment-gated | `workflow_dispatch` | emergency revoke by client id; opens an issue to reconcile the spec |
| `bootstrap.yml` | HSM runner, Environment-gated | `workflow_dispatch`, once | `init` over the HSM keys; commits the new deployment |

The tool version and the SHA-256 of each release binary are defaults in these
workflows. An instance pins a ref of this repository (`@v1`, or a SHA) and
inherits them; bumping the tool is one pull request here and a ref bump there.
`install-tool.sh` refuses a binary whose digest differs from the pin and
verifies the release's SLSA attestation when the runner's `gh` can.

## Setting up an instance

[`docs/new-instance.md`](docs/new-instance.md) is the runbook: repositories,
rulesets, Environment, deploy key, Pages, DNS, runner, bootstrap.
[`docs/host-setup.md`](docs/host-setup.md) prepares a signer host, and
[`docs/hsm-ceremony.md`](docs/hsm-ceremony.md) generates the keys and
replicates them to a cold standby.

## Invariants the workflows protect

- **A signing job needs an approved deployment.** Every HSM job declares the
  caller's Environment, so its required reviewers gate the PIN.
- **One signer at a time per instance.** All HSM jobs share a concurrency group;
  the CRL number and status list indices advance in one order.
- **Deleting a spec does not revoke.** `--prune` is never passed. Take a party
  out with `revoked: true`, which is reversible.
- **An out-of-band revocation is not undone by accident.** `apply` treats a
  revoked entry with an unrevoked spec as a re-registration; the guard fails the
  job unless that client's spec was edited in the same change.
- **Nothing secret is committed.** The bootstrap job aborts if a key file
  appears in the deployment directory.

## License

BSD 2-Clause.
