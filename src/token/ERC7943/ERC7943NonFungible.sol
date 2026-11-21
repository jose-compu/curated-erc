// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC7943NonFungible} from "./IERC7943NonFungible.sol";

/**
 * @title ERC7943NonFungible
 * @dev Reference ERC-7943 implementation for non-fungible (ERC-721) real-world asset tokens.
 */
abstract contract ERC7943NonFungible is ERC721, AccessControl, IERC7943NonFungible {
    bytes32 public constant ENFORCER_ROLE = keccak256("ERC7943_ENFORCER_ROLE");

    error ERC7943InvalidEnforcer();

    mapping(uint256 tokenId => bool) private _frozen;
    bool private _enforcerUpdate;

    constructor(address enforcer) {
        if (enforcer == address(0)) revert ERC7943InvalidEnforcer();
        _grantRole(DEFAULT_ADMIN_ROLE, enforcer);
        _grantRole(ENFORCER_ROLE, enforcer);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC7943NonFungible).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC7943NonFungible
    function forcedTransfer(address from, address to, uint256 tokenId)
        public
        virtual
        onlyRole(ENFORCER_ROLE)
        returns (bool)
    {
        if (!canReceive(to)) {
            revert ERC7943CannotReceive(to);
        }
        if (_ownerOf(tokenId) == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        if (_ownerOf(tokenId) != from) {
            revert ERC721IncorrectOwner(from, tokenId, _ownerOf(tokenId));
        }

        if (_frozen[tokenId]) {
            _frozen[tokenId] = false;
            emit Frozen(from, tokenId, false);
        }

        _enforcerUpdate = true;
        _update(to, tokenId, address(0));
        _enforcerUpdate = false;

        emit ForcedTransfer(from, to, tokenId);
        return true;
    }

    /// @inheritdoc IERC7943NonFungible
    function setFrozenTokens(address account, uint256 tokenId, bool frozenStatus)
        public
        virtual
        onlyRole(ENFORCER_ROLE)
        returns (bool)
    {
        _frozen[tokenId] = frozenStatus;
        emit Frozen(account, tokenId, frozenStatus);
        return true;
    }

    /// @inheritdoc IERC7943NonFungible
    function canSend(address) public view virtual returns (bool) {
        return true;
    }

    /// @inheritdoc IERC7943NonFungible
    function canReceive(address) public view virtual returns (bool) {
        return true;
    }

    /// @inheritdoc IERC7943NonFungible
    function getFrozenTokens(address, uint256 tokenId) public view virtual returns (bool) {
        return _frozen[tokenId];
    }

    /// @inheritdoc ERC721
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        if (owner != from) {
            revert ERC721IncorrectOwner(from, tokenId, owner);
        }
        super.transferFrom(from, to, tokenId);
    }

    /// @inheritdoc IERC7943NonFungible
    function canTransfer(address from, address to, uint256 tokenId) public view virtual returns (bool) {
        if (!canSend(from) || !canReceive(to)) {
            return false;
        }
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            return true;
        }
        if (owner != from) {
            return true;
        }
        return !_frozen[tokenId];
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        if (!_enforcerUpdate) {
            if (from == address(0)) {
                if (!canReceive(to)) {
                    revert ERC7943CannotReceive(to);
                }
            } else if (to == address(0)) {
                if (!canSend(from)) {
                    revert ERC7943CannotSend(from);
                }
                if (_frozen[tokenId]) {
                    revert ERC7943InsufficientUnfrozenBalance(from, tokenId);
                }
                if (!canTransfer(from, address(0), tokenId)) {
                    revert ERC7943CannotTransfer(from, address(0), tokenId);
                }
            } else if (from != address(0) && to != address(0)) {
                if (_frozen[tokenId]) {
                    revert ERC7943InsufficientUnfrozenBalance(from, tokenId);
                }
                if (!canSend(from)) {
                    revert ERC7943CannotSend(from);
                }
                if (!canReceive(to)) {
                    revert ERC7943CannotReceive(to);
                }
                if (!canTransfer(from, to, tokenId)) {
                    revert ERC7943CannotTransfer(from, to, tokenId);
                }
            }
        }
        if (to == address(0)) {
            delete _frozen[tokenId];
        }
        return super._update(to, tokenId, auth);
    }

    function _erc7943Mint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId);
    }

    function _erc7943EnforcerBurn(uint256 tokenId) internal virtual {
        address from = _ownerOf(tokenId);
        if (_frozen[tokenId]) {
            _frozen[tokenId] = false;
            emit Frozen(from, tokenId, false);
        }
        _enforcerUpdate = true;
        _update(address(0), tokenId, address(0));
        _enforcerUpdate = false;
    }
}
