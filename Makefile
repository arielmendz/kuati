# SPDX-FileCopyrightText: 2026 Ariel Mendez
# SPDX-License-Identifier: GPL-3.0-only

.PHONY: build test app release install clean

APPDIR ?= /Applications

build:
	swift build

test:
	swift run KuatiLayoutTests

app:
	./scripts/build-app.sh release

release:
	./scripts/build-release.sh $${VERSION:?Run make release VERSION=0.1.3}

install: app
	mkdir -p "$(APPDIR)"
	ditto build/Kuati.app "$(APPDIR)/Kuati.app"

clean:
	swift package clean
	rm -rf build dist
