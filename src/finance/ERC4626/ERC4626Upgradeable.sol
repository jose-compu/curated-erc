// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC4626} from "./IERC4626.sol";

/**
 * @title ERC4626Upgradeable
 * @dev Upgradeable version of {ERC4626}. Uses ERC-7201 namespaced storage for
 * the asset address and cached asset decimals.
 *
 * Conversion, rounding, and inflation-offset rules match {ERC4626}.
 * ERC-2612 permit is left to subclasses. Fee-on-transfer and rebasing assets
 * are unsupported.
 */
abstract contract ERC4626Upgradeable is Initializable, ERC20Upgradeable, IERC4626 {
    using Math for uint256;
    using SafeERC20 for IERC20;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    /// @dev Deposit exceeds {maxDeposit} for `receiver`.
    error ERC4626ExceededMaxDeposit(address receiver, uint256 assets, uint256 maxAssets);

    /// @dev Mint exceeds {maxMint} for `receiver`.
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 maxShares);

    /// @dev Withdraw exceeds {maxWithdraw} for `owner`.
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 maxAssets);

    /// @dev Redeem exceeds {maxRedeem} for `owner`.
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 maxShares);

    /// @dev Mutative vault call re-entered.
    error ERC4626ReentrantCall();

    /// @custom:storage-location erc7201:curatedcontracts.storage.ERC4626
    struct ERC4626Storage {
        IERC20 asset;
        uint8 underlyingDecimals;
        uint256 reentrancyStatus;
    }

    // keccak256(abi.encode(uint256(keccak256("curatedcontracts.storage.ERC4626")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC4626StorageLocation =
        0xdbb9fc12182ed1737699199975af0444c4e748bbedf3649c6f1feb673c58b700;

    function _getERC4626Storage() private pure returns (ERC4626Storage storage $) {
        assembly {
            $.slot := ERC4626StorageLocation
        }
    }

    /**
     * @dev Initializes share token metadata and the underlying asset.
     * Share `decimals` become asset decimals plus {_decimalsOffset}.
     */
    function __ERC4626_init(IERC20 asset_, string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init(name_, symbol_);
        __ERC4626_init_unchained(asset_);
    }

    function __ERC4626_init_unchained(IERC20 asset_) internal onlyInitializing {
        ERC4626Storage storage $ = _getERC4626Storage();
        (bool ok, uint8 assetDecimals) = _tryGetAssetDecimals(asset_);
        $.underlyingDecimals = ok ? assetDecimals : 18;
        $.asset = asset_;
        $.reentrancyStatus = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        ERC4626Storage storage $ = _getERC4626Storage();
        if ($.reentrancyStatus == _ENTERED) {
            revert ERC4626ReentrantCall();
        }
        $.reentrancyStatus = _ENTERED;
        _;
        $.reentrancyStatus = _NOT_ENTERED;
    }

    /// @inheritdoc IERC20Metadata
    function decimals() public view virtual override returns (uint8) {
        return _getERC4626Storage().underlyingDecimals + _decimalsOffset();
    }

    /// @inheritdoc IERC4626
    function asset() public view virtual returns (address) {
        return address(_getERC4626Storage().asset);
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view virtual returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return _convertToAssets(balanceOf(owner), Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf(owner);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) public virtual nonReentrant returns (uint256 shares) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }
        shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public virtual nonReentrant returns (uint256 assets) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }
        assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        nonReentrant
        returns (uint256 shares)
    {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }
        shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        nonReentrant
        returns (uint256 assets)
    {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }
        assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /// @dev Extra share decimals used as a virtual supply offset. Default 0.
    function _decimalsOffset() internal view virtual returns (uint8) {
        return 0;
    }

    /// @dev `assets * (supply + 10 ** offset) / (totalAssets + 1)` with `rounding`.
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256) {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    /// @dev `shares * (totalAssets + 1) / (supply + 10 ** offset)` with `rounding`.
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
    }

    /**
     * @dev Pull `assets` from `caller`, mint `shares` to `receiver`, emit {Deposit}.
     * Override to apply fees or alternate accounting. Do not omit the event.
     */
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual {
        IERC20(asset()).safeTransferFrom(caller, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(caller, receiver, assets, shares);
    }

    /**
     * @dev Burn `shares` from `owner`, send `assets` to `receiver`, emit {Withdraw}.
     * Spends allowance when `caller != owner`. Override to apply fees. Do not omit the event.
     */
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        virtual
    {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        _burn(owner, shares);
        IERC20(asset()).safeTransfer(receiver, assets);
        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _tryGetAssetDecimals(IERC20 asset_) private view returns (bool ok, uint8 assetDecimals) {
        (bool success, bytes memory data) = address(asset_).staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));
        if (success && data.length >= 32) {
            uint256 decoded = abi.decode(data, (uint256));
            if (decoded <= type(uint8).max) {
                return (true, uint8(decoded));
            }
        }
        return (false, 0);
    }
}
