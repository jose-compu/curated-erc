// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC7943MultiToken} from "./IERC7943MultiToken.sol";

/**
 * @title ERC7943MultiTokenUpgradeable
 * @dev Upgradeable ERC-7943 implementation for ERC-1155 tokens with ERC-7201 freeze storage.
 */
abstract contract ERC7943MultiTokenUpgradeable is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    IERC7943MultiToken
{
    bytes32 public constant ENFORCER_ROLE = keccak256("ERC7943_ENFORCER_ROLE");

    /// @custom:storage-location erc7201:curatedcontracts.storage.ERC7943MultiToken
    struct ERC7943MultiTokenStorage {
        mapping(address account => mapping(uint256 id => uint256)) frozen;
        bool enforcerUpdate;
    }

    // keccak256(abi.encode(uint256(keccak256("curatedcontracts.storage.ERC7943MultiToken")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC7943MultiTokenStorageLocation =
        0x71efb3b4c3e3110e79d9a019d85b0030c87279f16f0f689c5995c94135b93900;

    function _getERC7943MultiTokenStorage() private pure returns (ERC7943MultiTokenStorage storage $) {
        assembly {
            $.slot := ERC7943MultiTokenStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function __ERC7943MultiToken_init(address enforcer, string memory uri) internal onlyInitializing {
        __ERC1155_init(uri);
        __AccessControl_init();
        __ERC7943MultiToken_init_unchained(enforcer);
    }

    function __ERC7943MultiToken_init_unchained(address enforcer) internal onlyInitializing {
        _grantRole(DEFAULT_ADMIN_ROLE, enforcer);
        _grantRole(ENFORCER_ROLE, enforcer);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Upgradeable, AccessControlUpgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC7943MultiToken).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC7943MultiToken
    function forcedTransfer(address from, address to, uint256 tokenId, uint256 amount)
        public
        virtual
        onlyRole(ENFORCER_ROLE)
        returns (bool)
    {
        if (!canReceive(to)) {
            revert ERC7943CannotReceive(to);
        }
        uint256 balance = balanceOf(from, tokenId);
        if (balance < amount) {
            revert ERC1155InsufficientBalance(from, balance, amount, tokenId);
        }

        ERC7943MultiTokenStorage storage $ = _getERC7943MultiTokenStorage();
        uint256 frozen = $.frozen[from][tokenId];
        if (frozen > 0) {
            uint256 newFrozen = frozen > amount ? frozen - amount : 0;
            $.frozen[from][tokenId] = newFrozen;
            emit Frozen(from, tokenId, newFrozen);
        }

        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = tokenId;
        values[0] = amount;

        $.enforcerUpdate = true;
        _update(from, to, ids, values);
        $.enforcerUpdate = false;

        emit ForcedTransfer(from, to, tokenId, amount);
        return true;
    }

    /// @inheritdoc IERC7943MultiToken
    function setFrozenTokens(address account, uint256 tokenId, uint256 amount)
        public
        virtual
        onlyRole(ENFORCER_ROLE)
        returns (bool)
    {
        ERC7943MultiTokenStorage storage $ = _getERC7943MultiTokenStorage();
        $.frozen[account][tokenId] = amount;
        emit Frozen(account, tokenId, amount);
        return true;
    }

    /// @inheritdoc IERC7943MultiToken
    function canSend(address) public view virtual returns (bool) {
        return true;
    }

    /// @inheritdoc IERC7943MultiToken
    function canReceive(address) public view virtual returns (bool) {
        return true;
    }

    /// @inheritdoc IERC7943MultiToken
    function getFrozenTokens(address account, uint256 tokenId) public view virtual returns (uint256) {
        return _getERC7943MultiTokenStorage().frozen[account][tokenId];
    }

    /// @inheritdoc IERC7943MultiToken
    function canTransfer(address from, address to, uint256 tokenId, uint256 amount) public view virtual returns (bool) {
        if (!canSend(from) || !canReceive(to)) {
            return false;
        }
        uint256 balance = balanceOf(from, tokenId);
        if (amount > balance) {
            return true;
        }
        uint256 frozen = _getERC7943MultiTokenStorage().frozen[from][tokenId];
        uint256 unfrozen = balance > frozen ? balance - frozen : 0;
        return amount <= unfrozen;
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        virtual
        override
    {
        ERC7943MultiTokenStorage storage $ = _getERC7943MultiTokenStorage();
        if (!$.enforcerUpdate) {
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 id = ids[i];
                uint256 value = values[i];
                if (from == address(0)) {
                    if (!canReceive(to)) {
                        revert ERC7943CannotReceive(to);
                    }
                } else if (to == address(0)) {
                    if (!canSend(from)) {
                        revert ERC7943CannotSend(from);
                    }
                    _requireUnfrozen(from, id, value);
                } else {
                    _requireUserTransfer(from, to, id, value);
                }
            }
        }
        super._update(from, to, ids, values);
    }

    function _erc7943Mint(address to, uint256 tokenId, uint256 amount) internal virtual {
        ERC7943MultiTokenStorage storage $ = _getERC7943MultiTokenStorage();
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = tokenId;
        values[0] = amount;
        $.enforcerUpdate = true;
        _update(address(0), to, ids, values);
        $.enforcerUpdate = false;
    }

    function _erc7943EnforcerBurn(address from, uint256 tokenId, uint256 amount) internal virtual {
        ERC7943MultiTokenStorage storage $ = _getERC7943MultiTokenStorage();
        uint256 frozen = $.frozen[from][tokenId];
        if (amount > 0 && frozen > 0) {
            uint256 newFrozen = frozen > amount ? frozen - amount : 0;
            $.frozen[from][tokenId] = newFrozen;
            emit Frozen(from, tokenId, newFrozen);
        }
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = tokenId;
        values[0] = amount;
        $.enforcerUpdate = true;
        _update(from, address(0), ids, values);
        $.enforcerUpdate = false;
    }

    function _unfrozenAmount(address account, uint256 tokenId) internal view returns (uint256) {
        uint256 balance = balanceOf(account, tokenId);
        uint256 frozen = _getERC7943MultiTokenStorage().frozen[account][tokenId];
        return balance > frozen ? balance - frozen : 0;
    }

    function _requireUnfrozen(address from, uint256 tokenId, uint256 amount) internal view {
        uint256 balance = balanceOf(from, tokenId);
        if (amount <= balance) {
            uint256 unfrozen = _unfrozenAmount(from, tokenId);
            if (amount > unfrozen) {
                revert ERC7943InsufficientUnfrozenBalance(from, tokenId, amount, unfrozen);
            }
        }
    }

    function _requireUserTransfer(address from, address to, uint256 tokenId, uint256 amount) internal view {
        uint256 balance = balanceOf(from, tokenId);
        if (amount <= balance) {
            uint256 unfrozen = _unfrozenAmount(from, tokenId);
            if (amount > unfrozen) {
                revert ERC7943InsufficientUnfrozenBalance(from, tokenId, amount, unfrozen);
            }
        }
        if (!canSend(from)) {
            revert ERC7943CannotSend(from);
        }
        if (!canReceive(to)) {
            revert ERC7943CannotReceive(to);
        }
        if (!canTransfer(from, to, tokenId, amount)) {
            revert ERC7943CannotTransfer(from, to, tokenId, amount);
        }
    }
}
