// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ERC7751
 * @dev Wrapping of bubbled up reverts per EIP-7751.
 * See https://eips.ethereum.org/EIPS/eip-7751
 *
 * Reverts with `WrappedError` (selector `0x90bfb865`) to attach target, called selector,
 * raw inner revert bytes, and optional ABI-encoded context from the wrapping contract.
 */
library ERC7751 {
    /// @dev `WrappedError(address,bytes4,bytes,bytes)` selector per EIP-7751.
    bytes4 internal constant WRAPPED_ERROR_SELECTOR = 0x90bfb865;

    error WrappedError(address target, bytes4 selector, bytes reason, bytes details);

    /**
     * @dev Reverts with EIP-7751 `WrappedError`.
     */
    function revertWithWrappedError(address target, bytes4 selector, bytes memory reason, bytes memory details)
        internal
        pure
    {
        revert WrappedError(target, selector, reason, details);
    }

    /**
     * @dev Bubbles a caught revert from a low-level call, using the first four calldata bytes as selector.
     * @param target Called contract that reverted.
     * @param callData Calldata sent with the call; empty calldata yields `bytes4(0)` (plain ETH transfer).
     * @param reason Raw revert bytes from the inner call.
     * @param details Optional ABI-encoded custom error from this contract; use empty bytes when omitted.
     */
    function bubbleRevert(address target, bytes memory callData, bytes memory reason, bytes memory details)
        internal
        pure
    {
        revert WrappedError(target, _calledSelector(callData), reason, details);
    }

    /**
     * @dev Returns the selector of the function invoked by `callData`, or `bytes4(0)` when `callData` is empty.
     */
    function calledSelector(bytes memory callData) internal pure returns (bytes4) {
        return _calledSelector(callData);
    }

    function _calledSelector(bytes memory callData) private pure returns (bytes4 selector) {
        if (callData.length < 4) {
            return bytes4(0);
        }
        assembly {
            selector := mload(add(callData, 32))
        }
        selector = bytes4(selector);
    }
}
