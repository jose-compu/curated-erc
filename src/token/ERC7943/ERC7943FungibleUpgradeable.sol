// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC7943Fungible} from "./IERC7943Fungible.sol";

/**
 * @title ERC7943FungibleUpgradeable
 * @dev Upgradeable ERC-7943 implementation for fungible tokens with ERC-7201 freeze storage.
 */
abstract contract ERC7943FungibleUpgradeable is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    IERC7943Fungible
{
    bytes32 public constant ENFORCER_ROLE = keccak256("ERC7943_ENFORCER_ROLE");

    error ERC7943InvalidEnforcer();

    /// @custom:storage-location erc7201:curatedcontracts.storage.ERC7943Fungible
    struct ERC7943FungibleStorage {
        mapping(address account => uint256) frozen;
        bool enforcerUpdate;
    }

    // keccak256(abi.encode(uint256(keccak256("curatedcontracts.storage.ERC7943Fungible")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC7943FungibleStorageLocation =
        0x34a291192137eb57866d9ec1d5d6de7e99b16f165d8bc907abb999a5e466cd00;

    function _getERC7943FungibleStorage() private pure returns (ERC7943FungibleStorage storage $) {
        assembly {
            $.slot := ERC7943FungibleStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    /// @dev The child must call `__ERC20_init` (or equivalent) before this initializer.
    function __ERC7943Fungible_init(address enforcer) internal onlyInitializing {
        __AccessControl_init();
        __ERC7943Fungible_init_unchained(enforcer);
    }

    function __ERC7943Fungible_init_unchained(address enforcer) internal onlyInitializing {
        if (enforcer == address(0)) revert ERC7943InvalidEnforcer();
        _grantRole(DEFAULT_ADMIN_ROLE, enforcer);
        _grantRole(ENFORCER_ROLE, enforcer);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC7943Fungible).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC7943Fungible
    function forcedTransfer(address from, address to, uint256 amount)
        public
        virtual
        onlyRole(ENFORCER_ROLE)
        returns (bool)
    {
        if (!canReceive(to)) {
            revert ERC7943CannotReceive(to);
        }
        uint256 balance = balanceOf(from);
        if (balance < amount) {
            revert ERC20InsufficientBalance(from, balance, amount);
        }

        ERC7943FungibleStorage storage $ = _getERC7943FungibleStorage();
        uint256 frozen = $.frozen[from];
        if (frozen > 0) {
            uint256 newFrozen = frozen > amount ? frozen - amount : 0;
            $.frozen[from] = newFrozen;
            emit Frozen(from, newFrozen);
        }

        $.enforcerUpdate = true;
        _update(from, to, amount);
        $.enforcerUpdate = false;

        emit ForcedTransfer(from, to, amount);
        return true;
    }

    /// @inheritdoc IERC7943Fungible
    function setFrozenTokens(address account, uint256 amount) public virtual onlyRole(ENFORCER_ROLE) returns (bool) {
        ERC7943FungibleStorage storage $ = _getERC7943FungibleStorage();
        $.frozen[account] = amount;
        emit Frozen(account, amount);
        return true;
    }

    /// @inheritdoc IERC7943Fungible
    function canSend(address) public view virtual returns (bool) {
        return true;
    }

    /// @inheritdoc IERC7943Fungible
    function canReceive(address) public view virtual returns (bool) {
        return true;
    }

    /// @inheritdoc IERC7943Fungible
    function getFrozenTokens(address account) public view virtual returns (uint256) {
        return _getERC7943FungibleStorage().frozen[account];
    }

    /// @inheritdoc IERC7943Fungible
    function canTransfer(address from, address to, uint256 amount) public view virtual returns (bool) {
        if (!canSend(from) || !canReceive(to)) {
            return false;
        }
        uint256 balance = balanceOf(from);
        if (amount > balance) {
            return true;
        }
        return amount <= _unfrozenAmount(from);
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        ERC7943FungibleStorage storage $ = _getERC7943FungibleStorage();
        if (!$.enforcerUpdate) {
            if (from == address(0)) {
                if (!canReceive(to)) {
                    revert ERC7943CannotReceive(to);
                }
            } else if (to == address(0)) {
                if (!canSend(from)) {
                    revert ERC7943CannotSend(from);
                }
                _requireUnfrozen(from, value);
                if (!canTransfer(from, address(0), value)) {
                    revert ERC7943CannotTransfer(from, address(0), value);
                }
            } else {
                _requireUserTransfer(from, to, value);
            }
        }
        super._update(from, to, value);
    }

    function _erc7943Mint(address to, uint256 amount) internal virtual {
        _update(address(0), to, amount);
    }

    function _erc7943EnforcerBurn(address from, uint256 amount) internal virtual {
        ERC7943FungibleStorage storage $ = _getERC7943FungibleStorage();
        uint256 frozen = $.frozen[from];
        if (amount > 0 && frozen > 0) {
            uint256 newFrozen = frozen > amount ? frozen - amount : 0;
            $.frozen[from] = newFrozen;
            emit Frozen(from, newFrozen);
        }
        $.enforcerUpdate = true;
        _update(from, address(0), amount);
        $.enforcerUpdate = false;
    }

    function _unfrozenAmount(address account) internal view returns (uint256) {
        uint256 balance = balanceOf(account);
        uint256 frozen = _getERC7943FungibleStorage().frozen[account];
        return balance > frozen ? balance - frozen : 0;
    }

    function _requireUnfrozen(address from, uint256 amount) internal view {
        uint256 balance = balanceOf(from);
        if (amount <= balance) {
            uint256 unfrozen = _unfrozenAmount(from);
            if (amount > unfrozen) {
                revert ERC7943InsufficientUnfrozenBalance(from, amount, unfrozen);
            }
        }
    }

    function _requireUserTransfer(address from, address to, uint256 amount) internal view {
        uint256 balance = balanceOf(from);
        if (amount <= balance) {
            uint256 unfrozen = _unfrozenAmount(from);
            if (amount > unfrozen) {
                revert ERC7943InsufficientUnfrozenBalance(from, amount, unfrozen);
            }
        }
        if (!canSend(from)) {
            revert ERC7943CannotSend(from);
        }
        if (!canReceive(to)) {
            revert ERC7943CannotReceive(to);
        }
        if (!canTransfer(from, to, amount)) {
            revert ERC7943CannotTransfer(from, to, amount);
        }
    }
}
