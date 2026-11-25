<p align="center">
  <img src="img/logo.jpg" alt="Curated ERC" width="400" />
</p>

# Curated ERC

> v0.12.0

Canonical implementations of ERCs with real on-chain traction. Foundry-native, Solidity-tested.

Release banner (v0.12.0): [`img/linkedin-release-banner.jpg`](img/linkedin-release-banner.jpg). Regenerate with:

```bash
python3 scripts/render-linkedin-banner.py --version 0.12.0 \
  --subtitle "ERC-5006 rental NFT" \
  --detail "createUserRecord escrows the amount in the contract, and frozenBalanceOf keeps that amount after expiry until deleteUserRecord." \
  --erc-image website/img/ercs/erc5006.jpg
```

Optional `--detail` adds a short improvement line under the subtitle (up to 3 lines; full text required). For releases that add a **new ERC**, pass `--erc-image website/img/ercs/<id>.jpg` so the left panel shows that ERC’s surrealist painting in a thin frame instead of the large logo, with a small Curated ERC mark in the top-right. Without `--erc-image`, the banner stays unchanged (large logo on the left). Lining figures via `+lnum` when libraqm is available, else `GFSDidot-Regular.ttf` for lines with digits.

## The Gap

OpenZeppelin covers the core 10 standards (ERC-20, 721, 1155, etc.) thoroughly. The next 30 ERCs — standards with thousands of deployments, millions in TVL, and active protocol adoption — have no audited, library-grade implementations. Developers copy from unaudited repos or roll their own.

Curated ERC Contracts fills that gap.

## Principles

- **Foundry-native, Solidity-tested** — no JS test harness, no Hardhat dependency
- **Non-upgradeable + Upgradeable** — both variants in one repo, upgradeable versions use ERC-7201 namespaced storage
- **OZ-grade quality** — NatSpec docs, custom errors, fuzz tests, internal security audits per contract
- **Curated, not exhaustive** — only ERCs with demonstrated on-chain adoption

## Implemented

| ERC | Name | Category |
|-----|------|----------|
| 1363 | Payable Token | Token (ERC-20 extension) |
| 5192 | Minimal Soulbound NFT | Token (ERC-721 extension) |
| 4907 | Rental NFT | Token (ERC-721 extension) |
| 5006 | Rental NFT (ERC-1155) | Token (ERC-1155 extension) |
| 4906 | Metadata Update Extension | Token (ERC-721 extension) |
| 5484 | Consensual Soulbound Tokens | Token (ERC-721 extension) |
| 2309 | Consecutive Transfer (Batch Mint) | Token (ERC-721 extension) |
| 3525 | Semi-Fungible Token | Token (ERC-721 compatible) |
| 6909 | Minimal Multi-Token Interface | Token |
| 7943 | Universal RWA Interface | Token |
| 1271 | Signature Validation for Contracts | Cryptography |
| 5267 | EIP-712 Domain Retrieval | Cryptography |
| 6492 | Predeploy Signature Validation | Cryptography |
| 7751 | Wrapping of Bubbled Reverts | Utils / Error handling |
| 2771 | Meta Transactions | Context / Gasless UX |
| 3156 | Flash Loans | DeFi / Finance |
| 4626 | Tokenized Vaults | DeFi / Finance |
| 7201 | Namespaced Storage Layout | Utils / Upgrades |
| 8042 | Diamond Storage | Utils / Upgrades |
| 2535 | Diamonds (Multi-Facet Proxy) | Proxy / Upgrades |
| 4361 | Sign-In with Ethereum | Auth / Identity |
| 7818 | Expirable ERC-20 | Token (ERC-20 extension) |
| 8004 | Trustless Agents | AI Agents (identity, reputation, validation) |

23 standards implemented (non-upgradeable + upgradeable where applicable). Full plan across 40+ ERCs in [ROADMAP.md](./ROADMAP.md). Release history in [CHANGELOG.md](./CHANGELOG.md).

