# dannstockton.com — Hugo site. `make help` lists targets.
HUGO        ?= hugo
REPO        ?= stringerbell/stringerbell.github.io
DATE        := $(shell date +%Y-%m-%d)
RESUME_HTML := static/resume/index.html
RESUME_PDF  := static/resume.pdf
CHROME      ?= /Applications/Google Chrome.app/Contents/MacOS/Google Chrome

.PHONY: help serve build check clean new-post new-page new-gallery resume resume-pdf publish pages-setup

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

serve: ## Live-preview the site (includes drafts) at http://localhost:1313
	$(HUGO) server -D --navigateToChanged

build: ## Build the site into ./public
	$(HUGO) --gc --minify

check: build ## Build, then verify every URL that used to exist still does
	./scripts/check-site.sh public

clean: ## Remove build output
	rm -rf public resources/_gen

# ---- creating content -------------------------------------------------------
# usage: make new-post name=my-post-title
new-post: ## Create content/posts/<name>.md (draft) — usage: make new-post name=my-post-title
	@test -n "$(name)" || { echo "usage: make new-post name=my-post-title"; exit 1; }
	$(HUGO) new content/posts/$(name).md
	@echo "-> edit content/posts/$(name).md, set draft: false when ready, then: make publish"

# usage: make new-page name=projects
new-page: ## Create a standalone page at /<name>/ — usage: make new-page name=projects
	@test -n "$(name)" || { echo "usage: make new-page name=projects"; exit 1; }
	$(HUGO) new content/$(name).md
	@echo "-> edit content/$(name).md; add it to [menus] in hugo.toml if you want it in the nav"

# usage: make new-gallery name=pizza  (then drop images into content/pizza/)
new-gallery: ## Create a photo gallery at /<name>/ — usage: make new-gallery name=pizza
	@test -n "$(name)" || { echo "usage: make new-gallery name=pizza"; exit 1; }
	$(HUGO) new --kind gallery content/$(name)
	@echo "-> drop .jpg/.png files into content/$(name)/ and edit captions in content/$(name)/index.md"

# ---- resume -----------------------------------------------------------------
resume: node_modules ## Re-render static/resume/index.html from static/resume.json
	npx resumed render static/resume.json --theme jsonresume-theme-even --output $(RESUME_HTML)

resume-pdf: resume ## Re-render the resume, then print it to static/resume.pdf with headless Chrome
	"$(CHROME)" --headless=new --disable-gpu --no-pdf-header-footer \
		--print-to-pdf="$(abspath $(RESUME_PDF))" "file://$(abspath $(RESUME_HTML))"

node_modules: package.json
	npm install
	@touch node_modules

# ---- publishing -------------------------------------------------------------
publish: check ## Commit everything and push; GitHub Actions builds + deploys to dannstockton.com
	git add -A
	git commit -m "$(if $(msg),$(msg),Publish $(DATE))" || true
	git push origin main

pages-setup: ## One-time: tell GitHub Pages to deploy from the Actions workflow instead of the branch
	gh api -X PUT repos/$(REPO)/pages -f build_type=workflow
	@echo "-> GitHub Pages now deploys from .github/workflows/deploy.yml"
