.PHONY: build test app release install clean

build:
	swift build

test:
	swift run KuatiLayoutTests

app:
	./scripts/build-app.sh release

release:
	./scripts/build-release.sh $${VERSION:?Run make release VERSION=0.1.0}

install: app
	ditto build/Kuati.app /Applications/Kuati.app

clean:
	swift package clean
	rm -rf build dist
