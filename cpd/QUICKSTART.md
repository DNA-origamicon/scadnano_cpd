# scadnano-CPD — Quickstart

Commands to get the local dev server running and run tests.

## Start the localhost server

```bash
# 1. Install dependencies (first time only, or after pubspec.yaml changes)
dart pub get

# 2. Start the dev server
webdev serve
```

Open **http://127.0.0.1:8080** in your browser.
The server recompiles automatically when you save a Dart file; refresh the browser to pick up changes.

> **Slow first build?** The first compile takes 30–70 s (built_value code generation).
> Subsequent incremental rebuilds are much faster.

---

## If `webdev` isn't found

```bash
# Install webdev globally
dart pub global activate webdev

# Then add it to your PATH (Linux/macOS — add to .bashrc / .zshrc)
export PATH="$PATH:$HOME/.pub-cache/bin"
```

---

## Run tests

```bash
# All VM-compatible tests (includes CPD parameter schema tests)
dart run build_runner test -- test/cpd_parameters_test.dart --platform vm

# A single test file (Chrome required for most CPD rule tests)
dart run build_runner test -- test/cpd_rules/ext_ext_rule_test.dart
```

---

## Troubleshoot build errors

```bash
# Clean generated files and rebuild from scratch
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
webdev serve
```

---

## Production build (faster at runtime, no hot-reload)

```bash
webdev serve --release
```
