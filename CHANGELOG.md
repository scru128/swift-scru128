# Changelog

## v2.4.6 - unreleased

### Added

- `Scru128Id#byteArray` as synonym for deprecated `bytes`

### Deprecated

- `Scru128Id#bytes` to help migration to v3

## v2.4.5 - 2023-07-29

### Fixed

- Test case that could not compile with Xcode 13.4

## v2.4.4 - 2023-06-21

### Maintenance

- Improved test cases

## v2.4.3 - 2023-06-05

### Fixed

- multi-threaded test cases by adding proper @available attribute

## v2.4.2 - 2023-06-04

### Added

- `Sendable` protocol conformance to `Scru128Id`

### Maintenance

- Upgraded minimum Swift version to 5.6
- Rewrote multi-threaded test cases using Swift Concurrency
- Fixed README

## v2.4.1 - 2023-04-08

### Maintenance

- Tweaked docs and tests

## v2.4.0 - 2023-03-22

### Added

- `generateOrAbort()` and `generateOrAbortCore()` to `Scru128Generator`
  (formerly named as `generateNoRewind()` and `generateCoreNoRewind()`)
- `Scru128Generator#generateOrResetCore()`

### Deprecated

- `Scru128Generator#generateCore()`
- `Scru128Generator#lastStatus` and `Scru128Generator.Status`

## v2.3.1 - 2023-03-19

### Added

- `generateNoRewind()` and `generateCoreNoRewind(timestamp:rollbackAllowance:)`
  to `Scru128Generator` (experimental)

### Maintenance

- Improved documentation about generator method flavors

## v2.3.0 - 2023-02-13

### Fixed

- `Decodable` implementation of `Scru128Id` to throw error on failure instead of
  raising runtime panic

### Changed

- `Decodable` behavior so it tries to parse byte array as well as string

## v2.2.0 - 2022-12-23

### Added

- Sequence and IteratorProtocol implementations to `Scru128Generator` to make it
  work as infinite iterator

## v2.1.2 - 2022-06-11

### Fixed

- `generateCore()` to update `counter_hi` when `timestamp` passed < 1000

## v2.1.1 - 2022-05-23

### Fixed

- `generateCore()` to reject zero as `timestamp` value

## v2.1.0 - 2022-05-22

### Added

- `generateCore()` and `lastStatus` to `Scru128Generator`

## v2.0.0 - 2022-05-01

### Changed

- Textual representation: 26-digit Base32 -> 25-digit Base36
- Field structure: { `timestamp`: 44 bits, `counter`: 28 bits, `per_sec_random`:
  24 bits, `per_gen_random`: 32 bits } -> { `timestamp`: 48 bits, `counter_hi`:
  24 bits, `counter_lo`: 24 bits, `entropy`: 32 bits }
- Timestamp epoch: 2020-01-01 00:00:00.000 UTC -> 1970-01-01 00:00:00.000 UTC
- Counter overflow handling: stall generator -> increment timestamp

### Removed

- `setScru128Logger()` as counter overflow is no longer likely to occur
- `Scru128Id#counter`, `Scru128Id#perSecRandom`, `Scru128Id#perGenRandom`

### Added

- `Scru128Id#counterHi`, `Scru128Id#counterLo`, `Scru128Id#entropy`

## v1.0.0 - 2022-01-03

- Initial stable release
