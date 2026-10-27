# Loopback TLS fixture

`localhost-cert.pem` is a disposable self-signed localhost certificate.
`localhost-key.pem` is its deliberately public test key, not a credential.
Never use either for an application server. Neither is installed into system trust.

The local TLS test provides a working HTTPS/WSS server and checks that the default
SDK transports reject its untrusted certificate. It does not bypass verification
or claim trusted TLS success. Regenerate from the repository root with OpenSSL:

```sh
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout Tests/KiteConnectTests/Fixtures/localhost-key.pem \
  -out Tests/KiteConnectTests/Fixtures/localhost-cert.pem \
  -days 3650 -subj '/CN=localhost' \
  -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1'
```
