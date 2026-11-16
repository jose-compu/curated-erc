// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC5267} from "./IERC5267.sol";

/**
 * @title ERC5267
 * @dev EIP-712 domain retrieval mixin (ERC-5267). Retrieval only: no `DOMAIN_SEPARATOR`,
 * no `hashTypedData`, and no salt or extensions in the default layout.
 *
 * Subclasses that customize salt or extensions via {_eip712Salt} and {_eip712Extensions}
 * must set the corresponding bits in {_eip712Fields} (e.g. bit 4 for salt).
 */
abstract contract ERC5267 is IERC5267 {
    string private _name;
    string private _version;

    constructor(string memory name_, string memory version_) {
        _name = name_;
        _version = version_;
        emit EIP712DomainChanged();
    }

    /// @inheritdoc IERC5267
    function eip712Domain()
        public
        view
        virtual
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (_eip712Fields(), _name, _version, block.chainid, address(this), _eip712Salt(), _eip712Extensions());
    }

    /**
     * @dev Updates the EIP-712 domain `name` and `version`. Emits {EIP712DomainChanged}
     * only when either value actually changes (compared by `keccak256(bytes(...))`).
     */
    function _setDomain(string memory name_, string memory version_) internal {
        bool changed = keccak256(bytes(_name)) != keccak256(bytes(name_))
            || keccak256(bytes(_version)) != keccak256(bytes(version_));
        if (!changed) {
            return;
        }
        _name = name_;
        _version = version_;
        emit EIP712DomainChanged();
    }

    /**
     * @dev Domain fields bitmap. Default `0x0f`: name, version, chainId, verifyingContract.
     */
    function _eip712Fields() internal view virtual returns (bytes1) {
        return hex"0f";
    }

    function _eip712Salt() internal view virtual returns (bytes32) {
        return bytes32(0);
    }

    function _eip712Extensions() internal view virtual returns (uint256[] memory extensions) {
        return extensions;
    }
}
