.PHONY: build run clean release lint

build:
	swift build

run: build
	./scripts/release.sh debug
	open .build/debug/ClipMoar.app

clean:
	swift package clean
	rm -rf .build

release:
	./scripts/release.sh release

lint:
	./scripts/lint.sh
