// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC7943MultiToken} from "./IERC7943MultiToken.sol";

/**
 * @title ERC7943MultiToken
 * @dev Reference ERC-7943 implementation for multi-token (ERC-1155) real-world asset tokens.
 */
abstract contract ERC7943MultiToken is ERC1155, AccessControl, IERC7943MultiToken {
    bytes32 public constant ENFORCER_ROLE = keccak256("ERC7943_ENFORCER_ROLE");

    error ERC7943InvalidEnforcer();

    mapping(address account => mapping(uint256 id => uint256)) private _frozen;
    bool private _enforcerUpdate;

    constructor(address enforcer, string memory uri) ERC1155(uri) {
        if (enforcer == address(0)) revert ERC7943InvalidEnforcer();
        _grantRole(DEFAULT_ADMIN_ROLE, enforcer);
        _grantRole(ENFORCER_ROLE, enforcer);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, AccessControl, IERC165)
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

        uint256 frozen = _frozen[from][tokenId];
        if (frozen > 0) {
            uint256 newFrozen = frozen > amount ? frozen - amount : 0;
            _frozen[from][tokenId] = newFrozen;
            emit Frozen(from, tokenId, newFrozen);
        }

        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = tokenId;
        values[0] = amount;

        _enforcerUpdate = true;
        _update(from, to, ids, values);
        _enforcerUpdate = false;

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
        _frozen[account][tokenId] = amount;
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
        return _frozen[account][tokenId];
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
        uint256 frozen = _frozen[from][tokenId];
        uint256 unfrozen = balance > frozen ? balance - frozen : 0;
        return amount <= unfrozen;
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        virtual
        override
    {
        if (!_enforcerUpdate) {
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 id = ids[i];
                bool firstSighting = true;
                for (uint256 k = 0; k < i; ++k) {
                    if (ids[k] == id) {
                        firstSighting = false;
                        break;
                    }
                }
                if (!firstSighting) continue;

                uint256 summed = 0;
                for (uint256 j = 0; j < ids.length; ++j) {
                    if (ids[j] == id) {
                        summed += values[j];
                    }
                }

                if (from == address(0)) {
                    if (!canReceive(to)) {
                        revert ERC7943CannotReceive(to);
                    }
                } else if (to == address(0)) {
                    if (!canSend(from)) {
                        revert ERC7943CannotSend(from);
                    }
                    _requireUnfrozen(from, id, summed);
                    if (!canTransfer(from, address(0), id, summed)) {
                        revert ERC7943CannotTransfer(from, address(0), id, summed);
                    }
                } else {
                    _requireUserTransfer(from, to, id, summed);
                }
            }
        }
        super._update(from, to, ids, values);
    }

    function _erc7943Mint(address to, uint256 tokenId, uint256 amount) internal virtual {
        _mint(to, tokenId, amount, "");
    }

    function _erc7943EnforcerBurn(address from, uint256 tokenId, uint256 amount) internal virtual {
        uint256 frozen = _frozen[from][tokenId];
        if (amount > 0 && frozen > 0) {
            uint256 newFrozen = frozen > amount ? frozen - amount : 0;
            _frozen[from][tokenId] = newFrozen;
            emit Frozen(from, tokenId, newFrozen);
        }
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = tokenId;
        values[0] = amount;
        _enforcerUpdate = true;
        _update(from, address(0), ids, values);
        _enforcerUpdate = false;
    }

    function _unfrozenAmount(address account, uint256 tokenId) internal view returns (uint256) {
        uint256 balance = balanceOf(account, tokenId);
        uint256 frozen = _frozen[account][tokenId];
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
