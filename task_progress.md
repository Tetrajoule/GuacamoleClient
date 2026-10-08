# Clipboard forwarding investigation status

Status: In progress. The WinForms bridge is instrumented and builds, but local-to-remote paste has not been made to work in the live AiSEL RDP session.

## Confirmed runtime observations

- The supplied server at `http://192.168.236.62:8080/guacamole/` is reachable. Logging in as `guacadmin` exposes the saved `Aisel` RDP connection.
- In the WinForms app, Ctrl+V reaches the document-start bridge. The native clipboard read succeeds, the active Angular-managed client is selected, `text/plain` output-stream creation succeeds, and the text blob is queued.
- The live session does not return an output-stream acknowledgement before the app's transfer timeout. No remote paste is dispatched, and the remote Notepad remains unchanged.
- The AiSEL connection's API configuration has no explicit `disable-paste` or `disable-copy` parameter. Guacamole documents paste as allowed by default when these parameters are omitted. Remote Windows clipboard policy and server-side RDP/guacd behavior have not been inspected.
- A normal Edge session to the same HTTP Guacamole origin also failed to paste in the test. This comparison is not conclusive because the HTTP origin may restrict browser clipboard APIs.
- A temporary send-end-and-delay experiment did not visibly paste into remote Notepad and was removed. The remote-to-local test performed during this run was inconclusive because focus had returned to Explorer.

## Current implementation

- WinForms captures trusted Ctrl+V on the configured Guacamole connection page, confirms the active client using the Angular `ManagedClient.clientState`, and reads Unicode text from the Windows clipboard on the UI/STA thread with retries.
- Text is safely JSON-serialized into the page bridge and sent using `Guacamole.StringWriter` or a UTF-8/Base64 `sendBlob` fallback. The app currently waits for all blob acknowledgements before ending the stream and dispatching remote Ctrl+V; AiSEL did not acknowledge the blob.
- Clipboard diagnostics are written without clipboard contents to `%LOCALAPPDATA%\GuacamoleClient\Logs\clipboard-forwarding-<pid>.log`.

## Automated verification

- `dotnet build GuacamoleClient-WinForms/GuacamoleClient-WinForms.csproj --no-restore` passed with no warnings or errors.
- `dotnet test GuacamoleCommon.Tests/GuacamoleCommon.Tests.csproj --no-restore` passed: 163 passed, 6 skipped.
- A solution build was also attempted. The app projects built, but the MSIX project could not load the missing .NET DesktopBridge targets (`Microsoft.DesktopBridge.props`).

## Next steps

1. Inspect the live Guacamole/guacd logs or protocol trace for AiSEL while sending a client `clipboard` stream. Determine whether the stream instruction/blob is rejected, ignored, or acknowledged only after stream termination.
2. Verify the destination Windows RDP clipboard-redirection policy permits client-to-server data. The Guacamole connection parameter alone does not establish that the target machine accepts it.
3. Confirm the same operation in a normal browser on a secure HTTPS origin, or explicitly verify browser clipboard-read behavior for this HTTP deployment.
4. Once the RDP/server behavior is known, adjust stream completion/paste ordering to match that server behavior. Do not dispatch Ctrl+V after an unacknowledged or rejected transfer.
5. Rerun the live matrix: local-to-remote text (including Unicode, multiline, large text, rapid/repeated paste), remote-to-local, session switching, and reconnect.
