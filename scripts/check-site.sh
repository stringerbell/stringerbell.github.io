#!/usr/bin/env bash
# Smoke test for the built site: every URL that existed on the old hand-built site
# must still exist, so a layout/config change can't silently drop live content.
set -euo pipefail
out=${1:-public}
fail=0
need() { # path substring-to-expect
  local f="$out/$1"
  if [ ! -s "$f" ]; then echo "MISSING  $1"; fail=1; return; fi
  if [ -n "${2:-}" ] && ! grep -q -- "$2" "$f"; then echo "BAD      $1 (expected: $2)"; fail=1; return; fi
  echo "ok       $1"
}
need index.html                                                    "Recent Posts"
need index.xml                                                     "<rss"
need sitemap.xml                                                   "<urlset"
need 404.html                                                      "gopher.png"
need CNAME                                                         "dannstockton.com"
need about/index.html                                              "Baking Bread"
need bread/index.html                                              'gallery-card'
need posts/index.html                                              "Building Slack Slash Commands"
need posts/index.xml                                               "<rss"
need posts/why-i-taught-myself-how-to-code/index.html              "geocities"
need posts/building-slack-slash-commands-for-fun-and-profit/index.html "language-php"
# line-numbered code blocks must render inline (not as a table the theme CSS breaks)
if grep -q '<table style="border-spacing:0' "$out/posts/building-slack-slash-commands-for-fun-and-profit/index.html"; then echo "BAD      line numbers rendered as a table"; fail=1; fi
need posts/using-machine-learning-to-summarize-meeting-notes/index.html "ml-notes.gif"
need resume/index.html                                             "Dann Stockton"
need resume.json                                                   '"basics"'
need resume.pdf
need public/index.html
need 2013/12/02/why-i-taught-myself-how-to-code.html               "refresh"
need 2016/05/30/building-slack-slash-commands-for-fun-and-profit.html "refresh"
need 2018/05/30/using-machine-learning-to-summarize-meeting-notes.html "refresh"
need assets/css/main.d751652e.css
need assets/js/main.69694257.js
need css/custom.css
need css/gallery.css
need images/logo.png
need images/ml-notes.gif
need favicon.ico
# the theme shell must be present on every html page
for f in index.html about/index.html bread/index.html posts/index.html; do
  grep -q "sidebar-toggler" "$out/$f" || { echo "BAD      $f (no sidebar/menu shell)"; fail=1; }
done
# drafts must never leak into a production build
if grep -rl "draft-marker-do-not-publish" "$out" >/dev/null 2>&1; then echo "BAD      draft content published"; fail=1; fi
[ $fail -eq 0 ] && echo "all checks passed" || { echo "CHECKS FAILED"; exit 1; }
