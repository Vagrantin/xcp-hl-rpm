#!/usr/bin/env bash
# PR and publish check (xcp-hl#190): .repo contract, settings, and URLs on rpm.xcp-hl.org.
# Local: run from a clean checkout with python3 and shellcheck (shellcheck is skipped when absent).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> shellcheck"
if command -v shellcheck >/dev/null; then shellcheck ci/*.sh scripts/*.sh; else echo "shellcheck not installed, skipped"; fi

echo "==> .repo files: the section contract, the security settings and the host"
python3 - <<'PY'
import configparser, sys
HOST = 'https://rpm.xcp-hl.org/'
KEY = HOST + 'xcp-ng-ce-public.asc'
# Section names are read by XCP-ng's updater.py through xoa-hl's patch: renaming one hides its updates.
FILES = {
    'site/xcp-hl.repo': (['xcp-hl-base', 'xcp-hl-xolite', 'xcp-hl-xoa-proxy'],
                         {'enabled': '1', 'skip_if_unavailable': 'True'}),
    'site/xcp-hl-xoa-proxy-testing.repo': (['xcp-hl-xoa-proxy-testing'],
                                           {'enabled': '0', 'skip_if_unavailable': 'False'}),
    # Appliance plane: dnf inside the XOA-HL VM, read by xoa-hl's update units, not by updater.py.
    'site/xoa-hl.repo': (['xoa-hl'], {'enabled': '1', 'skip_if_unavailable': 'False'}),
    'site/xoa-hl-testing.repo': (['xoa-hl-testing'], {'enabled': '0', 'skip_if_unavailable': 'False'}),
}
BASE = {'gpgcheck': '0', 'repo_gpgcheck': '1', 'gpgkey': KEY}
bad = []
for path, (sections, want) in FILES.items():
    c = configparser.ConfigParser(interpolation=None)
    c.read(path)
    if c.sections() != sections:
        bad.append(f'{path}: sections {c.sections()}, want {sections}')
        continue
    for s in sections:
        for k, v in {**BASE, **want}.items():
            if c[s].get(k) != v:
                bad.append(f'{path} [{s}] {k}={c[s].get(k)}, want {v}')
        url = c[s].get('baseurl', '')
        if not (url.startswith(HOST) and url.endswith('/8.3/x86_64/')):
            bad.append(f'{path} [{s}] baseurl {url} is not an 8.3 tree on {HOST}')
print('\n'.join(bad) or 'ok')
sys.exit(1 if bad else 0)
PY

echo "==> the published key is the XCP-ng CE master key"
gpg --show-keys --with-colons site/xcp-ng-ce-public.asc | grep -q '^fpr:.*:2F591DB9D2C128C4C3D963F46DA00DCA5BBA215A:'

echo "ci/check.sh passed"
