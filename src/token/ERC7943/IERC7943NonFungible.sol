// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IERC7943NonFungible
 * @dev Interface for ERC-7943 non-fungible (ERC-721 shaped) real-world asset tokens.
 *
 * See https://eips.ethereum.org/EIPS/eip-7943
 */
interface IERC7943NonFungible is IERC165 {
    /**
     * @dev Emitted when a token is seized and transferred by an enforcer.
     * @param from The prior owner.
     * @param to The new owner.
     * @param tokenId The token identifier.
     */
    event ForcedTransfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when a token's frozen status changes.
     * @param account The account referenced in the freeze update.
     * @param tokenId The token identifier.
     * @param frozenStatus True if the token is frozen.
     */
    event Frozen(address indexed account, uint256 indexed tokenId, bool indexed frozenStatus);

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
     * @param tokenId The token identifier.
     */
    error ERC7943CannotTransfer(address from, address to, uint256 tokenId);

    /**
     * @dev The token is frozen and cannot be transferred.
     * @param account The token holder.
     * @param tokenId The frozen token identifier.
     */
    error ERC7943InsufficientUnfrozenBalance(address account, uint256 tokenId);

    /**
     * @dev Seizes `tokenId` from `from` and sends it to `to` (enforcer only).
     * @param from The current owner.
     * @param to The recipient.
     * @param tokenId The token identifier.
     * @return result True on success.
     */
    function forcedTransfer(address from, address to, uint256 tokenId) external returns (bool result);

    /**
     * @dev Sets the frozen status of `tokenId` for `account` (enforcer only).
     * @param account The account referenced in the update.
     * @param tokenId The token identifier.
     * @param frozenStatus The new frozen status.
     * @return result True on success.
     */
    function setFrozenTokens(address account, uint256 tokenId, bool frozenStatus) external returns (bool result);

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
     * @dev Returns whether `tokenId` is frozen for `account`.
     * @param account The account to query.
     * @param tokenId The token identifier.
     * @return frozenStatus True if frozen.
     */
    function getFrozenTokens(address account, uint256 tokenId) external view returns (bool frozenStatus);

    /**
     * @dev Returns whether transferring `tokenId` from `from` to `to` is allowed.
     * @param from The sender.
     * @param to The recipient.
     * @param tokenId The token identifier.
     * @return allowed True if the transfer is permitted.
     */
    function canTransfer(address from, address to, uint256 tokenId) external view returns (bool allowed);
}
