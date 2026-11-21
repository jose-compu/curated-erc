// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC7943NonFungible} from "./IERC7943NonFungible.sol";

/**
 * @title ERC7943NonFungibleUpgradeable
 * @dev Upgradeable ERC-7943 implementation for ERC-721 tokens with ERC-7201 freeze storage.
 */
abstract contract ERC7943NonFungibleUpgradeable is
    Initializable,
    ERC721Upgradeable,
    AccessControlUpgradeable,
    IERC7943NonFungible
{
    bytes32 public constant ENFORCER_ROLE = keccak256("ERC7943_ENFORCER_ROLE");

    error ERC7943InvalidEnforcer();

    /// @custom:storage-location erc7201:curatedcontracts.storage.ERC7943NonFungible
    struct ERC7943NonFungibleStorage {
        mapping(uint256 tokenId => bool) frozen;
        bool enforcerUpdate;
    }

    // keccak256(abi.encode(uint256(keccak256("curatedcontracts.storage.ERC7943NonFungible")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC7943NonFungibleStorageLocation =
        0x41313f5e0fdc7e90cc10ebf0269315a123d7856358b6f848912a50642fcc1c00;

    function _getERC7943NonFungibleStorage() private pure returns (ERC7943NonFungibleStorage storage $) {
        assembly {
            $.slot := ERC7943NonFungibleStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    /// @dev The child must call `__ERC721_init` (or equivalent) before this initializer.
    function __ERC7943NonFungible_init(address enforcer) internal onlyInitializing {
        __AccessControl_init();
        __ERC7943NonFungible_init_unchained(enforcer);
    }

    function __ERC7943NonFungible_init_unchained(address enforcer) internal onlyInitializing {
        if (enforcer == address(0)) revert ERC7943InvalidEnforcer();
        _grantRole(DEFAULT_ADMIN_ROLE, enforcer);
        _grantRole(ENFORCER_ROLE, enforcer);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, AccessControlUpgradeable, IERC165)
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

        ERC7943NonFungibleStorage storage $ = _getERC7943NonFungibleStorage();
        if ($.frozen[tokenId]) {
            $.frozen[tokenId] = false;
            emit Frozen(from, tokenId, false);
        }

        $.enforcerUpdate = true;
        _update(to, tokenId, address(0));
        $.enforcerUpdate = false;

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
        ERC7943NonFungibleStorage storage $ = _getERC7943NonFungibleStorage();
        $.frozen[tokenId] = frozenStatus;
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
        return _getERC7943NonFungibleStorage().frozen[tokenId];
    }

    /// @inheritdoc ERC721Upgradeable
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
        return !_getERC7943NonFungibleStorage().frozen[tokenId];
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        ERC7943NonFungibleStorage storage $ = _getERC7943NonFungibleStorage();
        if (!$.enforcerUpdate) {
            if (from == address(0)) {
                if (!canReceive(to)) {
                    revert ERC7943CannotReceive(to);
                }
            } else if (to == address(0)) {
                if (!canSend(from)) {
                    revert ERC7943CannotSend(from);
                }
                if ($.frozen[tokenId]) {
                    revert ERC7943InsufficientUnfrozenBalance(from, tokenId);
                }
                if (!canTransfer(from, address(0), tokenId)) {
                    revert ERC7943CannotTransfer(from, address(0), tokenId);
                }
            } else if (from != address(0) && to != address(0)) {
                if ($.frozen[tokenId]) {
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
            delete $.frozen[tokenId];
        }
        return super._update(to, tokenId, auth);
    }

    function _erc7943Mint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId);
    }

    function _erc7943EnforcerBurn(uint256 tokenId) internal virtual {
        address from = _ownerOf(tokenId);
        ERC7943NonFungibleStorage storage $ = _getERC7943NonFungibleStorage();
        if ($.frozen[tokenId]) {
            $.frozen[tokenId] = false;
            emit Frozen(from, tokenId, false);
        }
        $.enforcerUpdate = true;
        _update(address(0), tokenId, address(0));
        $.enforcerUpdate = false;
    }
}
