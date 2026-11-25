// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC5006
 * @dev Interface of the ERC-5006 Rental NFT standard for ERC-1155.
 * See https://eips.ethereum.org/EIPS/eip-5006
 */
interface IERC5006 {
    struct UserRecord {
        uint256 tokenId;
        address owner;
        uint64 amount;
        address user;
        uint64 expiry;
    }

    event CreateUserRecord(
        uint256 recordId, uint256 tokenId, uint64 amount, address owner, address user, uint64 expiry
    );

    event DeleteUserRecord(uint256 recordId);

    function usableBalanceOf(address account, uint256 tokenId) external view returns (uint256);

    function frozenBalanceOf(address account, uint256 tokenId) external view returns (uint256);

    function userRecordOf(uint256 recordId) external view returns (UserRecord memory);

    function createUserRecord(address owner, address user, uint256 tokenId, uint64 amount, uint64 expiry)
        external
        returns (uint256);

    function deleteUserRecord(uint256 recordId) external;

    error ERC5006Unauthorized(address caller, address owner);
    error ERC5006InvalidUser();
    error ERC5006InvalidAmount();
    error ERC5006ExpiryNotInFuture(uint64 expiry);
    error ERC5006RecordLimitReached(address user, uint256 tokenId);
    error ERC5006InvalidRecord(uint256 recordId);
}
