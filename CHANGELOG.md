# Changelog

## [Unreleased] - 2023-09-04

### Added

Add option to configure keepalive

## [1.0.0-6] - 2023-01-13

### Added

Add option to configure keepalive

### Improvements

Reuse connection pool on iOS
Use optimal event loop group on iOS dependent on platform support

### Bugfixes

Fix channel on Android not reflecting updated options on change

## [1.0.0-5] - 2023-01-12

### Added

Add option to specify compression limit on iOS

## [1.0.0-4] - 2023-01-11

### Bugfixes

Fix incorrect status code given on iOS on failure

## [1.0.0-3] - 2023-01-11

### Added

Added option to enable gRPC compression

---

Thanks to @krishnafkh for contributing the Android implementation (#5)

## [1.0.0-2] - 2023-01-10

### Bug fixes

Fix passed header value being invalid by unwrapping the `String` on iOS

## [1.0.0-1] - 2022-12-10

### Bugfixes

Fix status code not being included in gRPC error on iOS

## [1.0.0-0] - 2022-12-10

### Breaking

Now using gRPC-Swift on iOS

### [0.1.10] - 2022-09-01

### Improvements

Implemented maximum response size limit for gRPC client on Android

## [0.1.9] - 2022-08-31

### Added

Added option to set the maximum response size limit on the gRPC client.

## [0.1.8] - 2022-08-16

### Bugfixes

Fix error code not being provided on iOS

## [0.1.7] - 2022-08-07

### Bugfixes

Reuse Android ManagedChannel for gRPC calls

## [0.1.6] - 2022-06-09

### Bugfixes

Fix trailers not being sent

## [0.1.5] - 2022-06-01

### Improvements

Add trailers to GrpcError

### Bugfixes

Fix binary data contained within metadata

## [0.1.4] - 2021-06-24

### Breaking

Changed server output stream functions `onData(callback)`, `onFinish(callback)`, `onError(callback)` to `on(type, callback)`

### Improvements

Errors should be more descriptive than 'aborted'.

## [0.1.3] - 2021-06-23

Fix base64 encoding issue on iOS

## [0.1.2] - 2021-06-23

Fix incorrect location of types

## [0.1.1] - 2021-06-23

Initial release

## [0.1.0]

Initial commit
