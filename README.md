## Features

- Unowned, immutable primative for storing file assets onchain.
- Utilizes SSTORE2 for onchain storage with deterministic CREATE2 addresses to prevent duplicate chunks of data from being stored.
- Data chunks can be added by uploading bytes or providing a storage pointer to the existing SSTORE2 address that the data is stored at.
- Assets may be finalized by uploader to prevent changes.
- Asset SHA256 can be validated onchain to be added to validated hash catalog.
- Asset catalog is searchable by name, uploader, expected SHA256 hash and validated SHA256 hash.
- Assets can be returned as bytes, string or Base64 encoded string.
- Storage is compatible with [scripty.sol](https://int-art.gitbook.io/scripty.sol/ "ScriptyBuilder")

## Deployment
OnchainLibrary may be deployed to any EVM chain at the address `0x00000000009A2E85957ae69A3b96efece482d15C` using the Keyless CREATE2 Factory by [0age](https://twitter.com/z0age).

[Deployment bytecode](./deployment/bytecode/OnchainLibrary.txt)
Salt: `0x00000000000000000000000000000000000000009b4610c9d7b50d3590da2b87`
[Verification JSON](./deployment/verification/OnchainLibrary.json)

## Licensing
OnchainLibrary is licensed under the `MIT` license, see [`LICENSE`](./LICENSE).