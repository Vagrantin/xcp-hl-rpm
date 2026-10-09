#!/usr/bin/env bash
# One yum tree from a source repo's newest releases, same rules as that repo's own Pages workflow.
# Metadata points each package at its release asset (xml:base); the workflow strips the RPMs before deploy.
# Env: REPO (owner/name), PKG_GLOB, KEEP, OUT (tree dir), ALLOW_EMPTY (true/false), GH_TOKEN.
set -euo pipefail
: "${REPO:?}" "${PKG_GLOB:?}" "${KEEP:?}" "${OUT:?}"
mkdir -p "$OUT"
tags=$(mktemp)

gh release list --repo "$REPO" --limit "$KEEP" --json tagName -q '.[].tagName' > "$tags"
echo "${REPO}: $(wc -l < "$tags") release(s) to scan (newest ${KEEP})"
while read -r tag; do
  [[ -n "$tag" ]] || continue
  gh release download "$tag" --repo "$REPO" --pattern "$PKG_GLOB" --dir "$OUT/$tag" \
    || echo "  (no RPM asset on ${tag})"
done < "$tags"
# A release re-cut from the same commit emits the same filename: keep only the newest tag's copy.
declare -A seen
while read -r tag; do
  for f in "$OUT/$tag"/*.rpm; do
    [[ -e "$f" ]] || continue
    if [[ -n "${seen[${f##*/}]:-}" ]]; then rm -f "$f"; else seen[${f##*/}]=1; fi
  done
done < "$tags"
rm -f "$tags"

count=$(find "$OUT" -name '*.rpm' | wc -l)
if [[ "$count" -eq 0 ]]; then
  [[ "${ALLOW_EMPTY:-false}" == true ]] || { echo "no ${PKG_GLOB} collected from ${REPO}" >&2; exit 1; }
  echo "::warning::no ${PKG_GLOB} in ${REPO}, ${OUT} left unpublished"
  rm -rf "$OUT"
  exit 0
fi
find "$OUT" -name '*.rpm' -printf '  %f\n' | sort

# XCP-ng 8.3 dom0 is CentOS 7 (yum 3.4.3): gz metadata, sqlite databases, no zchunk, no zstd.
ZCK=(); createrepo_c --help 2>&1 | grep -q -- '--no-zck' && ZCK=(--no-zck)
createrepo_c --help 2>&1 | grep -q -- '--general-compress-type' && ZCK+=(--general-compress-type=gz)
# href is TAG/NAME, so xml:base + href is the release asset URL.
createrepo_c --database --compress-type=gz --checksum=sha256 --retain-old-md=0 "${ZCK[@]}" \
  --baseurl "https://github.com/${REPO}/releases/download/" "$OUT" >/dev/null
echo "${OUT}: ${count} RPM(s)"
