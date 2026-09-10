# SPDX-License-Identifier: MPL-2.0
# Copyright © 2026 Cristian Camargo Filho

.PHONY: smoke test

NVIM ?= nvim

test:
	$(NVIM) --clean --headless -u tests/minimal_init.lua -i NONE -l tests/run.lua

smoke:
	test -n "$(SERVER)"
	$(NVIM) --clean --headless -u tests/minimal_init.lua -i NONE -l tests/smoke.lua -- "$(SERVER)"
