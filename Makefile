.PHONY: build test app install clean

build:
	swift build

test:
	swift run KuatiLayoutTests

app:
	./scripts/build-app.sh release

install: app
	ditto build/Kuati.app /Applications/Kuati.app

clean:
	swift package clean
	rm -rf build