## Structure

```
src/
├── token/
│   ├── ERC1363/          # Payable Token (transfer/approve with callbacks)
│   ├── ERC2309/          # Consecutive Transfer (batch minting)
│   ├── ERC4906/          # Metadata Update Extension
│   ├── ERC3525/          # Semi-Fungible Token (slot + value model)
│   ├── ERC6909/          # Minimal Multi-Token Interface
│   ├── ERC7943/          # Universal RWA Interface (freeze & seizure)
│   ├── ERC4907/          # Rental NFT (user/owner split with expiry)
│   ├── ERC5006/          # Rental NFT for ERC-1155 (escrowed user records)
│   ├── ERC5192/          # Soulbound NFT (non-transferable)
│   ├── ERC5484/          # Consensual Soulbound Tokens (burn authorization)
│   └── ERC7818/          # Expirable ERC-20 (epoch-based expiry)
├── metatx/               # ERC-2771 Trusted Forwarder context
├── finance/
│   ├── ERC3156FlashLender.sol
│   └── ERC4626/          # Tokenized vaults (shares / assets)
├── diamond/              # ERC-2535 Diamonds (multi-facet proxy)
├── auth/                 # ERC-4361 Sign-In with Ethereum
│   ├── SIWE.sol          # Library: ERC-191 hash, verify, parse message
│   ├── SIWEParser.sol    # Stateless on-chain parser (no signature check)
│   └── SIWEVerifier.sol  # Stateless on-chain verifier contract
├── agent/                # ERC-8004 Trustless Agents
│   ├── ERC8004IdentityRegistry(.sol|Upgradeable.sol)
│   ├── ERC8004ReputationRegistry(.sol|Upgradeable.sol)
│   └── ERC8004ValidationRegistry(.sol|Upgradeable.sol)
└── utils/
    ├── cryptography/     # ERC-1271, ERC-5267, ERC-6492 Signature validation
    ├── ERC7751.sol       # ERC-7751 bubbled revert wrapping
    ├── ERC8042.sol       # ERC-8042 diamond storage slots
    └── StorageSlot7201.sol
```

Each ERC typically ships as:
- `IERC*.sol` — Standard interface
- `ERC*.sol` — Non-upgradeable implementation (abstract base or deployable contract)
- `ERC*Upgradeable.sol` — Upgradeable (Initializable + ERC-7201 namespaced storage)

Exceptions: **ERC-4361** exposes a library (`SIWE`) plus `SIWEParser` and `SIWEVerifier`; **ERC-6492**, **ERC-7201**, **ERC-7751**, and **ERC-8042** are libraries/utilities; **ERC-8004** ships three deployable registry contracts per variant.

## Installation

### Foundry

```bash
forge install jose-compu/curated-erc
```

Add the remapping to your `remappings.txt`:

```
curated-erc/=lib/curated-erc/src/
```

Then import and extend:

```solidity
import {ERC1363} from "curated-erc/token/ERC1363/ERC1363.sol";
import {ERC3525} from "curated-erc/token/ERC3525/ERC3525.sol";
import {ERC5192} from "curated-erc/token/ERC5192/ERC5192.sol";
import {ERC4907} from "curated-erc/token/ERC4907/ERC4907.sol";

contract MySFT is ERC3525 {
    constructor() ERC3525("MySFT", "MSFT", 18) {}
    function mint(address to, uint256 slot, uint256 value) external returns (uint256) {
        return _mint(to, slot, value);
    }
}

contract MyPayableToken is ERC1363 {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 1_000_000e18);
    }
}
```

**ERC-4361 (SIWE)** — verify a signed login message on-chain:

