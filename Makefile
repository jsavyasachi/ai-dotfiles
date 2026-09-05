test:
	bash tests/setup.sh
	bash tests/dispatch.sh

lint:
	bash -n setup.sh
	bash -n tests/setup.sh
	bash -n tests/dispatch.sh
	bash -n scripts/agy-dispatch.sh
	bash -n scripts/codex-dispatch.sh
	if command -v shellcheck >/dev/null 2>&1; then shellcheck setup.sh tests/setup.sh tests/dispatch.sh scripts/agy-dispatch.sh scripts/codex-dispatch.sh; else echo "shellcheck not installed; skipping"; fi
