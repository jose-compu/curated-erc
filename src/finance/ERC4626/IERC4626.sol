// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IERC4626
 * @dev Interface of the ERC-4626 Tokenized Vault Standard.
 * See https://eips.ethereum.org/EIPS/eip-4626
 */
interface IERC4626 is IERC20 {
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    /// @dev Underlying ERC-20 asset managed by the vault. Must not revert.
    function asset() external view returns (address assetTokenAddress);

    /// @dev Total underlying assets held or managed by the vault, inclusive of fees. Must not revert.
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /// @dev Ideal exchange of `assets` into shares, excluding fees and slippage. Must not revert.
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /// @dev Ideal exchange of `shares` into assets, excluding fees and slippage. Must not revert.
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /// @dev Maximum assets `receiver` may deposit. `type(uint256).max` if unlimited. Must not revert.
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /// @dev Shares minted by a `deposit` of `assets` in this block, inclusive of fees. Must not revert.
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /// @dev Deposit `assets` and mint shares to `receiver`. Emits {Deposit}.
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /// @dev Maximum shares `receiver` may mint. `type(uint256).max` if unlimited. Must not revert.
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /// @dev Assets required to mint `shares` in this block, inclusive of fees. Must not revert.
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /// @dev Mint exactly `shares` to `receiver` by depositing assets. Emits {Deposit}.
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /// @dev Maximum assets withdrawable from `owner`. Must not revert.
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /// @dev Shares burned by a `withdraw` of `assets` in this block, inclusive of fees. Must not revert.
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /// @dev Burn shares from `owner` and send exactly `assets` to `receiver`. Emits {Withdraw}.
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /// @dev Maximum shares redeemable from `owner`. Must not revert.
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /// @dev Assets sent by a `redeem` of `shares` in this block, inclusive of fees. Must not revert.
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /// @dev Burn exactly `shares` from `owner` and send assets to `receiver`. Emits {Withdraw}.
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}