```solidity
import {SIWE} from "curated-erc/auth/SIWE.sol";
import {SIWEVerifier} from "curated-erc/auth/SIWEVerifier.sol";

// Library (inline in your contract)
SIWE.VerificationParams memory params = SIWE.VerificationParams({
    message: siweMessage,
    signature: sig,
    signer: address(0),       // parse address from message
    chainId: block.chainid,
    domain: "app.example.com",
    nonce: expectedNonce,
    issuedAt: 0,
    expirationTime: expiry,
    notBefore: 0
});
address user = SIWE.verify(params);

// Or use the standalone verifier (emits SIWEVerified)
SIWEVerifier verifier = new SIWEVerifier();
address user = verifier.verify(params);
```

ERC-4361 (SIWE) stays on ERC-191; permit-style tokens can inherit **ERC-5267** for EIP-712 domain retrieval instead.

**ERC-5267 (EIP-712 domain)** — expose domain fields for wallets and indexers:

```solidity
import {ERC5267} from "curated-erc/utils/cryptography/ERC5267.sol";

contract MyPermitToken is ERC20, ERC5267 {
    constructor() ERC20("MyToken", "MTK") ERC5267("MyToken", "1") {}
}
```

**ERC-7818 (Expirable ERC-20)** — tokens expire by epoch; `balanceOf` excludes expired buckets:

```solidity
import {ERC7818} from "curated-erc/token/ERC7818/ERC7818.sol";
import {IERC7818} from "curated-erc/token/ERC7818/IERC7818.sol";

contract MyExpirableToken is ERC7818 {
    constructor() ERC7818("MyToken", "MTK", 7 days, 2, IERC7818.EPOCH_TYPE.TIME_BASED) {}

    function mint(address to, uint256 amount) external {
        _mintExpirable(to, amount);
    }
}
```

**ERC-8004 (Trustless Agents)** — deploy the three registries as chain singletons:

```solidity
import {ERC8004IdentityRegistry} from "curated-erc/agent/ERC8004IdentityRegistry.sol";
import {ERC8004ReputationRegistry} from "curated-erc/agent/ERC8004ReputationRegistry.sol";
import {ERC8004ValidationRegistry} from "curated-erc/agent/ERC8004ValidationRegistry.sol";

ERC8004IdentityRegistry identity = new ERC8004IdentityRegistry();
ERC8004ReputationRegistry reputation =
    new ERC8004ReputationRegistry(address(identity), msg.sender);
ERC8004ValidationRegistry validation =
    new ERC8004ValidationRegistry(address(identity), msg.sender);

uint256 agentId = identity.register("ipfs://agent-registration.json");
```

**ERC-4626 (Tokenized Vault)** — ERC-20 shares redeemable for an underlying asset:

```solidity
import {ERC4626} from "curated-erc/finance/ERC4626/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyVault is ERC4626 {
    constructor(IERC20 asset_) ERC20("My Vault", "vMY") ERC4626(asset_) {}
}
```

`previewDeposit` / `previewMint` / `previewWithdraw` / `previewRedeem` report the exchange before execution. The base uses a virtual offset so an empty vault cannot be inflated by a first-depositor donation. ERC-2612 permit and fee-on-transfer assets are left to subclasses.

**ERC-7751 (Wrapped reverts)** — bubble inner failures with structured context:

```solidity
import {ERC7751} from "curated-erc/utils/ERC7751.sol";

try token.transfer(to, amount) {} catch (bytes memory err) {
    ERC7751.bubbleRevert(
        address(token),
        abi.encodeCall(token.transfer, (to, amount)),
        err,
        ""
    );
    // or: ERC7751.revertWithWrappedError(target, selector, err, details);
}
```

**ERC-8042 (Diamond storage)** — namespaced slots for diamond facets:

```solidity
import {ERC8042} from "curated-erc/utils/ERC8042.sol";

bytes32 slot = ERC8042.erc8042Slot("myproject.erc721.registry");
// Production: bytes32 constant SLOT = keccak256("myproject.erc721.registry");
```

