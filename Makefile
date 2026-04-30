test:
	bash tests/setup.sh

lint:
	bash -n setup.sh
	bash -n tests/setup.sh
	if command -v shellcheck >/dev/null 2>&1; then shellcheck setup.sh tests/setup.sh; else echo "shellcheck not installed; skipping"; fi
