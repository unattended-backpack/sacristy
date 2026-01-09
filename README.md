# Sacristy

> Test me, oh Lord, and try me; examine my heart and mind.

Sacristy is Ethereum testnet infrastucture for Sigil development.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) - Docker is required as a container runtime.
- [Kurtosis](https://docs.kurtosis.com/install/) - Kurtosis is container orchestration for the testnet.

## Quick Start

The Sacristy is prepared to run using `make` goals in the [Makefile](./Makefile). Simply run `make l1` to prepare a new testnet. Once the network is up, you can bootstrap useful testing content using `make l1-bootstrap`. To tear it down, run `make clean`. You can see all commands with `make help`.

## Configuration

Configuration details for all of the Sacristy services are available in [`config.star`](./config.star).

## Hosts

For convenience, Sacristy exposes consistent local DNS routes to services at `*.sacristy.local`. To use these, make sure they are accessible in your `/etc/hosts` file per the Makefile instructions.

# Security

If you discover any bug; flaw; issue; dæmonic incursion; or other malicious, negligent, or incompetent action that impacts the security of any of these projects please responsibly disclose them to us; instructions are available [here](./SECURITY.md).

# License

The [license](./LICENSE) for all of our original work is `LicenseRef-VPL WITH AGPL-3.0-only`. This includes every asset in this repository: code, documentation, images, branding, and more. You are licensed to use all of it so long as you maintain _maximum possible virality_ and our copyleft licenses.

Permissive open source licenses are tools for the corporate subversion of libre software; visible source licenses are an even more malignant scourge. All original works in this project are to be licensed under the most aggressive, virulently-contagious copyleft terms possible. To that end everything is licensed under the [Viral Public License](./licenses/LicenseRef-VPL) coupled with the [GNU Affero General Public License v3.0](./licenses/AGPL-3.0-only) for use in the event that some unaligned party attempts to weasel their way out of copyleft protections. In short: if you use or modify anything in this project for any reason, your project must be licensed under these same terms.

For art assets specifically, in case you want to further split hairs or attempt to weasel out of this virality, we explicitly license those under the viral and copyleft [Free Art License 1.3](./licenses/FreeArtLicense-1.3).
