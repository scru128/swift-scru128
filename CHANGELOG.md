# Changelog

## Unreleased

### Changed

- Textual representation: 26-digit Base32 -> 25-digit Base36
- Field structure: { `timestamp`: 44 bits, `counter`: 28 bits, `per_sec_random`:
  24 bits, `per_gen_random`: 32 bits } -> { `timestamp`: 48 bits, `counter_hi`:
  24 bits, `counter_lo`: 24 bits, `entropy`: 32 bits }
- Timestamp epoch: 2020-01-01 00:00:00.000 UTC -> 1970-01-01 00:00:00.000 UTC
- Custom logger: package-wide configuration -> per-generator configuration

### Added

- `Scru128Id#counterHi`, `Scru128Id#counterLo`, `Scru128Id#entropy`
- `Scru128Generator#setLogger()`

### Removed

- `Scru128Id#counter`, `Scru128Id#perSecRandom`, `Scru128Id#perGenRandom`
- `setScru128Logger()`

## v1.0.0 - 2022-01-03

- Initial stable release.
