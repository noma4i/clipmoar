.PHONY: build run clean release lint

build:
	swift build

run:
	-pkill -x ClipMoar 2>/dev/null; sleep 0.5
	./scripts/release.sh debug
	open .build/debug/ClipMoar.app

clean:
	swift package clean
	rm -rf .build

release:
	./scripts/release.sh release

lint:
	./scripts/lint.sh
