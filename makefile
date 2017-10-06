.PHONY : clean* dist* build

timestamp = date --utc +%FT%H-%M-%S%Z
tar_options = --create --auto-compress

dist.tar.xz : build
	tar $(tar_options) \
		--file dist.tar.xz dist/*

dist-timestamp.tar.xz : build
	tar $(tar_options) \
		--file dist-$$($(timestamp)).tar.xz dist/*

build : clean-dist
	hugo --ignoreCache

clean : clean-all

clean-dist :
	rm -rf dist/

clean-all : clean-dist
	rm -rf dist*.tar.xz