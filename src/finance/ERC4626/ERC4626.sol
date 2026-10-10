// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC4626} from "./IERC4626.sol";

/**
 * @title ERC4626
 * @dev Abstract ERC-20 share token implementing the ERC-4626 tokenized vault.
 *
 * Conversion uses a virtual offset (`10 ** _decimalsOffset()` extra shares and
 * `+ 1` extra asset) so an empty vault cannot be inflated by a first-depositor
 * donation. Deposit and mint round shares down; withdraw and redeem round
 * shares or assets in the vault's favor.
 *
 * SECURITY HARDENING (v0.6.1 internal audit):
 * - Reject `address(0)` as the underlying asset.
 * - Revert when a non-zero deposit/withdraw would mint or burn zero shares, and
 *   when a non-zero mint/redeem would move zero assets (Solmate-style dust
 *   protection; prevents silent donation of assets or shares).
 * - `{_deposit}` measures the asset balance delta and reverts on shortfall so
 *   fee-on-transfer tokens cannot insolvent the vault.
 * - ReentrancyGuard on all mutative entry points. Transfer-then-mint matches
 *   the ERC-777 `tokensToSend` ordering used by OpenZeppelin.
 * - `{maxWithdraw}` is derived from `{maxRedeem}` so a subclass cap on redeem
 *   cannot be bypassed via withdraw.
 *
 * ERC-2612 permit is left to subclasses. Fee-on-transfer and rebasing assets
 * remain unsupported (they now revert rather than desynchronize balances).
 * Prefer `_decimalsOffset() >= 3` and a non-trivial seed deposit on empty vaults.
 *
 * Subclasses set ERC-20 name/symbol via {ERC20} and may override
 * {_decimalsOffset}, {totalAssets}, {_deposit}, and {_withdraw}.
 */
abstract contract ERC4626 is ERC20, ReentrancyGuard, IERC4626 {
    using Math for uint256;
    using SafeERC20 for IERC20;

    IERC20 private immutable _asset;
    uint8 private immutable _underlyingDecimals;

    /// @dev Deposit exceeds {maxDeposit} for `receiver`.
    error ERC4626ExceededMaxDeposit(address receiver, uint256 assets, uint256 maxAssets);

    /// @dev Mint exceeds {maxMint} for `receiver`.
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 maxShares);

    /// @dev Withdraw exceeds {maxWithdraw} for `owner`.
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 maxAssets);

    /// @dev Redeem exceeds {maxRedeem} for `owner`.
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 maxShares);

    /// @dev Underlying asset is the zero address.
    error ERC4626InvalidAsset(address asset);

    /// @dev Non-zero assets would mint or burn zero shares.
    error ERC4626ZeroShares();

    /// @dev Non-zero shares would deposit or withdraw zero assets.
    error ERC4626ZeroAssets();

    /// @dev Asset transfer credited `received` instead of the required `expected`.
    error ERC4626AssetTransferMismatch(uint256 expected, uint256 received);

    /**
     * @dev Sets the underlying asset. Share `decimals` become asset decimals plus {_decimalsOffset}.
     * If `asset_` has no `decimals()`, 18 is assumed.
     */
    constructor(IERC20 asset_) {
        if (address(asset_) == address(0)) {
            revert ERC4626InvalidAsset(address(0));
        }
        (bool ok, uint8 assetDecimals) = _tryGetAssetDecimals(asset_);
        _underlyingDecimals = ok ? assetDecimals : 18;
        _asset = asset_;
    }

    /// @inheritdoc IERC20Metadata
    function decimals() public view virtual override returns (uint8) {
        return _underlyingDecimals + _decimalsOffset();
    }

    /// @inheritdoc IERC4626
    function asset() public view virtual returns (address) {
        return address(_asset);
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view virtual returns (uint256) {
        return _asset.balanceOf(address(this));
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
        return _convertToAssets(maxRedeem(owner), Math.Rounding.Floor);
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
        if (assets != 0 && shares == 0) {
            revert ERC4626ZeroShares();
        }
        _deposit(_msgSender(), receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public virtual nonReentrant returns (uint256 assets) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }
        assets = previewMint(shares);
        if (shares != 0 && assets == 0) {
            revert ERC4626ZeroAssets();
        }
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
        if (assets != 0 && shares == 0) {
            revert ERC4626ZeroShares();
        }
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
        if (shares != 0 && assets == 0) {
            revert ERC4626ZeroAssets();
        }
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
        IERC20 token = IERC20(asset());
        uint256 balanceBefore = token.balanceOf(address(this));
        // ERC-777 `tokensToSend` can reenter before the transfer. Pull first so
        // a reentrant call observes no new shares and no credited assets yet.
        token.safeTransferFrom(caller, address(this), assets);
        uint256 received = token.balanceOf(address(this)) - balanceBefore;
        if (received != assets) {
            revert ERC4626AssetTransferMismatch(assets, received);
        }
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
