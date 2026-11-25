// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC5006} from "./IERC5006.sol";

/**
 * @notice ERC-1155 rental user role: `createUserRecord` escrows `amount` on this contract until the
 *         owner or an approved operator deletes the record.
 */
abstract contract ERC5006 is ERC1155, ERC1155Holder, IERC5006 {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 private immutable _recordLimit;

    mapping(uint256 tokenId => mapping(address owner => uint256)) private _frozen;
    mapping(uint256 recordId => UserRecord) private _records;
    mapping(uint256 tokenId => mapping(address user => EnumerableSet.UintSet)) private _userRecordIds;
    uint256 private _nextRecordId;

    constructor(uint256 recordLimit_) {
        _recordLimit = recordLimit_;
    }

    /// @inheritdoc IERC5006
    function createUserRecord(address owner, address user, uint256 tokenId, uint64 amount, uint64 expiry)
        public
        virtual
        returns (uint256)
    {
        if (!_isOwnerOrOperator(owner, msg.sender)) {
            revert ERC5006Unauthorized(msg.sender, owner);
        }
        if (user == address(0)) {
            revert ERC5006InvalidUser();
        }
        if (amount == 0) {
            revert ERC5006InvalidAmount();
        }
        if (expiry <= block.timestamp) {
            revert ERC5006ExpiryNotInFuture(expiry);
        }
        if (_userRecordIds[tokenId][user].length() >= _recordLimit) {
            revert ERC5006RecordLimitReached(user, tokenId);
        }

        _safeTransferFrom(owner, address(this), tokenId, amount, "");

        _frozen[tokenId][owner] += amount;
        uint256 recordId = ++_nextRecordId;
        _records[recordId] = UserRecord(tokenId, owner, amount, user, expiry);
        _userRecordIds[tokenId][user].add(recordId);

        emit CreateUserRecord(recordId, tokenId, amount, owner, user, expiry);
        return recordId;
    }

    /// @inheritdoc IERC5006
    function deleteUserRecord(uint256 recordId) public virtual {
        UserRecord storage record = _records[recordId];
        if (record.owner == address(0)) {
            revert ERC5006InvalidRecord(recordId);
        }
        if (!_isOwnerOrOperator(record.owner, msg.sender)) {
            revert ERC5006Unauthorized(msg.sender, record.owner);
        }

        uint256 tokenId = record.tokenId;
        address owner = record.owner;
        uint64 amount = record.amount;
        address user = record.user;

        _safeTransferFrom(address(this), owner, tokenId, amount, "");

        _frozen[tokenId][owner] -= amount;
        _userRecordIds[tokenId][user].remove(recordId);
        delete _records[recordId];

        emit DeleteUserRecord(recordId);
    }

    /// @inheritdoc IERC5006
    function usableBalanceOf(address account, uint256 tokenId) public view virtual returns (uint256) {
        EnumerableSet.UintSet storage ids = _userRecordIds[tokenId][account];
        uint256 len = ids.length();
        uint256 total;
        for (uint256 i = 0; i < len; ++i) {
            UserRecord storage record = _records[ids.at(i)];
            if (block.timestamp <= record.expiry) {
                total += record.amount;
            }
        }
        return total;
    }

    /// @inheritdoc IERC5006
    function frozenBalanceOf(address account, uint256 tokenId) public view virtual returns (uint256) {
        return _frozen[tokenId][account];
    }

    /// @inheritdoc IERC5006
    function userRecordOf(uint256 recordId) public view virtual returns (UserRecord memory) {
        return _records[recordId];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC1155Holder) returns (bool) {
        return interfaceId == type(IERC5006).interfaceId || ERC1155.supportsInterface(interfaceId)
            || ERC1155Holder.supportsInterface(interfaceId);
    }

    function _isOwnerOrOperator(address owner, address caller) private view returns (bool) {
        return caller == owner || isApprovedForAll(owner, caller);
    }
}
