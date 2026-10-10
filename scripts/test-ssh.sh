#!/bin/bash
# Owns only a temporary loopback sshd, generated test keys, and temporary files.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p build
fixture="$PWD/build/ssh-fixture"
# Refuse an existing fixture instead of replacing anyone's configuration.
mkdir "$fixture"
fixture_pid=''
cleanup() {
  if [[ -n "$fixture_pid" ]]; then kill "$fixture_pid" 2>/dev/null || true; wait "$fixture_pid" 2>/dev/null || true; fi
  rm -rf "$fixture"
}
trap cleanup EXIT
umask 077
ssh-keygen -q -t ed25519 -N '' -f "$fixture/host"
ssh-keygen -q -t ed25519 -N '' -f "$fixture/client"
fixture_user=$(id -un)
cat > "$fixture/sshd_config" <<CONFIG
Port 42891
ListenAddress 127.0.0.1
HostKey $fixture/host
PidFile $fixture/pid
AuthorizedKeysFile $fixture/client.pub
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM no
StrictModes yes
AllowUsers $fixture_user
CONFIG
cat > "$fixture/config" <<CONFIG
Host parity-fixture
 HostName 127.0.0.1
 User $fixture_user
 Port 42891
 IdentityFile $fixture/client
 IdentitiesOnly yes
 UserKnownHostsFile $fixture/known_hosts
 StrictHostKeyChecking yes
 BatchMode yes
 ConnectTimeout 2
CONFIG
read -r algorithm material remainder < "$fixture/host.pub"
printf '[127.0.0.1]:42891 %s %s\n' "$algorithm" "$material" > "$fixture/known_hosts"
/usr/sbin/sshd -D -f "$fixture/sshd_config" -E "$fixture/log" &
fixture_pid=$!
ready=false
for attempt in {1..25}; do
  kill -0 "$fixture_pid" 2>/dev/null || { cat "$fixture/log" >&2; exit 1; }
  if /usr/bin/ssh -F "$fixture/config" parity-fixture /usr/bin/true 2>/dev/null; then ready=true; break; fi
  sleep 0.2
done
[[ "$ready" == true ]] || { cat "$fixture/log" >&2; exit 1; }
HERDRX_TEST_SSH_CONFIG="$fixture/config" swift test --package-path Core -c release
