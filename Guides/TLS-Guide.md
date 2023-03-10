# Swift Driver TLS/SSL Guide

This guide covers the installation requirements and configuration options for connecting to MongoDB over TLS/SSL in the driver. See the [server documentation](https://docs.mongodb.com/manual/tutorial/configure-ssl/) to configure MongoDB to use TLS/SSL.

## Dependencies

The driver relies on the the TLS/SSL library installed on your system for making secure connections to the database. 
 - On macOS, the driver depends on SecureTransport, the native TLS library for macOS, so no additional installation is required.
 - On Linux, the driver depends on OpenSSL, which is usually bundled with your OS but may require specific installation. The driver also supports LibreSSL through the use of OpenSSL compatibility checks.
 
### Ensuring TLS 1.1+

Industry best practices recommend, and some regulations require, the use of TLS 1.1 or newer. Though no application changes are required for the driver to make use of the newest protocols, some operating systems or versions may not provide a TLS library version new enough to support them.

#### ...on Linux

Users of Linux or other non-macOS Unix can check their OpenSSL version like this:
```
$ openssl version
```
If the version number is less than 1.0.1, support for TLS 1.1 or newer is not available. Contact your operating system vendor for a solution, upgrade to a newer distribution, or manually upgrade your installation of OpenSSL.

#### ...on macOS

macOS 10.13 (High Sierra) and newer support TLS 1.1+.


## Basic Configuration

To require that connections to MongoDB made by the driver use TLS/SSL, specify `tls: true` in the `MongoClientOptions` passed to a `MongoClient`'s initializer:
```swift
let client = try MongoClient("mongodb://example.com", using: elg, options: MongoClientOptions(tls: true))
```

Alternatively, `tls=true` can be specified in the [MongoDB Connection String](https://docs.mongodb.com/manual/reference/connection-string/) passed to the initializer:
```swift
let client = try MongoClient("mongodb://example.com/?tls=true", using: elg)
```
**Note:** Specifying any `tls`-prefixed option in the connection string or `MongoClientOptions` will require all connections made by the driver to use TLS/SSL.

## Specifying a CA File

The driver can be configured to use a specific set of CA certificates. This is most often used with "self-signed" server certificates. 

A path to a file with either a single or bundle of certificate authorities to be considered trusted when making a TLS connection can be specified via the `tlsCAFile` option on `MongoClientOptions`:
```swift
let client = try MongoClient("mongodb://example.com", using: elg, options: MongoClientOptions(tlsCAFile: URL(string: "/path/to/ca.pem")))
```

Alternatively, the path can be specified via the `tlsCAFile` option in the [MongoDB Connection String](https://docs.mongodb.com/manual/reference/connection-string/) passed to the client's initializer:
```swift
let caFile = "/path/to/ca.pem".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
let client = try MongoClient("mongodb://example.com/?tlsCAFile=\(caFile)", using: elg)
```

## Specifying a Client Certificate or Private Key File

The driver can be configured to present the client certificate file or the client private key file via the `tlsCertificateKeyFile` option on `MongoClientOptions`:
```swift
let client = try MongoClient("mongodb://example.com", using: elg, options: MongoClientOptions(tlsCertificateKeyFile: URL(string: "/path/to/cert.pem")))
```
If the private key is password protected, a password can be supplied via `tlsCertificateKeyFilePassword` on `MongoClientOptions`:
```swift
let client = try MongoClient(
    "mongodb://example.com",
    using: elg,
    options: MongoClientOptions(tlsCertificateKeyFile: URL(string: "/path/to/cert.pem"), tlsCertificateKeyFilePassword: <password>)
)
```

Alternatively, these options can be set via the `tlsCertificateKeyFile` and `tlsCertificateKeyFilePassword` options in the [MongoDB Connection String](https://docs.mongodb.com/manual/reference/connection-string/) passed into the initializer:
```swift
let certificatePath = "/path/to/cert.pem".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
let password = "not a secure password".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
let client = try MongoClient(
    "mongodb://example.com/?tlsCertificateKeyFile=\(certificatePath)&tlsCertificateKeyFilePassword=\(password)",
    using: elg
)
```
**Note**: In both cases, if both a client certificate and a client private key are needed, the files should be concatenated into a single file which is specified by `tlsCertificateKeyFile`.

## Server Certificate Validation

The driver will automatically verify the validity of the server certificate by ensuring that it was issued by the
configured Certificate Authority, its SAN or CN match the hostname provided in the connection string, and it has not
expired.

To override this behavior, it is possible to disable parts or all of it via the following options in the
`MongoClientOptions` or connection string used to create the `MongoClient`:
- `tlsAllowInvalidHostnames`: disables hostname validation
- `tlsDisableOCSPEndpointCheck`: disables OCSP endpoint revocation checking. This does not disable verifying OCSP
responses stapled to a server's certificate 
- `tlsDisableCertificateRevocationCheck`: disables revocation checking entirely, including via OCSP stapled responses or
CRLs.
- `tlsAllowInvalidCertificates`: completely disables server certificate verification and allows any certificate to be
used.

By default, all of these options are set to false.

It is not recommended to change these defaults as it exposes the client to on-path-attackers (when
`tlsAllowInvalidHostnames` is set), invalid certificates (when `tlsAllowInvalidCertificates` is set), or potentially
revoked certificates (when `tlsDisableOCSPEndpointCheck` or `tlsDisableCertificateRevocationCheck` are set).

Note that `tlsDisableCertificateRevocationCheck` and `tlsDisableOCSPEndpointCheck` have no effect on macOS.

### OCSP on Linux/OpenSSL
The Online Certificate Status Protocol (OCSP) (see [RFC 6960](https://tools.ietf.org/html/rfc6960)) is fully supported
when using OpenSSL 1.0.1+.

### OCSP on macOS
The Online Certificate Status Protocol (OCSP) (see [RFC 6960](https://tools.ietf.org/html/rfc6960)) is partially
supported with the following notes:

- The Must-Staple extension (see [RFC 7633](https://tools.ietf.org/html/rfc7633)) is ignored. Connection may continue if
  a Must-Staple certificate is presented with no stapled response (unless the client receives a revoked response from an
  OCSP responder).

- Connection will continue if a Must-Staple certificate is presented without a stapled response and the OCSP responder
  is down.
