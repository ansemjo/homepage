# --------- configuration ----------

# get most recent commit hash
COMMIT := $(shell git describe --always --abbrev --dirty)

# get theme name from config
THEME := $(shell sed -n 's/theme = "\(.*\)"/\1/p' config.toml)
THEMEMODULE := themes/$(THEME)/.git

# target to deploy to
DEPLOY := farouk.semjonov.de:/srv/www/semjonov.de/
RSYNCARGS :=

# default target to run
.DEFAULT_GOAL := build

# --------- targets ----------

##  serve     - build and serve from memory
.PHONY: serve
serve	: $(THEMEMODULE)
	hugo serve --disableFastRender --bind 0.0.0.0

##* build     - use hugo to build the site
.PHONY: build
build : public/index.html

public/index.html : $(THEMEMODULE) $(shell find content/ -type f) config.*
	hugo --ignoreCache

themes/%/.git :
	git submodule update --init themes/$*

# create a vendored theme archive
.PHONY: vendor-theme
vendor-theme : $(THEMEMODULE)
	cd $</.. && git archive -o "../$$(printf "%s-r%s-g%s.zip" \
		"$$(basename "$$PWD")" \
		"$$(git rev-list --count HEAD)" \
		"$$(git rev-parse --short HEAD)")" HEAD

##  new       - write a new blog post
.PHONY: new
new :
	@read -p 'Enter path: ' -ei 'posts/$(shell date +%Y)/newpost' path && \
	hugo new "$$path/index.md" && \
	$$EDITOR "content/$$path/index.md";

##  deploy    - build and deploy the site
.PHONY: deploy
deploy : clean build
	rsync --archive $(RSYNCARGS) --chown=root:root public/ $(DEPLOY)

##  dist      - create a compressed archive of built site
.PHONY: dist
ARCHIVE := homepage-$(COMMIT).tar.gz
dist : $(ARCHIVE)
$(ARCHIVE) : clean build
	tar czf $@ -C public/ .

##  clean     - remove built public/ site
.PHONY: clean
clean :
	rm -rf public/

##  veryclean - use git to clean files and deinit all submodules
.PHONY: veryclean
veryclean : clean
	git submodule deinit --all --force
	git clean -fdx

.PHONY: help
help :
	@echo -e "\033[1mconfiguration:\033[0m"
	@echo "  commit    = $(COMMIT)"
	@echo "  theme     = $(THEME)"
	@echo "  deploy    = $(DEPLOY)"
	@echo -e "\033[1mavailable targets:\033[0m"
	@sed -n 's/^##//p' makefile
