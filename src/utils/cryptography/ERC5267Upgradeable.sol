// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC5267} from "./IERC5267.sol";

/**
 * @title ERC5267Upgradeable
 * @dev Upgradeable EIP-712 domain retrieval mixin (ERC-5267) with ERC-7201 namespaced storage.
 *
 * Implementation constructors should call `_disableInitializers()`.
 */
abstract contract ERC5267Upgradeable is Initializable, IERC5267 {
    /// @custom:storage-location erc7201:curatedcontracts.storage.ERC5267
    struct ERC5267Storage {
        string name;
        string version;
    }

    // keccak256(abi.encode(uint256(keccak256("curatedcontracts.storage.ERC5267")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC5267StorageLocation =
        0xa6975cdd03b545c71f44173764996f98911c37b038be6f5e1e2486b10ea0e300;

    function _getERC5267Storage() private pure returns (ERC5267Storage storage $) {
        assembly {
            $.slot := ERC5267StorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function __ERC5267_init(string memory name_, string memory version_) internal onlyInitializing {
        __ERC5267_init_unchained(name_, version_);
    }

    function __ERC5267_init_unchained(string memory name_, string memory version_) internal onlyInitializing {
        ERC5267Storage storage $ = _getERC5267Storage();
        $.name = name_;
        $.version = version_;
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
        ERC5267Storage storage $ = _getERC5267Storage();
        return (_eip712Fields(), $.name, $.version, block.chainid, address(this), _eip712Salt(), _eip712Extensions());
    }

    /**
     * @dev Updates the EIP-712 domain `name` and `version`. Emits {EIP712DomainChanged}
     * only when either value actually changes (compared by `keccak256(bytes(...))`).
     */
    function _setDomain(string memory name_, string memory version_) internal {
        ERC5267Storage storage $ = _getERC5267Storage();
        bool changed = keccak256(bytes($.name)) != keccak256(bytes(name_))
            || keccak256(bytes($.version)) != keccak256(bytes(version_));
        if (!changed) {
            return;
        }
        $.name = name_;
        $.version = version_;
        emit EIP712DomainChanged();
    }

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
