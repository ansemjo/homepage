##* build     - use hugo to build the site
HUGOARGS := --gc --minify
.PHONY: build
build : public/index.html
public/index.html : config.toml makefile $(shell find content/ -type f)
	git submodule update --init --recursive
	hugo --ignoreCache $(HUGOARGS)

##  serve     - build and serve from memory
.PHONY: serve
serve	:
	git submodule update --init --recursive
	hugo serve --disableFastRender $(HUGOARGS)

##  new       - write a new blog post
.PHONY: new
new :
	@read -p 'Enter path: ' -ei 'posts/$(shell date +%Y)/newpost/' path && \
	hugo new "$$path/index.md" && \
	$$EDITOR "content/$$path/index.md";

##  deploy    - build and deploy the site
DEPLOY 		:= farouk.semjonov.de:/srv/www/semjonov.de/
RSYNCARGS :=
.PHONY: deploy
deploy : clean build
	rsync --archive $(RSYNCARGS) --chown=root:root public/ $(DEPLOY)

##  dist      - create a compressed archive of built site
VERSION = $(shell printf "r%s-g%s" "$$(git rev-list --count HEAD)" "$$(git rev-parse --short HEAD)")
ARCHIVE = homepage-$(VERSION).tar.gz
.PHONY: dist
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
	@echo -e "\033[1mavailable targets:\033[0m"
	@sed -n 's/^##//p' makefile
