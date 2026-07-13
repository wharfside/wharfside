.PHONY: build test lint purity ci ai-test

build:
	xcodebuild build -project Wharfside.xcodeproj -scheme Wharfside \
	  -destination 'platform=macOS,arch=arm64' | xcbeautify

test:
	xcodebuild test -project Wharfside.xcodeproj -scheme Wharfside \
	  -destination 'platform=macOS,arch=arm64' \
	  -skip-testing:WharfsideUITests | xcbeautify
	cd Packages/WharfsideAnalysis && swift test -Xswiftc -warnings-as-errors

lint:
	swiftlint --strict

purity:
	@! grep -rnE '^\s*import (SwiftUI|FoundationModels|AppKit)' \
	  Packages/WharfsideAnalysis/Sources/ \
	  Packages/RulebookCore/Sources/ \
	  || (echo "WharfsideAnalysis and RulebookCore must stay pure (AI_INTEGRATION.md §2)"; exit 1)

ci: lint purity build test rulebook-linux

rulebook-test:
	cd Packages/RulebookCore && swift test -Xswiftc -warnings-as-errors

# Ground-truth Linux purity check for RulebookCore (B3 acceptance criterion).
# Requires apple/container or Docker. CI runs the same step in rulebook-core-linux.
rulebook-linux:
	container run --rm \
	  -v "$(PWD)/Packages/RulebookCore:/src" \
	  -w /src \
	  swift:6.0 \
	  swift test -c release -Xswiftc -warnings-as-errors

ai-test:
	mkdir -p .artifacts && touch .artifacts/.run-ai-regression
	xcodebuild test -project Wharfside.xcodeproj -scheme Wharfside \
	  -destination 'platform=macOS,arch=arm64' \
	  -only-testing:WharfsideTests/DiagnosisRegressionTests \
	  -parallel-testing-enabled NO | xcbeautify