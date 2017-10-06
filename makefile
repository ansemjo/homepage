.PHONY : clean* dist* build

timestamp = date --utc +%FT%H-%M-%S%Z
tar_options = --create --auto-compress

dist.txz : build
	tar $(tar_options) \
		--file dist.txz dist/*

dist-timestamp.txz : build
	tar $(tar_options) \
		--file dist-$$($(timestamp)).txz dist/*

build : clean-dist
	hugo --ignoreCache

clean : clean-all

clean-dist :
	rm -rf dist/

clean-all : clean-dist
	rm -rf dist*.txz