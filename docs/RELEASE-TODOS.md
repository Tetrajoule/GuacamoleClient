# Release follow-ups

## Clipboard forwarding

- [ ] Verify switching between multiple simultaneously connected sessions in the live WinForms UI. Automated tests cover changed, replaced, and disconnected clients.
- [ ] Verify sustained Ctrl+V key-repeat, including release of the held key.
- [ ] Verify Ctrl+Shift+V in a remote application that supports plain-text paste. Automated tests verify the modifier and key ordering.
- [ ] When separately testing ordinary browser clipboard integration, use HTTPS or explicitly account for the HTTP origin's browser clipboard restrictions.

Completed live checks and protocol findings are recorded in [task_progress.md](../task_progress.md).

## Packaging and publishing

- [ ] Complete Linux/macOS runtime validation before removing the corresponding `release-gates/not-yet-stable.*.disabled` files. These packages remain Dev-only.
- [ ] Consider a publicly trusted code-signing certificate for ClickOnce and MSIX. Both currently use the fork's self-signed publisher certificate.
- [x] Publish a signed, timestamped MSIX using the private key matching the release's public certificate. Release 2026.10.14.1 includes the verified `-signed.msix` asset.
- [ ] Verify signed MSIX installation and upgrades. The executable/runtime payload, package manifest, release version, and update metadata are validated by `tests/packaging/Test-WinFormsMsix.ps1` before upload.
- [ ] Renew the ClickOnce signing certificate before 2029-10-14, preserving a documented migration path for existing installations.
- [ ] Migrate the deprecated Windows unit-test-results composite action to its supported replacement. Current CI reporting succeeds but emits a deprecation annotation.
- [ ] Upgrade the release-upload action's Node runtime. `softprops/action-gh-release@v2` succeeds with GitHub's forced Node 24 runtime but emits a Node 20 deprecation annotation.
- [ ] Before each stable release, review obsolete Dev Preview releases and obtain explicit confirmation before deleting releases or assets. No older releases existed in this fork when preparing 2026.10.14.0.

## Existing source TODO

- [ ] Improve light/dark color detection in `GuacamoleCommon/Settings/GuacamoleColorScheme.cs`. This pre-existing TODO is independent of the clipboard fix.

## Release procedure

1. Review the complete diff, open follow-ups, and current stable/Dev releases.
2. Run the .NET and JavaScript tests and build the affected app projects sequentially.
3. Commit and push the intended files, then wait for Build and Test to pass.
4. Create a stable GitHub release at the verified commit using the repository's four-part date version, for example `2026.10.14.1`. Release workflows take the version from that tag and run on publication; no project version edit is required.
5. Wait for all release workflows to finish, then run **Sign release - WinForms MSIX** for that release tag to attach its signed variant. Verify expected release assets and check the deployed Pages site, ClickOnce URLs, and `app-updates.json`.
6. Carry unresolved checks forward here and in the release notes. Do not present an unperformed manual check as verified.
