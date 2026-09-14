# Runbook: a new registrar instance

Worked for `wrpac.siros.org`. Replace the domain, team and names for another.

Decide these first; two of them are permanent:

| Parameter | Example | Notes |
|---|---|---|
| domain | `wrpac.siros.org` | **permanent**: `init` bakes `https://<domain>` into every certificate as CRL distribution point and status list URI |
| registrar team | `@sirosfoundation/wrpac-siros-org-registrars` | CODEOWNER of `clients/` and required reviewer on the Environment; managed outside this setup |
| CA / registrar names, organization, country | `SIROS Access CA`, `SIROS Registration Certificate Provider`, `SIROS Foundation`, `SE` | in the certificates |
| CRL / status list validity | `168h` / `168h` | **recorded at bootstrap**; the publish schedule must run well inside the shorter one |
| key labels on the HSM | `wrpac-ca`, `wrpac-registrar` | must match the ceremony |

## 1. Repositories

Create `<domain>` (registry) and `<domain>-state` from the templates in
`templates/registry` and `templates/state`. Both public. Fill in the domain,
the team slug and the state repo name in the workflow files and CODEOWNERS.

## 2. Rulesets

Registry `main`: pull request required, one approval, code owner review
required, required status check `plan`, no force push, no deletion. No bypass
actors. Applies to admins.

State `main`: pull request required, no force push, no deletion, and **one
bypass actor: the deploy key** (actor type `DeployKey`). Humans cannot push
to the CA state; the CA can.

## 3. Deploy key

Generate an Ed25519 key, add the public half to the state repo as a deploy key
**with write access**, put the private half in the registry repo's `ca`
Environment as `STATE_DEPLOY_KEY`, then destroy the local copy. `apply`,
`publish`, `revoke` and `bootstrap` push state with it.

## 4. Environment `ca` on the registry repo

- Deployment branches: `main` only.
- Required reviewers: the registrar team.
- Secrets: `STATE_DEPLOY_KEY` (step 3) and `YUBIHSM_PIN`. The PIN is the
  operational auth key's 4-hex-digit ID followed by its password, from the
  ceremony. It lives nowhere else.

## 5. Actions settings on the registry repo

- Fork pull request workflows: **require approval for all outside
  collaborators**. `plan` runs on hosted runners, but a fork could edit the
  workflow file; approval keeps that off the signer.
- Give the repository access to the `signers` runner group (organization
  settings, or `PUT /orgs/{org}/actions/runner-groups/{id}/repositories/{repo_id}`).

## 6. Pages and DNS

Enable Pages on the state repo with **GitHub Actions** as the source and
`<domain>` as the custom domain. Create a DNS `CNAME` for `<domain>` pointing
at `sirosfoundation.github.io`. Turn on *Enforce HTTPS* once the certificate
is provisioned. The state repo's `pages.yml` serves `deployment/public/` at
the site root, plus a small index.

## 7. Host and keys

Follow [`host-setup.md`](host-setup.md) and [`hsm-ceremony.md`](hsm-ceremony.md).
The runner joins the `signers` group.

## 8. Bootstrap

Until this step, keep the registry repo's `publish` workflow **disabled**
(`gh workflow disable publish.yml -R <registry>`): its schedule can only fail
at secret validation while `YUBIHSM_PIN` does not exist, and every failure is
a red run and an email.

Run the registry repo's `bootstrap` workflow once with the parameters from
the table. It refuses to run twice. Check the first Pages deploy at
`https://<domain>/register.json`, `/crl.der`, `/status-list.jwt`,
`/lote.json`, `/tsl.xml`. Then `gh workflow enable publish.yml -R <registry>`.

## 9. Publish cadence

`publish.yml` in the registry repo defaults to every second day at 03:17 UTC
against a one-week validity. Change both together, never one.
