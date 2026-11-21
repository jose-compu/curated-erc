# Security audit: recent additions (2026-11-21)

## Scope

In-scope packages and variants shipped in v0.11.0 and reviewed for v0.11.1:

- ERC-5267 (EIP-712 domain retrieval)
- ERC-8042 (diamond storage identifiers)
- ERC-6909 (minimal multi-token)
- ERC-7943 (universal RWA interface): fungible, non-fungible, multi-token, each with upgradeable variants and ERC-7201 storage namespaces

## Method

Manual specification review against ERC/EIP text, OpenZeppelin v5.5.0 interaction checks, ERC-7201 slot isolation, and Foundry regression tests (`FOUNDRY_PROFILE=ci forge test`).

## Findings

| ID | Severity | Summary | Disposition |
| --- | --- | --- | --- |
| F1 | High | NFT `forcedTransfer` passed the enforcer as ERC-721 `auth`, so seizure reverted unless the enforcer was approved | Fixed in v0.11.1 |
| F2 | High | ERC-1155 batch transfer checked duplicate ids separately, allowing more than the unfrozen balance to move | Fixed in v0.11.1 |
| F3 | Medium | `_erc7943Mint` skipped receiver checks via `enforcerUpdate` | Fixed in v0.11.1 |
| F4 | Medium | Permissionless burn did not call `canTransfer` | Fixed in v0.11.1 |
| F5 | Low | ERC-6909 mint/credit used unchecked math without a supply cap | Fixed in v0.11.1 |
| F6 | Low | Upgradeable fungible/NFT init overwrote child ERC-20/ERC-721 name | Fixed in v0.11.1 |
| F7 | Low | Frozen NFT `transferFrom` surfaced freeze error instead of owner error | Fixed in v0.11.1 |
| F8 | Low | Zero-address enforcer accepted at deploy/init | Fixed in v0.11.1 |

## Fixes (v0.11.1)

- **F1:** `forcedTransfer` on ERC-7943 NFT uses `_update(..., address(0))` for authorization.
- **F2:** ERC-7943 multi-token `_update` sums duplicate ids in a batch before unfrozen and transfer checks.
- **F3:** Mint helpers call `_update`, `_safeMint`, or `_mint` without bypassing receiver validation.
- **F4:** Burn branch in `_update` reverts with `ERC7943CannotTransfer` when `canTransfer` is false.
- **F5:** ERC-6909 credits use checked arithmetic; debits remain unchecked after balance check.
- **F6:** Removed empty `__ERC20_init` / `__ERC721_init` from ERC-7943 upgradeable parents; child must initialize token metadata first.
- **F7:** NFT `transferFrom` validates owner before freeze logic.
- **F8:** `ERC7943InvalidEnforcer` when `enforcer == address(0)` in constructors and init unchained hooks.

## Checked and left alone

- ERC-7201 slot constants and namespace separation from OpenZeppelin and other Curated ERC namespaces
- ERC-5267 field layout, `block.chainid`, and `address(this)` in domain
- ERC-8042 printable-ASCII identifier rule and `LibDiamond` documentation
- ERC-6909 interface id `0x0f632fb3`; no optional metadata extensions added in this patch
- ERC-7943 `canTransfer` returning true when amount exceeds balance (spec-compliant)
- `forcedTransfer` freeze reduction and event ordering

## Deferred

None.