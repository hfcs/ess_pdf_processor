SHELL := /bin/bash
.PHONY: build-web

build-web:
	@echo "Building Flutter web demo (web_app) from repo root..."
	flutter -C web_app pub get
	flutter -C web_app build web --release

clean:
	@echo "Cleaning Flutter web demo build artifacts..."
	rm -rf web_app/build
