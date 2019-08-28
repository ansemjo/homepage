##>>> ansemjo/blog
.DEFAULT_GOAL := dist

# get most recent commit hash
COMMIT := $(shell git describe --always --abbrev --dirty)

# get theme name from config
THEME := $(shell sed -n 's/theme = "\(.*\)"/\1/p' config.toml)

##  serve     : build and serve from memory
.PHONY: serve
serve	: themes/$(THEME)/.git
	hugo serve --disableFastRender --bind 0.0.0.0

##  build     : use hugo to build the site
##  rebuild   : clean and build
.PHONY: build rebuild
build   : public/index.html ;
rebuild : veryclean build ;

##  deploy    : build and deploy the site
.PHONY: deploy
deploy : HOST := muliphein.semjonov.de
deploy : rebuild
	ansible-playbook -i $(HOST), -u ansible deploy.yml

# run hugo to build public site
public/index.html : themes/$(THEME)/.git $(shell find content/ -type f) config.*
	hugo --ignoreCache

# checkout theme submodules
themes/%/.git :
	git submodule update --init

##> dist      : create a compressed archive of built site
.PHONY: dist
ARCHIVE := dist-$(COMMIT).tar.gz
dist : $(ARCHIVE)
$(ARCHIVE) : public/index.html
	tar czf $@ -C public/ .

##  clean     : use git to clean untracked files and folders
.PHONY: clean
clean :
	git clean -fdx

##  veryclean : clean and deinit all submodules (themes)
.PHONY: veryclean
veryclean : clean
	git submodule deinit --all --force

##  help      : usage help
.PHONY: help
help :
	@sed -n 's/^##//p' makefile
