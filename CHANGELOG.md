# Changelog

## [Unreleased]

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
