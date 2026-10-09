# xcp-hl-rpm

Signed yum repositories for XCP-ng HomeLab Edition (XCP-HL), published at
<https://rpm.xcp-hl.org/> (xcp-hl#190). One Pages site serves every XCP-HL
repository, so the documentation site can be rebuilt without touching the
repositories hosts update from.

| Repository ID | Package | Path | Source |
|---|---|---|---|
| `xcp-hl-base` | `xcp-hl-release` | `/xcp-hl/8.3/x86_64/` | newest 10 releases of `Vagrantin/xcp-hl` |
| `xcp-hl-xolite` | `xo-lite-ce` | `/xolite-ce/8.3/x86_64/` | newest 5 releases of `Vagrantin/xolite-ce` |
| `xcp-hl-xoa-proxy` | `xoa-proxy` | `/xoa-proxy/8.3/x86_64/` | exactly `stable.json` on `xoa-proxy`'s `promotions` branch |
| `xcp-hl-xoa-proxy-testing` | `xoa-proxy` candidates | `/xoa-proxy/testing/8.3/x86_64/` | newest 5 pre-releases of `Vagrantin/xoa-proxy` |

The site root also serves the bootstrap `xcp-hl.repo`, `xcp-hl-xoa-proxy-testing.repo`,
`xcp-ng-ce-public.asc` and `manifest.txt` (what is published, used to skip no-op deploys).

Issues go to the [xcp-hl repository](https://github.com/Vagrantin/xcp-hl/issues).

## Layout

- `.github/workflows/publish.yml` builds, signs and deploys the site. It runs on push to
  `main`, hourly, on `workflow_dispatch`, and on `repository_dispatch` (type `rpm-publish`).
  It only deploys when `manifest.txt` differs from the live one.
- `scripts/build-simple.sh` builds one tree from a repo's newest releases.
- `scripts/build-xoa-proxy.sh` and `scripts/updateinfo.jq` are vendored from
  `xoa-proxy/pages/` at `ceefb6b`. Keep them in sync until the cut.
- `site/` is copied to the site root as is.
- `ci/check.sh` checks the `.repo` contract (section names, `gpgcheck=0` with
  `repo_gpgcheck=1`, URLs on `rpm.xcp-hl.org`) and the key fingerprint.

Secrets: `GPG_PRIVATE_KEY`, `GPG_PASSPHRASE` (same key as the source repos).
Pages source: GitHub Actions.

## DNS for rpm.xcp-hl.org

1. Verify the domain for the account first, so nobody else can claim a subdomain: GitHub
   profile Settings, Pages, Add a domain, `xcp-hl.org`. Create the TXT record it shows
   (`_github-pages-challenge-vagrantin.xcp-hl.org`), then click Verify.
2. Add the record at the DNS provider:

   | Name | Type | Value |
   |---|---|---|
   | `rpm` | `CNAME` | `vagrantin.github.io.` |

   The value is the account host only, without `/xcp-hl-rpm`. If the provider proxies
   traffic (Cloudflare orange cloud), set it to DNS only, or GitHub cannot issue the certificate.
3. If `xcp-hl.org` has CAA records, add `0 issue "letsencrypt.org"`.
4. In this repo, Settings, Pages, Custom domain: `rpm.xcp-hl.org`. With an Actions deployment
   this setting is what counts, a `CNAME` file in the site is ignored.
5. Once the DNS check passes and the certificate is issued (minutes to an hour), tick
   Enforce HTTPS.
6. Check: `dig +short rpm.xcp-hl.org` lists `vagrantin.github.io.` and `185.199.108-111.153`, and
   `curl -fsSI https://rpm.xcp-hl.org/xcp-hl.repo` returns 200.

## Transition and cut

Until the cut, installed hosts keep using the `vagrantin.github.io` URLs, which the source repos
still publish. This site mirrors them with the same rules.

1. Set up DNS and HTTPS (above), and check from an XCP-ng 8.3 host that the dom0 trusts the
   certificate: `curl -fsSI https://rpm.xcp-hl.org/xcp-hl.repo`, then `yum makecache` with
   `site/xcp-hl.repo`.
2. In `xcp-hl`, point `SOURCES/xcp-hl.repo` and `pages/xcp-hl.repo` at `rpm.xcp-hl.org`, and cut an
   `xcp-hl-release`. Hosts receive it from the old URL, then follow the new one.
3. Update the bootstrap instructions: xcp-hl docs (`updates.md` in en, fr, ja,
   `developers/xcp-ng-ce-iso.md`), `xolite-ce` and `xoa-proxy` READMEs, `pages/*.repo` and
   `pages/index.html`.
4. Make the source repos send `repository_dispatch` (`rpm-publish`) after a release or promotion,
   and repoint jenkins-infra `config/qa-streams.json` (`yum`, `pages_workflow`, `site_url`,
   `stable_url`, `key_url`) at this repo, so `agent/promote.sh` waits for this workflow.
5. After a grace period, drop the yum steps from `xcp-hl/.github/workflows/pages.yml` (docs only)
   and retire `pages-repo.yml` in `xolite-ce` and `xoa-proxy`.
