BINPATH := $(shell swift build --show-bin-path)

all: run

bin_setup:
	rm -f redist
	ln -s .build/checkouts/steamworks-swift/redist redist
	mkdir -p ${BINPATH}
	ln -sf ${CURDIR}/redist/lib/osx/* ${BINPATH}/
	echo 480 > ${BINPATH}/steam_appid.txt

run: bin_setup
	STEAMAPI_REDIST_DIR=${CURDIR} swift build
	swift run --skip-build
