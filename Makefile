SCRATCH ?= .build/main

.PHONY: build test release app run install xcodebuild-check clean

build:
	swift build --scratch-path $(SCRATCH)

test:
	swift test --scratch-path $(SCRATCH)

release:
	swift build -c release --scratch-path $(SCRATCH)

app: release
	bash scripts/bundle.sh $(SCRATCH)

run: app
	open dist/Ordo.app

install: app
	ditto dist/Ordo.app /Applications/Ordo.app
	@echo "installed /Applications/Ordo.app"

xcodebuild-check:
	xcodebuild -scheme OrdoApp -destination 'platform=macOS' -derivedDataPath .build/xcode build

clean:
	rm -rf .build dist
