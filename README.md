# SCRU128: Sortable, Clock and Random number-based Unique identifier

SCRU128 ID is yet another attempt to supersede [UUID] in the use cases that need
decentralized, globally unique time-ordered identifiers. SCRU128 is inspired by
[ULID] and [KSUID] and has the following features:

- 128-bit unsigned integer type
- Sortable by generation time (as integer and as text)
- 26-digit case-insensitive portable textual representation
- 44-bit biased millisecond timestamp that ensures remaining life of 550 years
- Up to 268 million time-ordered but unpredictable unique IDs per millisecond
- 84-bit _layered_ randomness for collision resistance

```swift
import Scru128

print(scru128()) // e.g. "00RNOS8DGRPBRNGKN57QHSVFDC"
print(scru128()) // e.g. "00RNOS8DGRPBRNIKN57RO9NCBG"
```

See [SCRU128 Specification] for details.

[uuid]: https://en.wikipedia.org/wiki/Universally_unique_identifier
[ulid]: https://github.com/ulid/spec
[ksuid]: https://github.com/segmentio/ksuid
[scru128 specification]: https://github.com/scru128/spec

## Add swift-scru128 as a package dependency

To add this library to your Xcode project as a dependency, select File > Add
Packages and enter the package URL: https://github.com/scru128/swift-scru128

To use this library in a SwiftPM project, add the following line to the
dependencies in your Package.swift file:

```swift
.package(url: "https://github.com/scru128/swift-scru128", from: "0.2.1"),
```

And, include `Scru128` as a dependency for your target:

```swift
.target(
  name: "<target>",
  dependencies: [.product(name: "Scru128", package: "swift-scru128")]
)
```

## License

Copyright 2021 LiosK

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
