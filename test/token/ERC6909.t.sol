// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC6909} from "../../src/token/ERC6909/ERC6909.sol";
import {ERC6909Upgradeable} from "../../src/token/ERC6909/ERC6909Upgradeable.sol";
import {IERC6909} from "../../src/token/ERC6909/IERC6909.sol";
import {StorageSlot7201} from "../../src/utils/StorageSlot7201.sol";

contract ERC6909Harness is ERC6909 {
    function mint(address receiver, uint256 id, uint256 amount) external {
        _mint(receiver, id, amount);
    }

    function burn(address owner, uint256 id, uint256 amount) external {
        _burn(owner, id, amount);
    }
}

contract ERC6909UpgradeableHarness is ERC6909Upgradeable {
    function initialize() external initializer {
        __ERC6909_init();
    }

    function mint(address receiver, uint256 id, uint256 amount) external {
        _mint(receiver, id, amount);
    }

    function burn(address owner, uint256 id, uint256 amount) external {
        _burn(owner, id, amount);
    }
}

contract ERC6909Test is Test {
    ERC6909Harness internal token;

    ERC6909Harness internal proxyToken;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint256 internal constant ID_A = 1;
    uint256 internal constant ID_B = 2;

    function setUp() public {
        token = new ERC6909Harness();

        ERC6909UpgradeableHarness impl = new ERC6909UpgradeableHarness();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeCall(ERC6909UpgradeableHarness.initialize, ()));
        proxyToken = ERC6909Harness(address(proxy));
    }

    function _mintBoth(address to, uint256 id, uint256 amount) internal {
        token.mint(to, id, amount);
        proxyToken.mint(to, id, amount);
    }

    function test_transfer_movesOneId_emitsCaller() public {
        _mintBoth(alice, ID_A, 100);
        vm.prank(alice);
        vm.expectEmit(true, true, true, true, address(token));
        emit IERC6909.Transfer(alice, alice, bob, ID_A, 40);
        assertTrue(token.transfer(bob, ID_A, 40));
        assertEq(token.balanceOf(alice, ID_A), 60);
        assertEq(token.balanceOf(bob, ID_A), 40);

        vm.prank(alice);
        assertTrue(proxyToken.transfer(bob, ID_A, 40));
        assertEq(proxyToken.balanceOf(alice, ID_A), 60);
        assertEq(proxyToken.balanceOf(bob, ID_A), 40);
    }

    function test_transfer_insufficientBalance_reverts() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC6909.ERC6909InsufficientBalance.selector, alice, ID_A, 0, 1));
        token.transfer(bob, ID_A, 1);
    }

    function test_transfer_zeroAmount_succeeds() public {
        vm.prank(alice);
        assertTrue(token.transfer(bob, ID_A, 0));
    }

    function test_transfer_toZero_burns() public {
        _mintBoth(alice, ID_A, 50);
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit IERC6909.Transfer(alice, alice, address(0), ID_A, 50);
        assertTrue(token.transfer(address(0), ID_A, 50));
        assertEq(token.balanceOf(alice, ID_A), 0);
    }

    function test_transferFrom_bySender_allowanceUnchanged() public {
        _mintBoth(alice, ID_A, 100);
        vm.prank(alice);
        token.approve(carol, ID_A, 50);
        vm.prank(alice);
        assertTrue(token.transferFrom(alice, bob, ID_A, 30));
        assertEq(token.allowance(alice, carol, ID_A), 50);
    }

    function test_transferFrom_byOperator_noAllowanceChange_secondId() public {
        _mintBoth(alice, ID_A, 100);
        _mintBoth(alice, ID_B, 200);
        vm.prank(alice);
        token.setOperator(carol, true);
        vm.prank(carol);
        assertTrue(token.transferFrom(alice, bob, ID_A, 10));
        vm.prank(carol);
        assertTrue(token.transferFrom(alice, bob, ID_B, 20));
        assertEq(token.allowance(alice, carol, ID_A), 0);
        assertEq(token.balanceOf(bob, ID_B), 20);
    }

    function test_transferFrom_bySpender_decreasesAllowance() public {
        _mintBoth(alice, ID_A, 100);
        vm.prank(alice);
        token.approve(carol, ID_A, 50);
        vm.prank(carol);
        assertTrue(token.transferFrom(alice, bob, ID_A, 30));
        assertEq(token.allowance(alice, carol, ID_A), 20);
    }

    function test_transferFrom_insufficientAllowance_reverts() public {
        _mintBoth(alice, ID_A, 100);
        vm.prank(alice);
        token.approve(carol, ID_A, 10);
        vm.prank(carol);
        vm.expectRevert(
            abi.encodeWithSelector(ERC6909.ERC6909InsufficientAllowance.selector, alice, carol, ID_A, 10, 20)
        );
        token.transferFrom(alice, bob, ID_A, 20);
    }

    function test_transferFrom_maxAllowance_unchanged() public {
        _mintBoth(alice, ID_A, 100);
        vm.prank(alice);
        token.approve(carol, ID_A, type(uint256).max);
        vm.prank(carol);
        assertTrue(token.transferFrom(alice, bob, ID_A, 30));
        assertEq(token.allowance(alice, carol, ID_A), type(uint256).max);
    }

    function test_setOperator_grant_repeat_revoke() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit IERC6909.OperatorSet(alice, carol, true);
        assertTrue(token.setOperator(carol, true));
        assertTrue(token.isOperator(alice, carol));

        vm.prank(alice);
        assertTrue(token.setOperator(carol, true));

        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit IERC6909.OperatorSet(alice, carol, false);
        assertTrue(token.setOperator(carol, false));
        assertFalse(token.isOperator(alice, carol));
    }

    function test_approve_overwrites_emits() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit IERC6909.Approval(alice, carol, ID_A, 100);
        assertTrue(token.approve(carol, ID_A, 100));
        assertEq(token.allowance(alice, carol, ID_A), 100);

        vm.prank(alice);
        assertTrue(token.approve(carol, ID_A, 50));
        assertEq(token.allowance(alice, carol, ID_A), 50);
    }

    function test_idIsolation() public {
        _mintBoth(alice, ID_A, 100);
        _mintBoth(alice, ID_B, 200);
        vm.prank(alice);
        token.approve(carol, ID_A, 80);
        vm.prank(alice);
        token.transfer(bob, ID_A, 40);
        assertEq(token.balanceOf(alice, ID_A), 60);
        assertEq(token.balanceOf(alice, ID_B), 200);
        assertEq(token.allowance(alice, carol, ID_A), 80);
        assertEq(token.allowance(alice, carol, ID_B), 0);
    }

    function test_supportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC6909).interfaceId));
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertFalse(token.supportsInterface(bytes4(0xdeadbeef)));
    }

    function test_interfaceId() public pure {
        assertEq(type(IERC6909).interfaceId, bytes4(0x0f632fb3));
    }

    function test_upgradeable_storageSlot() public pure {
        bytes32 expected = StorageSlot7201.erc7201Slot("curatedcontracts.storage.ERC6909");
        assertEq(expected, bytes32(uint256(0x5e2ae5780a3caf81f5c0593653ee1c986e9afa25e8c0d45eeafdd4a545618900)));
    }

    function test_upgradeable_cannotReinitialize() public {
        ERC6909UpgradeableHarness impl = new ERC6909UpgradeableHarness();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeCall(ERC6909UpgradeableHarness.initialize, ()));
        vm.expectRevert();
        ERC6909UpgradeableHarness(address(proxy)).initialize();
    }

    function testFuzz_balanceConservation(uint256 mintAlice, uint256 mintBob, uint256 xfer, uint256 xferFrom) public {
        mintAlice = bound(mintAlice, 0, type(uint128).max);
        mintBob = bound(mintBob, 0, type(uint128).max);
        uint256 total = mintAlice + mintBob;
        if (total == 0) return;
        xfer = bound(xfer, 0, mintAlice);
        xferFrom = bound(xferFrom, 0, mintBob);

        token.mint(alice, ID_A, mintAlice);
        token.mint(bob, ID_A, mintBob);
        uint256 sumBefore = token.balanceOf(alice, ID_A) + token.balanceOf(bob, ID_A);

        if (xfer > 0) {
            vm.prank(alice);
            token.transfer(bob, ID_A, xfer);
        }
        if (xferFrom > 0) {
            vm.prank(bob);
            token.approve(carol, ID_A, xferFrom);
            vm.prank(bob);
            token.transferFrom(bob, alice, ID_A, xferFrom);
        }

        uint256 sumAfter = token.balanceOf(alice, ID_A) + token.balanceOf(bob, ID_A);
        assertEq(sumAfter, sumBefore);
    }
}
