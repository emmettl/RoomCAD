.PHONY: build app run test lint format ci-test check validate icon release-check release
CONFIGURATION ?= release

build:
	swift build

app:
	bash Scripts/build-app.sh "$(CONFIGURATION)"

run: app
	open dist/RoomCAD.app

test:
	swift test

lint:
	swift format lint --strict --recursive Package.swift Sources Tests Scripts

format:
	swift format format --in-place --recursive Package.swift Sources Tests Scripts

ci-test:
	python3 Scripts/test-release.py

check: lint test ci-test build

validate:
	swift run -c release acousticbench --bras-cr2
	swift run -c release acousticbench --bras-cr3

icon:
	swift Scripts/make-icon.swift

release-check:
	python3 Scripts/release.py check

release:
	python3 Scripts/release.py prepare
