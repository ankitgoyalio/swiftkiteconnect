# Publisher coverage and offline verification

Publisher user guidance now lives in the DocC catalog:

- [Publisher integration boundaries](../Sources/KiteConnect/KiteConnect.docc/Publisher-integration.md).
- [Prepare a Publisher handoff](../Sources/KiteConnect/KiteConnect.docc/Prepare-a-Publisher-handoff.md).
- [Handle a Publisher return](../Sources/KiteConnect/KiteConnect.docc/Handle-a-Publisher-return.md).
- [Use the Publisher plugin](../Sources/KiteConnect/KiteConnect.docc/Use-the-Publisher-plugin.md).

This file retains the dated guidance coverage record for the 2026-10-27 upstream snapshot. It does not establish browser or trading qualification.

## Snapshot coverage and validation

All entries below are guidance coverage, not new Swift SDK APIs or a 1.0
qualification claim. The canonical articles link to the audited v3 documentation as of
2026-10-27. Revisit those sources for each release.

| Capability | Canonical DocC article | Evidence / limitation |
| --- | --- | --- |
| Offsite basket form, login and return | Prepare a Publisher handoff; Handle a Publisher return | Offline form preparation test; no remote submission. |
| Branded/custom HTML data buttons | Use the Publisher plugin | Official documentation audit; no browser execution. |
| Dynamic basket, readiness, inspection and rendering | Use the Publisher plugin | Controlled plugin boundary test; no remote assets. |
| Redirect override and finished callback | Use the Publisher plugin; Handle a Publisher return | Pure callback parsing tests; no provider callback observed. |
| Holdings authorisation plugin/browser bridge | Use the Publisher plugin | Official portfolio/plugin audit only; REST owned by separate capability. |
| Mobile/desktop cookies and redirects; iOS restriction | Publisher integration boundaries | Official docs audit only; device behavior unverified. |
| Optional API session and application ownership | Publisher integration boundaries; Handle a Publisher return | Authentication documentation audit; no credentialed exchange. |

Run focused, credential-free validation from the repository root:

```sh
node --test Tests/Publisher.test.cjs
```

The tests evaluate the examples using controlled DOM/plugin boundaries, without
loading external JavaScript, opening a browser or placing orders. They verify
payload serialization, initialization and callback parsing, not Kite execution,
cookie compatibility or SDK REST coverage. No dates/timestamps are transported
by these examples, so temporal SDK contracts have no new implementation here.
