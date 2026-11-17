// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ERC8042
 * @dev Utility library for EIP-8042 diamond storage locations.
 *
 * ERC-8042 defines `erc8042(id) = keccak256(id)` for namespace identifiers that are
 * printable ASCII (bytes in the range 0x20..0x7E inclusive). Document structs with
 * `@custom:storage-location erc8042:<id>` (see https://eips.ethereum.org/EIPS/eip-8042).
 *
 * Contracts that share the same id share the same storage slot; use a project-specific
 * prefix (for example `"myproject.erc721.registry"`).
 */
library ERC8042 {
    error ERC8042InvalidIdentifier();

    /// @notice ERC-8042 storage slot: keccak256(id).
    /// @dev Every byte must be in 0x20..0x7E inclusive. Empty string reverts
    ///      (library policy; the spec does not treat empty as an identifier).
    ///      Space (0x20) is valid and not recommended: it breaks the NatSpec tag.
    ///      Production code should use a compile-time constant:
    ///      `bytes32 constant SLOT = keccak256("myproject.erc721.registry");`
    function erc8042Slot(string memory id) internal pure returns (bytes32 slot) {
        bytes memory data = bytes(id);
        uint256 len = data.length;
        if (len == 0) revert ERC8042InvalidIdentifier();

        for (uint256 i = 0; i < len; ++i) {
            uint8 b = uint8(data[i]);
            if (b < 0x20 || b > 0x7E) revert ERC8042InvalidIdentifier();
        }

        slot = keccak256(data);
    }
}
