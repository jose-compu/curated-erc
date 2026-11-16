// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC5267
 * @dev Interface for EIP-712 domain retrieval (ERC-5267).
 * See https://eips.ethereum.org/EIPS/eip-5267
 */
interface IERC5267 {
    /**
     * @dev MAY be emitted when the EIP-712 domain metadata changes.
     */
    event EIP712DomainChanged();

    /**
     * @dev Returns the fields of the EIP-712 domain that are present and their values.
     */
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
}
