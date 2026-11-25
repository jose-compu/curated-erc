// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC5006} from "../../src/token/ERC5006/ERC5006.sol";
import {ERC5006Upgradeable} from "../../src/token/ERC5006/ERC5006Upgradeable.sol";
import {IERC5006} from "../../src/token/ERC5006/IERC5006.sol";
import {StorageSlot7201} from "../../src/utils/StorageSlot7201.sol";

bytes4 constant IF_ERC5006 = 0xc26d96cc;

contract MockERC5006 is ERC5006 {
    constructor(uint256 limit) ERC1155("ipfs://test") ERC5006(limit) {}

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }

    function burn(address from, uint256 id, uint256 amount) external {
        _burn(from, id, amount);
    }
}

contract ERC5006UpgradeableHarness is ERC5006Upgradeable {
    function initialize(uint256 limit) external initializer {
        __ERC1155_init("ipfs://test");
        __ERC5006_init(limit);
    }

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }

    function burn(address from, uint256 id, uint256 amount) external {
        _burn(from, id, amount);
    }
}

contract ERC5006Test is Test {
    MockERC5006 internal token;
    ERC5006UpgradeableHarness internal proxyImpl;
    IERC5006 internal proxy;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");
    address internal operator = makeAddr("operator");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant TOKEN_ID = 1;
    uint256 internal constant TOKEN_ID_2 = 2;
    uint256 internal constant MINTED = 100;

    function setUp() public {
        vm.warp(1000);
        token = new MockERC5006(16);
        token.mint(owner, TOKEN_ID, MINTED);
        token.mint(owner, TOKEN_ID_2, MINTED);

        proxyImpl = new ERC5006UpgradeableHarness();
        ERC1967Proxy p =
            new ERC1967Proxy(address(proxyImpl), abi.encodeCall(ERC5006UpgradeableHarness.initialize, (16)));
        proxy = IERC5006(address(p));
        ERC5006UpgradeableHarness(address(proxy)).mint(owner, TOKEN_ID, MINTED);
    }

    function test_supportsInterface() public view {
        assertEq(type(IERC5006).interfaceId, IF_ERC5006);
        assertTrue(token.supportsInterface(IF_ERC5006));
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155Receiver).interfaceId));
        assertFalse(token.supportsInterface(0xffffffff));
    }

    function test_createUserRecord_byOwner() public {
        uint64 amount = 10;
        uint64 expiry = 2000;

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IERC1155.TransferSingle(owner, owner, address(token), TOKEN_ID, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC5006.CreateUserRecord(1, TOKEN_ID, amount, owner, user, expiry);
        uint256 recordId = token.createUserRecord(owner, user, TOKEN_ID, amount, expiry);
        vm.stopPrank();

        assertEq(recordId, 1);
        assertEq(token.balanceOf(owner, TOKEN_ID), MINTED - amount);
        assertEq(token.balanceOf(address(token), TOKEN_ID), amount);
        assertEq(token.frozenBalanceOf(owner, TOKEN_ID), amount);
        assertEq(token.usableBalanceOf(user, TOKEN_ID), amount);

        IERC5006.UserRecord memory rec = token.userRecordOf(1);
        assertEq(rec.tokenId, TOKEN_ID);
        assertEq(rec.owner, owner);
        assertEq(rec.amount, amount);
        assertEq(rec.user, user);
        assertEq(rec.expiry, expiry);
    }

    function test_createUserRecord_byOperator() public {
        vm.prank(owner);
        token.setApprovalForAll(operator, true);

        vm.prank(operator);
        token.createUserRecord(owner, user, TOKEN_ID, 5, 2000);

        assertEq(token.frozenBalanceOf(owner, TOKEN_ID), 5);
        assertEq(token.usableBalanceOf(user, TOKEN_ID), 5);
    }

    function test_createUserRecord_revert_unauthorized() public {
        uint256 balBefore = token.balanceOf(owner, TOKEN_ID);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IERC5006.ERC5006Unauthorized.selector, stranger, owner));
        token.createUserRecord(owner, user, TOKEN_ID, 1, 2000);
        assertEq(token.balanceOf(owner, TOKEN_ID), balBefore);
    }

    function test_createUserRecord_revert_zeroUser() public {
        vm.prank(owner);
        vm.expectRevert(IERC5006.ERC5006InvalidUser.selector);
        token.createUserRecord(owner, address(0), TOKEN_ID, 1, 2000);
    }

    function test_createUserRecord_revert_zeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(IERC5006.ERC5006InvalidAmount.selector);
        token.createUserRecord(owner, user, TOKEN_ID, 0, 2000);
    }

    function test_createUserRecord_revert_expiryNotAfterTimestamp() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC5006.ERC5006ExpiryNotInFuture.selector, uint64(block.timestamp)));
        token.createUserRecord(owner, user, TOKEN_ID, 1, uint64(block.timestamp));

        vm.expectRevert(abi.encodeWithSelector(IERC5006.ERC5006ExpiryNotInFuture.selector, uint64(500)));
        token.createUserRecord(owner, user, TOKEN_ID, 1, 500);
        vm.stopPrank();
    }

    function test_createUserRecord_revert_insufficientBalance() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector, owner, MINTED, MINTED + 1, TOKEN_ID
            )
        );
        token.createUserRecord(owner, user, TOKEN_ID, uint64(MINTED + 1), 2000);

        IERC5006.UserRecord memory empty = token.userRecordOf(1);
        assertEq(empty.owner, address(0));

        vm.prank(owner);
        uint256 id = token.createUserRecord(owner, user, TOKEN_ID, 1, 2000);
        assertEq(id, 1);
    }

    function test_createUserRecord_revert_recordLimit() public {
        MockERC5006 limited = new MockERC5006(2);
        limited.mint(owner, TOKEN_ID, MINTED);

        vm.startPrank(owner);
        limited.createUserRecord(owner, user, TOKEN_ID, 1, 1500);
        limited.createUserRecord(owner, user, TOKEN_ID, 1, 2000);
        vm.expectRevert(abi.encodeWithSelector(IERC5006.ERC5006RecordLimitReached.selector, user, TOKEN_ID));
        limited.createUserRecord(owner, user, TOKEN_ID, 1, 2500);
        vm.stopPrank();

        vm.warp(2501);
        assertEq(limited.usableBalanceOf(user, TOKEN_ID), 0);
        assertEq(limited.frozenBalanceOf(owner, TOKEN_ID), 2);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC5006.ERC5006RecordLimitReached.selector, user, TOKEN_ID));
        limited.createUserRecord(owner, user, TOKEN_ID, 1, 3000);

        vm.prank(owner);
        limited.deleteUserRecord(1);

        vm.prank(owner);
        limited.createUserRecord(owner, user, TOKEN_ID, 1, 3000);
    }

    function test_usableBalanceOf_sumsUnexpiredRecords() public {
        vm.startPrank(owner);
        token.createUserRecord(owner, user, TOKEN_ID, 3, 2000);
        token.createUserRecord(owner, user, TOKEN_ID, 7, 3000);
        vm.stopPrank();

        assertEq(token.usableBalanceOf(user, TOKEN_ID), 10);
        assertEq(token.usableBalanceOf(user, TOKEN_ID_2), 0);
    }

    function test_usableBalanceOf_exactExpiryIncluded() public {
        uint64 expiry = 2000;
        vm.prank(owner);
        token.createUserRecord(owner, user, TOKEN_ID, 5, expiry);

        vm.warp(expiry);
        assertEq(token.usableBalanceOf(user, TOKEN_ID), 5);
    }

    function test_usableBalanceOf_afterExpiryExcluded() public {
        uint64 expiry = 2000;
        vm.prank(owner);
        token.createUserRecord(owner, user, TOKEN_ID, 5, expiry);

        vm.warp(expiry + 1);
        assertEq(token.usableBalanceOf(user, TOKEN_ID), 0);
        assertEq(token.userRecordOf(1).amount, 5);
    }

    function test_frozenBalanceOf_persistsAfterExpiry() public {
        vm.prank(owner);
        token.createUserRecord(owner, user, TOKEN_ID, 5, 2000);

        vm.warp(2001);
        assertEq(token.frozenBalanceOf(owner, TOKEN_ID), 5);
    }

    function test_deleteUserRecord_byOwner() public {
        vm.prank(owner);
        token.createUserRecord(owner, user, TOKEN_ID, 10, 2000);

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IERC1155.TransferSingle(owner, address(token), owner, TOKEN_ID, 10);
        vm.expectEmit(true, true, true, true);
        emit IERC5006.DeleteUserRecord(1);
        token.deleteUserRecord(1);
        vm.stopPrank();

        assertEq(token.balanceOf(owner, TOKEN_ID), MINTED);
        assertEq(token.frozenBalanceOf(owner, TOKEN_ID), 0);
        assertEq(token.usableBalanceOf(user, TOKEN_ID), 0);
        IERC5006.UserRecord memory rec = token.userRecordOf(1);
        assertEq(rec.owner, address(0));
    }

    function test_deleteUserRecord_byOperator() public {
        vm.prank(owner);
        token.createUserRecord(owner, user, TOKEN_ID, 4, 2000);
        vm.prank(owner);
        token.setApprovalForAll(operator, true);

        vm.prank(operator);
        token.deleteUserRecord(1);
        assertEq(token.frozenBalanceOf(owner, TOKEN_ID), 0);
    }

    function test_deleteUserRecord_revert_user() public {
        vm.prank(owner);
        token.createUserRecord(owner, user, TOKEN_ID, 4, 2000);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IERC5006.ERC5006Unauthorized.selector, user, owner));
        token.deleteUserRecord(1);
        assertEq(token.frozenBalanceOf(owner, TOKEN_ID), 4);
    }

    function test_deleteUserRecord_revert_unknown() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC5006.ERC5006InvalidRecord.selector, 0));
        token.deleteUserRecord(0);

        vm.expectRevert(abi.encodeWithSelector(IERC5006.ERC5006InvalidRecord.selector, 99));
        token.deleteUserRecord(99);
    }

    function test_deleteUserRecord_afterExpiry() public {
        vm.prank(owner);
        token.createUserRecord(owner, user, TOKEN_ID, 6, 1500);
        vm.warp(2000);

        vm.prank(owner);
        token.deleteUserRecord(1);

        assertEq(token.balanceOf(owner, TOKEN_ID), MINTED);
        assertEq(token.frozenBalanceOf(owner, TOKEN_ID), 0);
    }

    function test_recordIds_startAtOne_andIncrease() public {
        vm.startPrank(owner);
        assertEq(token.createUserRecord(owner, user, TOKEN_ID, 1, 2000), 1);
        assertEq(token.createUserRecord(owner, user, TOKEN_ID, 1, 3000), 2);
        vm.stopPrank();
    }

    function test_transferRemainder_keepsRecord() public {
        vm.prank(owner);
        token.createUserRecord(owner, user, TOKEN_ID, 20, 2000);

        vm.prank(owner);
        token.safeTransferFrom(owner, stranger, TOKEN_ID, 30, "");

        assertEq(token.userRecordOf(1).amount, 20);
        assertEq(token.frozenBalanceOf(owner, TOKEN_ID), 20);
        assertEq(token.usableBalanceOf(user, TOKEN_ID), 20);
    }

    function test_burnRemainder_keepsEscrow() public {
        vm.prank(owner);
        token.createUserRecord(owner, user, TOKEN_ID, 20, 2000);

        vm.prank(owner);
        token.burn(owner, TOKEN_ID, 30);

        assertEq(token.userRecordOf(1).amount, 20);
        assertEq(token.frozenBalanceOf(owner, TOKEN_ID), 20);
    }

    function testFuzz_usableUntilExpiry(uint64 amount, uint64 expiry) public {
        amount = uint64(bound(amount, 1, MINTED));
        expiry = uint64(bound(expiry, block.timestamp + 1, type(uint64).max - 1));

        vm.prank(owner);
        token.createUserRecord(owner, user, TOKEN_ID, amount, expiry);

        vm.warp(expiry);
        assertEq(token.usableBalanceOf(user, TOKEN_ID), amount);
        assertEq(token.frozenBalanceOf(owner, TOKEN_ID), amount);

        vm.warp(expiry + 1);
        assertEq(token.usableBalanceOf(user, TOKEN_ID), 0);
    }

    function testFuzz_operatorCreateOwnerDelete(uint64 amount, uint64 expiry) public {
        amount = uint64(bound(amount, 1, MINTED));
        expiry = uint64(bound(expiry, block.timestamp + 1, type(uint64).max));

        uint256 ownerBalBefore = token.balanceOf(owner, TOKEN_ID);
        uint256 contractBalBefore = token.balanceOf(address(token), TOKEN_ID);

        vm.prank(owner);
        token.setApprovalForAll(operator, true);

        vm.prank(operator);
        uint256 recordId = token.createUserRecord(owner, user, TOKEN_ID, amount, expiry);

        assertEq(token.balanceOf(owner, TOKEN_ID), ownerBalBefore - amount);
        assertEq(token.frozenBalanceOf(owner, TOKEN_ID), amount);

        vm.prank(owner);
        token.deleteUserRecord(recordId);

        assertEq(token.balanceOf(owner, TOKEN_ID), ownerBalBefore);
        assertEq(token.balanceOf(address(token), TOKEN_ID), contractBalBefore);
        assertEq(token.frozenBalanceOf(owner, TOKEN_ID), 0);
    }

    function test_upgradeable_initializerOnce_and_slot() public {
        assertEq(
            StorageSlot7201.erc7201Slot("curatedcontracts.storage.ERC5006"),
            0x86b648b178dea7c5ed397aa4c7aae2f018d7e9ab49a9b3b40233fffe5cbe0500
        );
        assertTrue(IERC165(address(proxy)).supportsInterface(IF_ERC5006));

        vm.expectRevert();
        ERC5006UpgradeableHarness(address(proxy)).initialize(16);
    }

    function test_proxy_parity_createAndDelete() public {
        uint64 amount = 8;
        uint64 expiry = 2000;

        vm.prank(owner);
        uint256 recordId = proxy.createUserRecord(owner, user, TOKEN_ID, amount, expiry);

        assertEq(proxy.frozenBalanceOf(owner, TOKEN_ID), amount);
        assertEq(proxy.usableBalanceOf(user, TOKEN_ID), amount);

        vm.prank(owner);
        proxy.deleteUserRecord(recordId);

        assertEq(proxy.frozenBalanceOf(owner, TOKEN_ID), 0);
        assertEq(proxy.usableBalanceOf(user, TOKEN_ID), 0);
    }
}
