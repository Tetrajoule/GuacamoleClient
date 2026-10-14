# Clipboard forwarding investigation status

Status: The WinForms local-to-remote text clipboard fix is implemented and verified in the live AiSEL RDP session (2026-10-14). Stable fork release 2026.10.14.1 is published, including the verified signed MSIX. A focused upstream pull request for issue #56 is open and awaiting maintainer review.

## Root causes confirmed

1. **RDP clipboard streams do not return success acknowledgements.** Apache Guacamole's RDP clipboard/blob handlers append incoming text without sending success ACKs. The end handler advertises the completed clipboard data to RDP. Waiting for every blob to be acknowledged prevented the bridge from sending that required end instruction.
2. **Remote key states must be numeric.** `Guacamole.Client.sendKeyEvent()` passes its pressed argument directly to the tunnel. JavaScript booleans become `true`/`false` on the wire, whereas guacd parses this argument as an integer. The old bridge's synthesized Ctrl+V therefore did not generate key-down events. This also explains why the previous send-end-and-delay experiment did not paste.

The live protocol probe observed no clipboard success ACK either before or after sending end. Sending text followed by end and numeric key states successfully pasted Unicode/multiline text into remote Notepad.

Upstream references (Guacamole 1.6.0):

- [RDP clipboard, blob, and end handlers](https://github.com/apache/guacamole-server/blob/1.6.0/src/protocols/rdp/channels/cliprdr.c)
- [Protocol key argument parsing](https://github.com/apache/guacamole-server/blob/1.6.0/src/libguac/user-handlers.c)
- [ManagedClient.setClipboard text/end ordering](https://github.com/apache/guacamole-client/blob/1.6.0/guacamole/src/main/frontend/src/app/client/types/ManagedClient.js)
- [Client.sendKeyEvent serialization](https://github.com/apache/guacamole-client/blob/1.6.0/guacamole-common-js/src/main/webapp/modules/Client.js)

## Current implementation

- WinForms captures trusted Ctrl+V on the configured Guacamole connection page, confirms the active Angular-managed client, and reads Unicode text from the Windows clipboard on the UI/STA thread with retries.
- Text is JSON-serialized into the page bridge and sent using `Guacamole.StringWriter` or a UTF-8/Base64 `sendBlob` fallback. The bridge sends end immediately after all text blobs, matching Guacamole's web client.
- A `stream-sent` message triggers native finalization. The bridge rechecks the active session and queues remote Ctrl+V using numeric `1`/`0` key states. It does not require nonexistent success ACKs or add an arbitrary paste delay.
- Observed stream rejection, send failure, cancellation, disconnection, and session replacement suppress paste. Cancellation does not end an already-ended stream twice.
- The obsolete internal acknowledgement counter and its counter-specific tests were removed. The JSON-encoding helper and its unit test remain in files named `ClipboardTextBridgeEncoding.cs` and `ClipboardTextBridgeEncodingTests.cs`.
- Diagnostics distinguish queued stream/key instructions from proof of remote application receipt. No clipboard contents are logged.

## Live verification

Server: `http://192.168.236.62:8080/guacamole/`, saved `Aisel` RDP connection.

The rebuilt WinForms app was exercised with native Windows Ctrl+V, rather than only calling the injected JavaScript:

- Unicode text containing German characters, Japanese text, and an emoji pasted into remote Notepad.
- Multiline text pasted with its line breaks intact.
- Five rapid native paste gestures produced five visible copies.
- A large payload of 55,000 Unicode code points (57,500 UTF-16 code units, 2,500 lines) pasted successfully through multiple blobs. Remote Notepad showed line 2,501 after the trailing newline.
- Small and large remote-to-local copies replaced a deliberately different local clipboard sentinel with the exact expected Windows clipboard text.
- After reloading the WebView2 page and establishing a fresh RDP connection, native Unicode paste and remote-to-local copy again passed an exact-text comparison.
- Temporary matrix/reconnect Notepad windows were closed without saving. The earlier probe text appended to the existing Notepad was removed after checking its exact suffix, and restoration was verified. The local text clipboard was restored after the probes.

The runtime log for this run is `%LOCALAPPDATA%\GuacamoleClient\Logs\clipboard-forwarding-60944.log`. Screenshots are under `%TEMP%\opencode\clipboard-native-*.png`. These are local investigation artifacts, not repository files.

Successful bidirectional clipboard transfer demonstrates that this session permits clipboard redirection. Server logs and Windows policy settings were not inspected directly.

## Automated verification

- `dotnet build GuacamoleClient-WinForms/GuacamoleClient-WinForms.csproj --no-restore` passed with no warnings or errors.
- `dotnet test GuacamoleCommon.Tests/GuacamoleCommon.Tests.csproj --no-restore` passed: 159 passed, 6 skipped. The four removed acknowledgement-counter tests encoded the invalid ACK requirement.
- `node --test tests/clipboard-forwarding/clipboard-bridge.test.mjs` passed: 14 tests. Node was run from the temporary Playwright installation because it is not on this machine's PATH.
- The JavaScript regression tests execute the production embedded scripts with Guacamole stream/tunnel doubles. Coverage includes no-ACK stream completion, numeric key states, UTF-8 fallback chunking, Unicode, rejection, send/key failures, cancellation, disconnect/reconnect guards, session switching, Ctrl+Shift+V key ordering, and repeated paste.
- The earlier solution build limitation remains: the MSIX project requires unavailable .NET DesktopBridge targets (`Microsoft.DesktopBridge.props`). The affected WinForms app builds independently.

## Upstream contribution status

- Issue: [#56 — Clipboard from local client to remote session does not work in Guacamole Client for Windows](https://github.com/jochenwezel/GuacamoleClient/issues/56)
- Pull request: [#67 — Fix WinForms local-to-remote clipboard paste](https://github.com/jochenwezel/GuacamoleClient/pull/67), from `Tetrajoule:fix/issue-56-native-clipboard-forwarding` to upstream `main`.
- The PR contains only the WinForms clipboard bridge and related regression tests; fork-specific release, Pages, and signing changes are excluded.
- The issue has a comment linking the PR and summarizing the fix: [comment](https://github.com/jochenwezel/GuacamoleClient/issues/56#issuecomment-6172352766).
- AI assistance disclosure is included in the PR description and issue comment: the patch was developed with AI assistance and reviewed/tested in a live RDP session.
- PR state: open. GitHub reported no PR checks at the time this status was updated; maintainer review and any requested revisions remain pending.
- Potential next steps: monitor upstream CI/review and address maintainer feedback; verify signed-MSIX install/upgrade on a separate Windows machine; complete live multi-session, sustained-key-repeat, and Ctrl+Shift+V checks. Details are tracked in `docs/RELEASE-TODOS.md`.

## Remaining follow-up

Release outcome: stable fork release [2026.10.14.1](https://github.com/Tetrajoule/GuacamoleClient/releases/tag/2026.10.14.1) is published at commit `b238f88`. CI passed on Windows, Linux, and macOS; all six release workflows passed. All 14 original release assets were nonempty. A verified signed MSIX was subsequently added, bringing the release to 15 assets. Remote artifact checks verified the MSIX executable/runtime, package version and update metadata, and SHA-256 hashes for the signed MSIX and WinForms framework-dependent packages. The download site, Stable/Dev update-feed versions, and all four signed ClickOnce deployment/application-manifest URLs were verified. Downloads: https://tetrajoule.github.io/GuacamoleClient/.

Release notes are in `docs/release-notes/2026.10.14.1.md`; the consolidated clipboard, packaging, signing, and existing source follow-ups are in `docs/RELEASE-TODOS.md`. The initial 2026.10.14.0 release exposed an inherited MSIX payload/version defect during artifact inspection. Its invalid MSIX asset was withdrawn. The corrected packaging uses the published application and includes a durable payload/manifest/update-metadata verification gate.

Additional MSIX signing: release 2026.10.14.1 now has 15 assets, including `GuacamoleClient-WinForms-msix-2026.10.14.1-signed.msix`. The [signing workflow](https://github.com/Tetrajoule/GuacamoleClient/actions/runs/38590412875) passed SignTool/Authenticode verification, confirmed the signer matches public certificate `A9A4DE44C5C5E98D32CB596ACC73D7AAC4EAA288`, checked the DigiCert timestamp, and compared the application payload against the original unsigned release asset. The downloaded file's CMS signature and SHA-256 were independently verified: `d8338e0a751937856503430509a00a587b0a1df82de6754996e9c7e2b6e3fc61`. Target-machine installation and upgrades remain untested.

1. Exercise switching between multiple simultaneously connected sessions in the live WinForms UI. Automated tests already verify that a changed/replaced/disconnected client cannot receive a pending paste.
2. Check sustained key-repeat and Ctrl+Shift+V in remote applications that support those gestures. Rapid separate Ctrl+V gestures passed live; the modified key ordering is covered by automated tests.
3. If testing ordinary browser clipboard integration separately, use HTTPS or explicitly account for browser restrictions on this HTTP origin. The native WinForms clipboard path was verified on the supplied HTTP deployment.
