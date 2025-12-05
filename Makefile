.PHONY: build run clean release lint

build:
	swift build

run:
	-pkill -x ClipMoar 2>/dev/null; sleep 0.5
	./scripts/release.sh debug
	mkdir -p dist
	rm -rf dist/ClipMoar.app
	cp -R .build/debug/ClipMoar.app dist/
	open dist/ClipMoar.app

clean:
	swift package clean
	rm -rf .build dist

release:
	./scripts/release.sh release
	mkdir -p dist
	rm -rf dist/ClipMoar.app
	cp -R .build/release/ClipMoar.app dist/

lint:
	./scripts/lint.sh
