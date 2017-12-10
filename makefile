# targets that do not correspond to real files
.PHONY : clean build theme cleandist dist dist.*

# get most recent commit hash
COMMIT := $(shell git rev-parse --short  HEAD)

# construct archive names
ARCHIVE  := public-$(COMMIT).tar
SUFFIXES := xz gz bz2 lz
ARCHIVES := $(addprefix $(ARCHIVE).,$(SUFFIXES))

## build  : use hugo to build the site [default]
build : theme public/index.html ;

# run hugo to build public site
public/index.html :
	hugo --ignoreCache

# create compressed archive from built site
$(ARCHIVES) : public/index.html
	tar caf "$@" public/*

# aliases for different archives
## dist   : create a compressed archive of built site
## dist.% : create a .% compressed archive (gz, xz, bz2, lz)
cleandist : clean dist.xz ;
dist 			: dist.xz ;
dist.% 		: $(ARCHIVE).% ;

## theme  : checkout theme submodules
theme : themes/hackcss/LICENSE ;
themes/hackcss/LICENSE :
	git submodule update --init

## clean  : use git to clean untracked files and folders
clean :
	git clean -dfx

## help   : usage help
help :
	@sed -n 's/^##//p' makefile
