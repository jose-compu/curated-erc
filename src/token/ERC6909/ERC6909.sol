// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC6909} from "./IERC6909.sol";

/**
 * @title ERC6909
 * @dev Reference implementation of ERC-6909 Minimal Multi-Token Interface.
 * See https://eips.ethereum.org/EIPS/eip-6909
 */
abstract contract ERC6909 is Context, IERC6909, IERC165 {
    error ERC6909InsufficientBalance(address owner, uint256 id, uint256 balance, uint256 needed);
    error ERC6909InsufficientAllowance(address owner, address spender, uint256 id, uint256 allowance, uint256 needed);

    mapping(address owner => mapping(uint256 id => uint256)) private _balances;
    mapping(address owner => mapping(address spender => mapping(uint256 id => uint256))) private _allowances;
    mapping(address owner => mapping(address spender => bool)) private _operators;

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC6909).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @inheritdoc IERC6909
    function balanceOf(address owner, uint256 id) public view virtual returns (uint256) {
        return _balances[owner][id];
    }

    /// @inheritdoc IERC6909
    function allowance(address owner, address spender, uint256 id) public view virtual returns (uint256) {
        return _allowances[owner][spender][id];
    }

    /// @inheritdoc IERC6909
    function isOperator(address owner, address spender) public view virtual returns (bool) {
        return _operators[owner][spender];
    }

    /// @inheritdoc IERC6909
    function transfer(address receiver, uint256 id, uint256 amount) public virtual returns (bool) {
        address caller = _msgSender();
        _transfer(caller, caller, receiver, id, amount);
        return true;
    }

    /// @inheritdoc IERC6909
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) public virtual returns (bool) {
        address caller = _msgSender();
        if (caller != sender && !_operators[sender][caller]) {
            uint256 current = _allowances[sender][caller][id];
            if (current < amount) {
                revert ERC6909InsufficientAllowance(sender, caller, id, current, amount);
            }
            if (current != type(uint256).max) {
                unchecked {
                    _allowances[sender][caller][id] = current - amount;
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
        if (amount != 0) {
            _balances[receiver][id] += amount;
        }
        emit Transfer(_msgSender(), address(0), receiver, id, amount);
    }

    function _burn(address owner, uint256 id, uint256 amount) internal virtual {
        uint256 balance = _balances[owner][id];
        if (balance < amount) {
            revert ERC6909InsufficientBalance(owner, id, balance, amount);
        }
        unchecked {
            _balances[owner][id] = balance - amount;
        }
        emit Transfer(_msgSender(), owner, address(0), id, amount);
    }

    function _transfer(address caller, address sender, address receiver, uint256 id, uint256 amount) internal virtual {
        uint256 balance = _balances[sender][id];
        if (balance < amount) {
            revert ERC6909InsufficientBalance(sender, id, balance, amount);
        }
        unchecked {
            _balances[sender][id] = balance - amount;
        }
        if (receiver != address(0)) {
            _balances[receiver][id] += amount;
        }
        emit Transfer(caller, sender, receiver, id, amount);
    }

    function _approve(address owner, address spender, uint256 id, uint256 amount) internal virtual {
        _allowances[owner][spender][id] = amount;
        emit Approval(owner, spender, id, amount);
    }

    function _setOperator(address owner, address spender, bool approved) internal virtual {
        _operators[owner][spender] = approved;
        emit OperatorSet(owner, spender, approved);
    }
}
