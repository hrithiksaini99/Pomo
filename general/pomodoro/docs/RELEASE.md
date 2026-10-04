# Release Pomo

Pomo is a native macOS 13+ menu bar app. The build has no third-party runtime dependencies. `VERSION` is the source of truth for the marketing version; `BUILD_NUMBER` defaults to `1` and must be a positive integer.

## Local build

Install Apple's Command Line Tools or Xcode, then run from the repository root:

```sh
./test.sh
./build.sh
open dist/Pomo.app
```

`./build.sh --universal` includes both Apple silicon and Intel. `./build.sh --install` copies the app to your personal Applications folder. The default build is ad hoc signed for local development, and its bundle metadata records the development channel. It is not a notarized public release. Native smoke-test diagnostics are compiled only into ad hoc development builds; signed distribution builds exclude them.

## Development packages

```sh
./script/package_release.sh --universal --development
```

This produces ZIP and drag-to-Applications DMG archives, a release manifest, and SHA-256 checksums in `dist/releases/`. Each development archive has `-development` in its filename; the disk image includes a development notice. This mode never contacts Apple's notary service.

The packaging process is repeatable and verifies its outputs. Archives are not promised to be byte-identical between runs: compiler versions, filesystem metadata, code-signing timestamps, and notarization tickets can affect bytes. Checksums identify the exact artifacts from a given run.

Existing artifacts are never silently overwritten. Bump `VERSION` for a new public release or use `--output-dir` with a fresh absolute directory for another development run.

## Public distribution

A public release requires a valid **Developer ID Application** signing certificate and its private key in your Keychain, plus a working `notarytool` Keychain credential profile. An Apple Developer Program membership is needed to obtain the certificate. Do not add certificates, credentials, or private keys to the repository.

Check your signing identities:

```sh
security find-identity -p codesigning -v
```

Create the credential profile interactively. The tool prompts for credentials; keep them out of shell history and source control:

```sh
xcrun notarytool store-credentials pomo-notary
```

Then supply the identity and profile names:

```sh
export SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export NOTARY_PROFILE='pomo-notary'
export BUILD_NUMBER=1
./test.sh
./script/package_release.sh --universal
```

Use `SIGNING_KEYCHAIN` and `NOTARY_KEYCHAIN` if the identity or credential profile is in a non-default Keychain. The script stops if credentials are absent, the signing authority is incorrect, hardened runtime is missing, notarization is not accepted, or validation fails. It never falls back to a development build during a public release.

The release pipeline:

1. Builds the app, embeds the icon, and signs with hardened runtime and a secure timestamp.
2. Submits the signed app archive to Apple and waits for an `Accepted` response.
3. Staples and validates the app's ticket, then assesses the app with Gatekeeper.
4. Creates the final ZIP from the stapled app and a DMG containing the app, Applications shortcut, and installation instructions.
5. Signs, notarizes, staples, and validates the DMG.
6. Validates the app signature and generates the release manifest and SHA-256 checksums.

Notarization responses remain in the ignored `build/notarization/` directory for diagnosis. For a rejected submission, inspect its submission ID and use `xcrun notarytool log <submission-id> --keychain-profile "$NOTARY_PROFILE"` to obtain Apple's diagnostic log. A notarization timeout stops packaging; Apple may continue processing the existing submission.

Before publication, extract the ZIP and install from the DMG on a clean Mac. Verify macOS 13+ compatibility, menu bar visibility, pause/resume, simultaneous timers, focus completions, notification permission and banners, and both supported architectures where hardware is available. Run the local native smoke check with `./script/build_and_run.sh --smoke-test`; it requires an interactive desktop session.

For each downloaded artifact, verify its checksum from the release directory:

```sh
shasum -a 256 -c Pomo-1.0.0-macos-universal.SHA256SUMS.txt
```

## GitHub Actions

**Build and checks** runs core checks, validates a universal bundle, and uploads explicitly labeled development archives. Hosted CI does not run the desktop smoke test.

**Package release** is manually dispatched. It defaults to `development`. The `signed-and-notarized` channel requires these secrets in the GitHub `release` environment:

| Secret | Value |
| --- | --- |
| `POMO_CERTIFICATE_P12_B64` | Base64-encoded Developer ID certificate and private key exported as `.p12` |
| `POMO_CERTIFICATE_PASSWORD` | Password protecting that `.p12` |
| `POMO_SIGNING_IDENTITY` | Developer ID Application identity name |
| `POMO_NOTARY_PRIVATE_KEY` | App Store Connect team API key in `.p8` format |
| `POMO_NOTARY_KEY_ID` | API key ID |
| `POMO_NOTARY_ISSUER_ID` | Team API issuer ID |

Configure environment protection for release access. The workflow imports signing material into a temporary Keychain and removes it in its cleanup step. Both workflows upload artifacts for review; neither creates a GitHub release or publishes unnotarized binaries as stable. Publish a stable release only from the verified signed-and-notarized artifacts.

Apple's official documentation: [Developer ID](https://developer.apple.com/developer-id/) and [customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