**ERC-6909 (Multi-token)** — balances per owner and token id:

```solidity
import {ERC6909} from "curated-erc/token/ERC6909/ERC6909.sol";

contract MyMultiToken is ERC6909 {
    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount);
    }
}
```

**ERC-7943 (Universal RWA)** — compliance layer on ERC-20, ERC-721, or ERC-1155:

```solidity
import {ERC7943Fungible} from "curated-erc/token/ERC7943/ERC7943Fungible.sol";

contract MyRwa is ERC7943Fungible {
    constructor(address enforcer) ERC20("RWA", "RWA") ERC7943Fungible(enforcer) {}
}
```

**ERC-5006 (Rental NFT, ERC-1155)** — escrowed user right until the owner deletes the record:

```solidity
import {ERC5006} from "curated-erc/token/ERC5006/ERC5006.sol";

contract MyRental is ERC5006 {
    constructor() ERC1155("ipfs://item") ERC5006(16) {}
}
```

### Hardhat

The recommended path is the [`@nomicfoundation/hardhat-foundry`](https://hardhat.org/hardhat-runner/plugins/nomicfoundation-hardhat-foundry) plugin, which lets Hardhat read `remappings.txt` and resolve imports from the `lib/` folder directly — no duplicate OpenZeppelin installs.

1. Install the plugin:

```bash
npm install --save-dev @nomicfoundation/hardhat-foundry
```

2. Add it to your `hardhat.config.ts`:

```typescript
import "@nomicfoundation/hardhat-foundry";
```

3. Clone curated-erc as a git submodule (same as Foundry):

```bash
forge install <your-github-user>/curated-erc
```

4. Add the remapping to `remappings.txt`:

```
curated-erc/=lib/curated-erc/src/
```

The plugin picks up remappings automatically. Imports work the same way as in Foundry:

```solidity
import {ERC4907} from "curated-erc/token/ERC4907/ERC4907.sol";
import {SIWEVerifier} from "curated-erc/auth/SIWEVerifier.sol";
import {ERC8004IdentityRegistry} from "curated-erc/agent/ERC8004IdentityRegistry.sol";
```

### Hardhat (npm)

If you use Hardhat without Foundry, install from npm and add OpenZeppelin as dependencies:

1. Install the library and its peer dependencies:

```bash
npm install curated-erc @openzeppelin/contracts@5.5.0 @openzeppelin/contracts-upgradeable@5.5.0
```

2. Import and extend in your contracts:

```solidity
import {ERC1363} from "curated-erc/token/ERC1363/ERC1363.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyPayableToken is ERC1363 {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 1_000_000e18);
    }
}
```

Hardhat will compile the contracts in `node_modules/curated-erc` when resolving these imports; no extra config is needed. Use Solidity `^0.8.20` (e.g. `0.8.24`) in your `hardhat.config` to match the library.

## Development

```bash
forge install
forge build    # via-ir enabled for stack-heavy registry contracts
forge test -vv # 501 tests (unit + fuzz)
```

## npm publishing

Releases use [npm Trusted Publishing](https://docs.npmjs.com/trusted-publishers/) from GitHub Actions (`id-token: write`; no npm token). **Normal path:** push an annotated semver tag `v*.*.*` matching `package.json`; `publish.yml` publishes via OIDC. **Fallback:** merge a PR that updates [`.github/npm-publish-tag`](.github/npm-publish-tag) to the tag to publish (e.g. `v0.7.0`) when the tag already exists. See [CONTRIBUTING.md](./CONTRIBUTING.md). Configure the trusted publisher on [npmjs.com](https://www.npmjs.com/) for `jose-compu/curated-erc`, workflow `publish.yml` (no GitHub Environment unless configured on npm).

## Dependencies

- OpenZeppelin Contracts v5.5.0
- OpenZeppelin Contracts Upgradeable v5.5.0
- Forge Std v1.15.0

## License

MIT
