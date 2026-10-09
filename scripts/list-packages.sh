#!/usr/bin/env bash
# HTML list of a stable tree's packages, from build-promoted.sh's stable.list. Args: LIST BASEURL.
set -euo pipefail
list="$1" baseurl="$2"
cat <<EOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>XCP-HL yum repository</title>
<style>body{max-width:46rem;margin:3rem auto;padding:0 1.2rem;font:16px/1.6 system-ui,sans-serif}code{font-family:ui-monospace,monospace}</style>
</head>
<body>
<h1>XCP-HL yum repository</h1>
<p>Repository baseurl: <code>${baseurl}</code></p>
<p>Metadata: <a href="repodata/repomd.xml">repodata/repomd.xml</a></p>
<h2>Packages</h2>
<ul>
EOF
cut -d' ' -f2 "$list" | sort | while read -r rpm; do echo "<li><a href=\"${rpm}\">${rpm}</a></li>"; done
cat <<EOF
</ul>
<p><a href="/">Back to the site root</a></p>
</body>
</html>
EOF
