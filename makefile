# targets that do not correspond to real files
.PHONY : prerequisites veryclean clean default serve build rebuild cleandist dist dist.*

default : build

# get most recent commit hash
COMMIT := $(shell git rev-parse --short  HEAD)

# construct archive names
ARCHIVE  := dist-$(COMMIT).tar
SUFFIXES := xz gz bz2 lz
ARCHIVES := $(addprefix $(ARCHIVE).,$(SUFFIXES))

prerequisites : themes/hackcss/LICENSE ;

## serve     : build and serve from memory
serve	: prerequisites
	hugo serve --disableFastRender --bind 0.0.0.0

## build     : use hugo to build the site [default]
## rebuild   : clean and build
build   : public/index.html ;
rebuild : veryclean build ;

# run hugo to build public site
public/index.html : prerequisites
	hugo --ignoreCache

# create compressed archive from built site
$(ARCHIVES) : public/index.html
	tar caf "$@" --directory public .

# aliases for different archives
## dist      : create a compressed archive of built site
## dist.%    : create a .% compressed archive (gz, xz, bz2, lz)
cleandist : clean dist.lz ;
dist 			: dist.lz ;
dist.% 		: $(ARCHIVE).% ;

# checkout theme submodules
themes/hackcss/LICENSE :
	git submodule update --init

## clean     : use git to clean untracked files and folders
clean :
	git clean -dfx

## veryclean : clean and deinit all submodules (themes)
veryclean : clean
	git submodule deinit --all --force

## help      : usage help
help :
	@sed -n 's/^##//p' makefile
