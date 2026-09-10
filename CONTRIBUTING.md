<!-- SPDX-License-Identifier: MPL-2.0 -->
<!-- Copyright © 2026 Cristian Camargo Filho -->

# Contributing

This repository owns only the Neovim/LazyVim adapter: buffer recognition,
workspace-root selection, language-server process lifecycle, and editor-facing
commands. Put analysis rules in Harness Lens Core, filesystem/config behavior in
the SDK, and protocol behavior in the language-server repository.

Keep defaults local-first and deterministic. Do not add automatic downloads,
network transport, validation-rule copies, model-provider dependencies, or raw
source/report persistence.

Run the repository check before opening a pull request:

```bash
make test
```

Contributions intentionally submitted here are provided under MPL-2.0. You must
have the necessary rights to submit the work.
