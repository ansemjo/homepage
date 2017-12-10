# targets that do not correspond to real files
.PHONY : clean build cleandist dist dist.*

# get most recent commit hash
COMMIT := $(shell git rev-parse --short  HEAD)

# construct archive names
ARCHIVE  := public-$(COMMIT).tar
SUFFIXES := xz gz bz2 lz
ARCHIVES := $(addprefix $(ARCHIVE).,$(SUFFIXES))

# default
build : public

# run hugo to build public site
public :
	hugo --ignoreCache

# create compressed archive from built site
$(ARCHIVES) : public
	tar caf "$@" public/*

# aliases for different archives
cleandist : clean dist.xz ;
dist 			: dist.xz ;
dist.% 		: $(ARCHIVE).% ;

# use git to clean untracked files and folders
clean :
	git clean -dfx
