# dannstockton.com

Personal site, built with [Hugo](https://gohugo.io/) and deployed to GitHub Pages by
GitHub Actions on every push to `main`. The look is the old Minimo theme, extracted into
`layouts/` so nothing depends on an external theme.

## Publishing (the short version)

```sh
make new-post name=my-new-post   # creates content/posts/my-new-post.md as a draft
make serve                       # preview at http://localhost:1313 (drafts included)
# ...edit the markdown, set draft: false...
make publish msg="Add my new post"   # builds, smoke-tests, commits, pushes -> live in ~1 min
```

`make help` lists everything.

## What goes where

| I want to…                        | Do this                                                                 |
|-----------------------------------|-------------------------------------------------------------------------|
| write a blog post                 | `make new-post name=slug` → edit `content/posts/slug.md`                |
| add a standalone page (`/foo/`)   | `make new-page name=foo` → edit `content/foo.md`; add to `[menus]` in `hugo.toml` if it belongs in the nav |
| add a photo gallery (`/pizza/`)   | `make new-gallery name=pizza` → drop images into `content/pizza/`; order + captions live in `content/pizza/index.md` |
| put an image in a post            | drop it in `static/images/` and use `{{< figure src="/images/foo.png" alt="..." >}}` (or plain markdown `![alt](/images/foo.png)`) |
| update the resume                 | edit `static/resume.json`, then `make resume` (HTML) or `make resume-pdf` (HTML + PDF via headless Chrome). Note: the current `static/resume/index.html` was hand-tweaked, so the first regenerated version will look a little different (stock `jsonresume-theme-even`). Hand-editing that file directly still works too. |
| change the nav / title / accent   | `hugo.toml`                                                             |
| change the look                   | `layouts/` (templates), `static/css/custom.css` (overrides), `static/css/gallery.css` |

Anything in `static/` is copied to the site verbatim, so hand-made HTML (`static/public/`,
`static/resume/`, the old `/2013/...` redirect stubs) keeps working untouched.

## Safety net

`make check` builds the site and runs `scripts/check-site.sh`, which asserts that every URL
that existed on the old site still exists in the build (posts, about, bread, resume, redirects,
feeds, CSS/JS). CI runs the same check before deploying, so a bad layout change can't
silently take a page down.

## One-time setup on a new machine

```sh
brew install hugo       # site generator
npm install             # only needed for `make resume`
```

## One-time setup already done for the repo

GitHub Pages must deploy from the Actions workflow rather than from the `main` branch root.
`make pages-setup` flips that setting (needs `gh` logged in). It only has to be run once.
