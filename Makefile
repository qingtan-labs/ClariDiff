.PHONY: build test app cli release clean

build:
	swift build

test:
	swift test

app:
	./scripts/build-app.sh

cli:
	swift build -c release --product claridiff

release:
	./scripts/build-release.sh

clean:
	swift package clean
