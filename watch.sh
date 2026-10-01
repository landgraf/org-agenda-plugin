#!/bin/bash
# Print a line whenever an org agenda file is saved, so the widget can refresh
# right away instead of waiting for its timer. Needs inotify-tools; without it
# this idles and the widget falls back to timed refreshes.

command -v inotifywait >/dev/null || exec sleep infinity

agenda_dirs() {
  timeout 30 emacsclient --eval \
    '(mapconcat (quote identity) (delete-dups (mapcar (quote file-name-directory) (org-agenda-files nil (quote ifmode)))) "\n")' 2>/dev/null |
    sed -e 's/^"//' -e 's/"$//' -e 's/\\n/\n/g'
}

# The Emacs daemon may come up after the shell does; keep asking until it answers.
existing=()
until (( ${#existing[@]} )); do
  while IFS= read -r dir; do
    [[ -n $dir && -d $dir ]] && existing+=("$dir")
  done < <(agenda_dirs)
  (( ${#existing[@]} )) || sleep 60
done

exec inotifywait -mq -e close_write,moved_to --include '\.org$' "${existing[@]}"
