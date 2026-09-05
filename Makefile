test:
	bash tests/setup.sh
	bash tests/dispatch.sh
	bash tests/band-resolve.sh
	bash tests/bands-validate.sh
	bash tests/codex-models.sh
	bash tests/bands-drift.sh

lint:
	bash -n setup.sh
	bash -n tests/setup.sh
	bash -n tests/dispatch.sh
	bash -n tests/band-resolve.sh
	bash -n tests/bands-validate.sh
	bash -n tests/codex-models.sh
	bash -n tests/bands-drift.sh
	bash -n scripts/agy-dispatch.sh
	bash -n scripts/codex-dispatch.sh
	bash -n scripts/band-resolve.sh
	bash -n scripts/bands-drift.sh
	python3 -m py_compile scripts/codex-models.py scripts/bands-validate.py
	if command -v shellcheck >/dev/null 2>&1; then shellcheck setup.sh tests/setup.sh tests/dispatch.sh tests/band-resolve.sh tests/bands-validate.sh tests/codex-models.sh tests/bands-drift.sh scripts/agy-dispatch.sh scripts/codex-dispatch.sh scripts/band-resolve.sh scripts/bands-drift.sh; else echo "shellcheck not installed; skipping"; fi
