#!/bin/bash
# Print an org agenda JSON snapshot gathered from the running Emacs daemon.
# Usage: collect.sh [days] [next-keyword]

days=${1:-7}
next=${2-NEXT}
dir=$(dirname "$(realpath "$0")")
out=$(mktemp --tmpdir omarchy-org-agenda.XXXXXX)
trap 'rm -f "$out"' EXIT

quote() { local s=${1//\\/\\\\}; printf '"%s"' "${s//\"/\\\"}"; }

if ! timeout 30 emacsclient --eval "(progn
  (load $(quote "$dir/collect.el") nil t)
  (let ((coding-system-for-write 'utf-8))
    (with-temp-file $(quote "$out")
      (insert (omarchy-org-agenda-json $((days)) $(quote "$next")))))
  t)" >/dev/null 2>"$out.err"; then
  if grep -q "can't find socket\|No socket or alternate editor" "$out.err"; then
    msg="Emacs server is not running (start it with 'emacs --daemon' or M-x server-start)"
  else
    msg=$(head -c 300 "$out.err" | tr '\n' ' ')
  fi
  rm -f "$out.err"
  printf '{"error": %s}\n' "$(jq -Rn --arg m "${msg:-Emacs daemon is not reachable}" '$m')"
  exit 0
fi
rm -f "$out.err"
cat "$out"
