// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IERC7943MultiToken
 * @dev Interface for ERC-7943 multi-token (ERC-1155 shaped) real-world asset tokens.
 *
 * See https://eips.ethereum.org/EIPS/eip-7943
 */
interface IERC7943MultiToken is IERC165 {
    /**
     * @dev Emitted when tokens are seized and transferred by an enforcer.
     * @param from The address from which tokens were taken.
     * @param to The recipient.
     * @param tokenId The token type identifier.
     * @param amount The amount seized.
     */
    event ForcedTransfer(address indexed from, address indexed to, uint256 indexed tokenId, uint256 amount);

    /**
     * @dev Emitted when the frozen amount of `tokenId` for `account` changes.
     * @param account The account whose freeze was updated.
     * @param tokenId The token type identifier.
     * @param amount The frozen amount after the update.
     */
    event Frozen(address indexed account, uint256 indexed tokenId, uint256 amount);

    /**
     * @dev The account is not allowed to send tokens.
     * @param account The blocked sender.
     */
    error ERC7943CannotSend(address account);

    /**
     * @dev The account is not allowed to receive tokens.
     * @param account The blocked recipient.
     */
    error ERC7943CannotReceive(address account);

    /**
     * @dev The transfer is blocked by compliance rules.
     * @param from The sender.
     * @param to The recipient.
     * @param tokenId The token type identifier.
     * @param amount The transfer amount.
     */
    error ERC7943CannotTransfer(address from, address to, uint256 tokenId, uint256 amount);

    /**
     * @dev The transfer amount exceeds the unfrozen balance.
     * @param account The token holder.
     * @param tokenId The token type identifier.
     * @param amount The attempted transfer amount.
     * @param unfrozen The unfrozen balance available.
     */
    error ERC7943InsufficientUnfrozenBalance(address account, uint256 tokenId, uint256 amount, uint256 unfrozen);

    /**
     * @dev Seizes `amount` of `tokenId` from `from` and sends to `to` (enforcer only).
     * @param from The address to seize from.
     * @param to The recipient.
     * @param tokenId The token type identifier.
     * @param amount The amount to seize.
     * @return result True on success.
     */
    function forcedTransfer(address from, address to, uint256 tokenId, uint256 amount) external returns (bool result);

    /**
     * @dev Sets the frozen amount of `tokenId` for `account` (enforcer only).
     * @param account The account to update.
     * @param tokenId The token type identifier.
     * @param amount The new frozen amount (may exceed balance).
     * @return result True on success.
     */
    function setFrozenTokens(address account, uint256 tokenId, uint256 amount) external returns (bool result);

    /**
     * @dev Returns whether `account` may send tokens.
     * @param account The account to check.
     * @return allowed True if sending is allowed.
     */
    function canSend(address account) external view returns (bool allowed);

    /**
     * @dev Returns whether `account` may receive tokens.
     * @param account The account to check.
     * @return allowed True if receiving is allowed.
     */
    function canReceive(address account) external view returns (bool allowed);

    /**
     * @dev Returns the frozen amount of `tokenId` for `account`.
     * @param account The account to query.
     * @param tokenId The token type identifier.
     * @return amount The frozen amount (may exceed balance).
     */
    function getFrozenTokens(address account, uint256 tokenId) external view returns (uint256 amount);

    /**
     * @dev Returns whether a transfer of `amount` of `tokenId` from `from` to `to` is allowed.
     * @param from The sender.
     * @param to The recipient.
     * @param tokenId The token type identifier.
     * @param amount The transfer amount.
     * @return allowed True if the transfer is permitted.
     */
    function canTransfer(address from, address to, uint256 tokenId, uint256 amount) external view returns (bool allowed);
}
