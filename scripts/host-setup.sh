#!/usr/bin/env bash
# Prepare a signer host for a registrar instance and register its runner.
# Idempotent: safe to re-run. Run as root (sudo). Ubuntu 22.04 / 24.04.
#
#   host-setup.sh --runner-token <token> [--name wrpac-signer-01] [--group signers] [--labels wrpac]
#
# The token is an organization runner *registration* token, valid one hour:
#   gh api -X POST orgs/sirosfoundation/actions/runners/registration-token --jq .token
# Nothing GitHub-related persists on the host except the runner's own
# credentials, which let it take jobs and nothing else. No PIN is stored here.
set -euo pipefail

ORG_URL="https://github.com/sirosfoundation"
NAME="wrpac-signer-01"; GROUP="signers"; LABELS="wrpac"; TOKEN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runner-token) TOKEN="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --group) GROUP="$2"; shift 2 ;;
    --labels) LABELS="$2"; shift 2 ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done
[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

echo "== packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q yubihsm-connector yubihsm-shell yubihsm-pkcs11 libyubihsm-usb1 libyubihsm-http1 \
  curl git jq file ca-certificates openssl >/dev/null
# gh >= 2.49 verifies release attestations and posts PR comments from the runner.
if ! command -v gh >/dev/null || ! gh attestation --help >/dev/null 2>&1; then
  install -dm755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
  apt-get update -q && apt-get install -y -q gh >/dev/null
fi
echo "gh $(gh --version | head -1)"

echo "== yubihsm-connector on loopback"
systemctl enable --now yubihsm-connector
sleep 1
curl -fsS http://127.0.0.1:12345/connector/status | sed 's/^/   /'

echo "== PKCS#11 module config (no PIN)"
cat > /etc/yubihsm_pkcs11.conf <<'CONF'
connector = http://127.0.0.1:12345
debug = 0
CONF
chmod 0644 /etc/yubihsm_pkcs11.conf
MODULE="$(ls /usr/lib/*/pkcs11/yubihsm_pkcs11.so 2>/dev/null | head -1)"
echo "   module: ${MODULE:-NOT FOUND}"

echo "== runner user"
id runner >/dev/null 2>&1 || useradd -m -s /bin/bash runner
# the connector talks USB; the runner only talks HTTP to the connector, so no
# USB group membership is needed for it.

echo "== actions runner"
RUNNER_HOME=/home/runner/actions-runner
if [[ ! -x "$RUNNER_HOME/run.sh" ]]; then
  ARCH="$(uname -m)"; case "$ARCH" in x86_64) RARCH=x64 ;; aarch64) RARCH=arm64 ;; *) echo "unsupported $ARCH" >&2; exit 1 ;; esac
  VER="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name | sed 's/^v//')"
  TGZ="actions-runner-linux-${RARCH}-${VER}.tar.gz"
  sudo -u runner mkdir -p "$RUNNER_HOME"
  sudo -u runner curl -fsSL -o "$RUNNER_HOME/$TGZ" "https://github.com/actions/runner/releases/download/v${VER}/${TGZ}"
  SUM="$(curl -fsSL "https://github.com/actions/runner/releases/download/v${VER}/${TGZ}.sha256" 2>/dev/null || true)"
  if [[ -n "$SUM" ]]; then echo "${SUM%% *}  $RUNNER_HOME/$TGZ" | sha256sum -c -; fi
  sudo -u runner tar -xzf "$RUNNER_HOME/$TGZ" -C "$RUNNER_HOME" && rm -f "$RUNNER_HOME/$TGZ"
  "$RUNNER_HOME/bin/installdependencies.sh" >/dev/null
fi

if [[ ! -f "$RUNNER_HOME/.runner" ]]; then
  [[ -n "$TOKEN" ]] || { echo "runner not registered and no --runner-token given" >&2; exit 1; }
  # The PKCS#11 module reads its config from this variable; setting it in the
  # runner's .env makes it available to every job without each workflow
  # knowing the host layout.
  echo "YUBIHSM_PKCS11_CONF=/etc/yubihsm_pkcs11.conf" | sudo -u runner tee "$RUNNER_HOME/.env" >/dev/null
  sudo -u runner "$RUNNER_HOME/config.sh" --unattended --replace \
    --url "$ORG_URL" --token "$TOKEN" \
    --runnergroup "$GROUP" --labels "$LABELS" --name "$NAME" --work _work
  ( cd "$RUNNER_HOME" && ./svc.sh install runner && ./svc.sh start )
else
  echo "   already registered as $(jq -r .agentName "$RUNNER_HOME/.runner")"
  ( cd "$RUNNER_HOME" && ./svc.sh status | tail -3 )
fi

echo "== summary"
echo "   connector : $(systemctl is-active yubihsm-connector)"
echo "   device    : $(yubihsm-shell -a get-device-info 2>&1 | grep -iE 'serial|version' | tr '\n' ' ')"
echo "   runner    : $(systemctl is-active 'actions.runner.*' 2>/dev/null | head -1)"
echo "   next      : key ceremony (docs/hsm-ceremony.md), then YUBIHSM_PIN on the Environment, then bootstrap"
