# Contributing to Pomo

Keep the app small, native, and predictable. Open an issue before adding a new product surface or changing timer behavior.

## Before submitting a change

```sh
./test.sh
./build.sh
./script/build_and_run.sh --smoke-test
```

Use an injected clock for timing checks. Do not write tests that wait for real focus intervals. Keep Foundation-only state in `Core.swift` and platform behavior in `AppDelegate.swift`.

For website changes, verify narrow and wide layouts, keyboard navigation, reduced motion, and the interactive preview. Avoid external scripts and tracking. Serve the static directory with:

```sh
python3 -m http.server 8080 --directory general/website
```

Never commit signing credentials, certificates, private keys, development archives, build output, local tooling configuration, or personal reference material.
