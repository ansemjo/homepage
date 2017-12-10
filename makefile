# targets that do not correspond to real files
.PHONY : clean build theme cleandist dist dist.*

# get most recent commit hash
COMMIT := $(shell git rev-parse --short  HEAD)

# construct archive names
ARCHIVE  := public-$(COMMIT).tar
SUFFIXES := xz gz bz2 lz
ARCHIVES := $(addprefix $(ARCHIVE).,$(SUFFIXES))

# default
build : theme public/index.html ;

# run hugo to build public site
public/index.html :
	hugo --ignoreCache

# create compressed archive from built site
$(ARCHIVES) : build
	tar caf "$@" public/*

# aliases for different archives
cleandist : clean dist.xz ;
dist 			: dist.xz ;
dist.% 		: $(ARCHIVE).% ;

# checkout theme submodule
theme : themes/hackcss/LICENSE ;
themes/hackcss/LICENSE :
	git submodule update --init

# use git to clean untracked files and folders
clean :
	git clean -dfx
