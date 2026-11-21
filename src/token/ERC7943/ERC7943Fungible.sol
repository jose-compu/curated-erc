// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC7943Fungible} from "./IERC7943Fungible.sol";

/**
 * @title ERC7943Fungible
 * @dev Reference ERC-7943 implementation for fungible (ERC-20) real-world asset tokens.
 *
 * Adds freeze controls, compliance views, and enforcer-only seizure to {ERC20}.
 */
abstract contract ERC7943Fungible is ERC20, AccessControl, IERC7943Fungible {
    bytes32 public constant ENFORCER_ROLE = keccak256("ERC7943_ENFORCER_ROLE");

    error ERC7943InvalidEnforcer();

    mapping(address account => uint256) private _frozen;
    bool private _enforcerUpdate;

    constructor(address enforcer) {
        if (enforcer == address(0)) revert ERC7943InvalidEnforcer();
        _grantRole(DEFAULT_ADMIN_ROLE, enforcer);
        _grantRole(ENFORCER_ROLE, enforcer);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, IERC165) returns (bool) {
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

        uint256 frozen = _frozen[from];
        if (frozen > 0) {
            uint256 newFrozen = frozen > amount ? frozen - amount : 0;
            _frozen[from] = newFrozen;
            emit Frozen(from, newFrozen);
        }

        _enforcerUpdate = true;
        _update(from, to, amount);
        _enforcerUpdate = false;

        emit ForcedTransfer(from, to, amount);
        return true;
    }

    /// @inheritdoc IERC7943Fungible
    function setFrozenTokens(address account, uint256 amount) public virtual onlyRole(ENFORCER_ROLE) returns (bool) {
        _frozen[account] = amount;
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
        return _frozen[account];
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

    /**
     * @dev Validates compliance rules before the underlying {ERC20-_update}.
     */
    function _update(address from, address to, uint256 value) internal virtual override {
        if (!_enforcerUpdate) {
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

    /**
     * @dev Enforcer mint helper; still enforces `canReceive` on the recipient.
     */
    function _erc7943Mint(address to, uint256 amount) internal virtual {
        _update(address(0), to, amount);
    }

    /**
     * @dev Enforcer burn helper; may reduce freeze and emits {Frozen} before the burn.
     */
    function _erc7943EnforcerBurn(address from, uint256 amount) internal virtual {
        uint256 frozen = _frozen[from];
        if (amount > 0 && frozen > 0) {
            uint256 newFrozen = frozen > amount ? frozen - amount : 0;
            _frozen[from] = newFrozen;
            emit Frozen(from, newFrozen);
        }
        _enforcerUpdate = true;
        _update(from, address(0), amount);
        _enforcerUpdate = false;
    }

    function _unfrozenAmount(address account) internal view returns (uint256) {
        uint256 balance = balanceOf(account);
        uint256 frozen = _frozen[account];
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
