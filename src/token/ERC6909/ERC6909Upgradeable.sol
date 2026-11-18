// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC6909} from "./IERC6909.sol";

/**
 * @title ERC6909Upgradeable
 * @dev Upgradeable reference implementation of ERC-6909 with ERC-7201 namespaced storage.
 */
abstract contract ERC6909Upgradeable is Initializable, ContextUpgradeable, IERC6909, IERC165 {
    error ERC6909InsufficientBalance(address owner, uint256 id, uint256 balance, uint256 needed);
    error ERC6909InsufficientAllowance(address owner, address spender, uint256 id, uint256 allowance, uint256 needed);

    /// @custom:storage-location erc7201:curatedcontracts.storage.ERC6909
    struct ERC6909Storage {
        mapping(address owner => mapping(uint256 id => uint256)) _balances;
        mapping(address owner => mapping(address spender => mapping(uint256 id => uint256))) _allowances;
        mapping(address owner => mapping(address spender => bool)) _operators;
    }

    // keccak256(abi.encode(uint256(keccak256("curatedcontracts.storage.ERC6909")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC6909StorageLocation =
        0x5e2ae5780a3caf81f5c0593653ee1c986e9afa25e8c0d45eeafdd4a545618900;

    function _getERC6909Storage() private pure returns (ERC6909Storage storage $) {
        assembly {
            $.slot := ERC6909StorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function __ERC6909_init() internal onlyInitializing {}

    function __ERC6909_init_unchained() internal onlyInitializing {}

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC6909).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @inheritdoc IERC6909
    function balanceOf(address owner, uint256 id) public view virtual returns (uint256) {
        return _getERC6909Storage()._balances[owner][id];
    }

    /// @inheritdoc IERC6909
    function allowance(address owner, address spender, uint256 id) public view virtual returns (uint256) {
        return _getERC6909Storage()._allowances[owner][spender][id];
    }

    /// @inheritdoc IERC6909
    function isOperator(address owner, address spender) public view virtual returns (bool) {
        return _getERC6909Storage()._operators[owner][spender];
    }

    /// @inheritdoc IERC6909
    function transfer(address receiver, uint256 id, uint256 amount) public virtual returns (bool) {
        address caller = _msgSender();
        _transfer(caller, caller, receiver, id, amount);
        return true;
    }

    /// @inheritdoc IERC6909
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) public virtual returns (bool) {
        ERC6909Storage storage $ = _getERC6909Storage();
        address caller = _msgSender();
        if (caller != sender && !$._operators[sender][caller]) {
            uint256 current = $._allowances[sender][caller][id];
            if (current < amount) {
                revert ERC6909InsufficientAllowance(sender, caller, id, current, amount);
            }
            if (current != type(uint256).max) {
                unchecked {
                    $._allowances[sender][caller][id] = current - amount;
                }
            }
        }
        _transfer(caller, sender, receiver, id, amount);
        return true;
    }

    /// @inheritdoc IERC6909
    function approve(address spender, uint256 id, uint256 amount) public virtual returns (bool) {
        _approve(_msgSender(), spender, id, amount);
        return true;
    }

    /// @inheritdoc IERC6909
    function setOperator(address spender, bool approved) public virtual returns (bool) {
        _setOperator(_msgSender(), spender, approved);
        return true;
    }

    function _mint(address receiver, uint256 id, uint256 amount) internal virtual {
        ERC6909Storage storage $ = _getERC6909Storage();
        if (amount != 0) {
            unchecked {
                $._balances[receiver][id] += amount;
            }
        }
        emit Transfer(_msgSender(), address(0), receiver, id, amount);
    }

    function _burn(address owner, uint256 id, uint256 amount) internal virtual {
        ERC6909Storage storage $ = _getERC6909Storage();
        uint256 balance = $._balances[owner][id];
        if (balance < amount) {
            revert ERC6909InsufficientBalance(owner, id, balance, amount);
        }
        unchecked {
            $._balances[owner][id] = balance - amount;
        }
        emit Transfer(_msgSender(), owner, address(0), id, amount);
    }

    function _transfer(address caller, address sender, address receiver, uint256 id, uint256 amount) internal virtual {
        ERC6909Storage storage $ = _getERC6909Storage();
        uint256 balance = $._balances[sender][id];
        if (balance < amount) {
            revert ERC6909InsufficientBalance(sender, id, balance, amount);
        }
        unchecked {
            $._balances[sender][id] = balance - amount;
            if (receiver != address(0)) {
                $._balances[receiver][id] += amount;
            }
        }
        emit Transfer(caller, sender, receiver, id, amount);
    }

    function _approve(address owner, address spender, uint256 id, uint256 amount) internal virtual {
        _getERC6909Storage()._allowances[owner][spender][id] = amount;
        emit Approval(owner, spender, id, amount);
    }

    function _setOperator(address owner, address spender, bool approved) internal virtual {
        _getERC6909Storage()._operators[owner][spender] = approved;
        emit OperatorSet(owner, spender, approved);
    }
}
