# Allow maintained dependencies behind replaceable transports

Reliable Apple/Linux support takes priority over a zero-dependency constraint. Maintained dependencies may provide networking and cross-platform SHA-256 behind replaceable transport interfaces; the exact dependencies remain subject to implementation validation.

Linux WebSocket support must be tested in the supported runtime environment before choosing a transport, since Foundation API availability alone does not establish working libcurl WebSocket support. Replaceable transports also enable controlled protocol tests without real credentials.
