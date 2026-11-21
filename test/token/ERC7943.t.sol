// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, Vm} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC7943Fungible} from "../../src/token/ERC7943/ERC7943Fungible.sol";
import {ERC7943FungibleUpgradeable} from "../../src/token/ERC7943/ERC7943FungibleUpgradeable.sol";
import {ERC7943NonFungible} from "../../src/token/ERC7943/ERC7943NonFungible.sol";
import {ERC7943NonFungibleUpgradeable} from "../../src/token/ERC7943/ERC7943NonFungibleUpgradeable.sol";
import {ERC7943MultiToken} from "../../src/token/ERC7943/ERC7943MultiToken.sol";
import {ERC7943MultiTokenUpgradeable} from "../../src/token/ERC7943/ERC7943MultiTokenUpgradeable.sol";
import {IERC7943Fungible} from "../../src/token/ERC7943/IERC7943Fungible.sol";
import {IERC7943NonFungible} from "../../src/token/ERC7943/IERC7943NonFungible.sol";
import {IERC7943MultiToken} from "../../src/token/ERC7943/IERC7943MultiToken.sol";
import {StorageSlot7201} from "../../src/utils/StorageSlot7201.sol";

bytes4 constant IF_FUNGIBLE = 0x3edbb4c4;
bytes4 constant IF_NFT = 0xbf1ef5fe;
bytes4 constant IF_MULTI = 0x41c4fbad;

contract ERC7943NoReceiver {}

contract ERC7943FungibleHarness is ERC7943Fungible {
    mapping(address => bool) internal blockedSend;
    mapping(address => bool) internal blockedReceive;
    bool internal blockCanTransfer;

    constructor(address enforcer) ERC20("URWA", "URWA") ERC7943Fungible(enforcer) {}

    function setBlockedSend(address account, bool blocked) external {
        blockedSend[account] = blocked;
    }

    function setBlockedReceive(address account, bool blocked) external {
        blockedReceive[account] = blocked;
    }

    function setBlockCanTransfer(bool blocked) external {
        blockCanTransfer = blocked;
    }

    function canSend(address account) public view override returns (bool) {
        return !blockedSend[account];
    }

    function canReceive(address account) public view override returns (bool) {
        return !blockedReceive[account];
    }

    function canTransfer(address from, address to, uint256 amount) public view override returns (bool) {
        if (blockCanTransfer) return false;
        return super.canTransfer(from, to, amount);
    }

    function mint(address to, uint256 amount) external onlyRole(ENFORCER_ROLE) {
        _erc7943Mint(to, amount);
    }

    function userBurn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function enforcerBurn(address from, uint256 amount) external onlyRole(ENFORCER_ROLE) {
        _erc7943EnforcerBurn(from, amount);
    }
}

contract ERC7943FungibleUpgradeableHarness is ERC7943FungibleUpgradeable {
    mapping(address => bool) internal blockedSend;
    mapping(address => bool) internal blockedReceive;
    bool internal blockCanTransfer;

    function initialize(address enforcer) external initializer {
        __ERC20_init("URWA", "URWA");
        __ERC7943Fungible_init(enforcer);
    }

    function setBlockedSend(address account, bool blocked) external {
        blockedSend[account] = blocked;
    }

    function setBlockedReceive(address account, bool blocked) external {
        blockedReceive[account] = blocked;
    }

    function setBlockCanTransfer(bool blocked) external {
        blockCanTransfer = blocked;
    }

    function canSend(address account) public view override returns (bool) {
        return !blockedSend[account];
    }

    function canReceive(address account) public view override returns (bool) {
        return !blockedReceive[account];
    }

    function canTransfer(address from, address to, uint256 amount) public view override returns (bool) {
        if (blockCanTransfer) return false;
        return super.canTransfer(from, to, amount);
    }

    function mint(address to, uint256 amount) external onlyRole(ENFORCER_ROLE) {
        _erc7943Mint(to, amount);
    }

    function userBurn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function enforcerBurn(address from, uint256 amount) external onlyRole(ENFORCER_ROLE) {
        _erc7943EnforcerBurn(from, amount);
    }
}

contract ERC7943FungibleNamedUpgradeableHarness is ERC7943FungibleUpgradeable {
    function initialize(address enforcer) external initializer {
        __ERC20_init("RWA", "RWA");
        __ERC7943Fungible_init(enforcer);
    }
}

contract ERC7943NFTReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract ERC7943NonFungibleHarness is ERC7943NonFungible {
    mapping(address => bool) internal blockedSend;
    mapping(address => bool) internal blockedReceive;
    bool internal blockCanTransfer;

    constructor(address enforcer) ERC721("URWA", "URWA") ERC7943NonFungible(enforcer) {}

    function setBlockedSend(address account, bool blocked) external {
        blockedSend[account] = blocked;
    }

    function setBlockedReceive(address account, bool blocked) external {
        blockedReceive[account] = blocked;
    }

    function canSend(address account) public view override returns (bool) {
        return !blockedSend[account];
    }

    function canReceive(address account) public view override returns (bool) {
        return !blockedReceive[account];
    }

    function setBlockCanTransfer(bool blocked) external {
        blockCanTransfer = blocked;
    }

    function canTransfer(address from, address to, uint256 tokenId) public view override returns (bool) {
        if (blockCanTransfer) return false;
        return super.canTransfer(from, to, tokenId);
    }

    function mint(address to, uint256 tokenId) external onlyRole(ENFORCER_ROLE) {
        _erc7943Mint(to, tokenId);
    }

    function userBurn(uint256 tokenId) external {
        _burn(tokenId);
    }

    function enforcerBurn(uint256 tokenId) external onlyRole(ENFORCER_ROLE) {
        _erc7943EnforcerBurn(tokenId);
    }
}

contract ERC7943NonFungibleUpgradeableHarness is ERC7943NonFungibleUpgradeable {
    mapping(address => bool) internal blockedSend;
    mapping(address => bool) internal blockedReceive;
    bool internal blockCanTransfer;

    function initialize(address enforcer) external initializer {
        __ERC721_init("URWA", "URWA");
        __ERC7943NonFungible_init(enforcer);
    }

    function setBlockedSend(address account, bool blocked) external {
        blockedSend[account] = blocked;
    }

    function setBlockedReceive(address account, bool blocked) external {
        blockedReceive[account] = blocked;
    }

    function canSend(address account) public view override returns (bool) {
        return !blockedSend[account];
    }

    function canReceive(address account) public view override returns (bool) {
        return !blockedReceive[account];
    }

    function setBlockCanTransfer(bool blocked) external {
        blockCanTransfer = blocked;
    }

    function canTransfer(address from, address to, uint256 tokenId) public view override returns (bool) {
        if (blockCanTransfer) return false;
        return super.canTransfer(from, to, tokenId);
    }

    function mint(address to, uint256 tokenId) external onlyRole(ENFORCER_ROLE) {
        _erc7943Mint(to, tokenId);
    }

    function userBurn(uint256 tokenId) external {
        _burn(tokenId);
    }

    function enforcerBurn(uint256 tokenId) external onlyRole(ENFORCER_ROLE) {
        _erc7943EnforcerBurn(tokenId);
    }
}

contract ERC7943MultiTokenHarness is ERC7943MultiToken {
    mapping(address => bool) internal blockedSend;
    mapping(address => bool) internal blockedReceive;
    bool internal blockCanTransfer;

    constructor(address enforcer) ERC7943MultiToken(enforcer, "uri") {}

    function setBlockedSend(address account, bool blocked) external {
        blockedSend[account] = blocked;
    }

    function setBlockedReceive(address account, bool blocked) external {
        blockedReceive[account] = blocked;
    }

    function canSend(address account) public view override returns (bool) {
        return !blockedSend[account];
    }

    function canReceive(address account) public view override returns (bool) {
        return !blockedReceive[account];
    }

    function setBlockCanTransfer(bool blocked) external {
        blockCanTransfer = blocked;
    }

    function canTransfer(address from, address to, uint256 tokenId, uint256 amount)
        public
        view
        override
        returns (bool)
    {
        if (blockCanTransfer) return false;
        return super.canTransfer(from, to, tokenId, amount);
    }

    function mint(address to, uint256 tokenId, uint256 amount) external onlyRole(ENFORCER_ROLE) {
        _erc7943Mint(to, tokenId, amount);
    }

    function userBurn(uint256 tokenId, uint256 amount) external {
        _burn(_msgSender(), tokenId, amount);
    }

    function enforcerBurn(address from, uint256 tokenId, uint256 amount) external onlyRole(ENFORCER_ROLE) {
        _erc7943EnforcerBurn(from, tokenId, amount);
    }
}

contract ERC7943MultiTokenUpgradeableHarness is ERC7943MultiTokenUpgradeable {
    mapping(address => bool) internal blockedSend;
    mapping(address => bool) internal blockedReceive;
    bool internal blockCanTransfer;

    function initialize(address enforcer) external initializer {
        __ERC7943MultiToken_init(enforcer, "uri");
    }

    function setBlockedSend(address account, bool blocked) external {
        blockedSend[account] = blocked;
    }

    function setBlockedReceive(address account, bool blocked) external {
        blockedReceive[account] = blocked;
    }

    function canSend(address account) public view override returns (bool) {
        return !blockedSend[account];
    }

    function canReceive(address account) public view override returns (bool) {
        return !blockedReceive[account];
    }

    function setBlockCanTransfer(bool blocked) external {
        blockCanTransfer = blocked;
    }

    function canTransfer(address from, address to, uint256 tokenId, uint256 amount)
        public
        view
        override
        returns (bool)
    {
        if (blockCanTransfer) return false;
        return super.canTransfer(from, to, tokenId, amount);
    }

    function mint(address to, uint256 tokenId, uint256 amount) external onlyRole(ENFORCER_ROLE) {
        _erc7943Mint(to, tokenId, amount);
    }

    function userBurn(uint256 tokenId, uint256 amount) external {
        _burn(_msgSender(), tokenId, amount);
    }

    function enforcerBurn(address from, uint256 tokenId, uint256 amount) external onlyRole(ENFORCER_ROLE) {
        _erc7943EnforcerBurn(from, tokenId, amount);
    }
}

contract ERC7943Test is Test {
    address internal enforcer = makeAddr("enforcer");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    ERC7943FungibleHarness internal fungible;
    ERC7943FungibleUpgradeableHarness internal fungibleProxy;
    ERC7943NonFungibleHarness internal nft;
    ERC7943NonFungibleUpgradeableHarness internal nftProxy;
    ERC7943MultiTokenHarness internal multi;
    ERC7943MultiTokenUpgradeableHarness internal multiProxy;

    uint256 internal constant ID = 42;

    function setUp() public {
        fungible = new ERC7943FungibleHarness(enforcer);
        nft = new ERC7943NonFungibleHarness(enforcer);
        multi = new ERC7943MultiTokenHarness(enforcer);

        ERC7943FungibleUpgradeableHarness fungibleImpl = new ERC7943FungibleUpgradeableHarness();
        fungibleProxy = ERC7943FungibleUpgradeableHarness(
            address(
                new ERC1967Proxy(
                    address(fungibleImpl), abi.encodeCall(ERC7943FungibleUpgradeableHarness.initialize, (enforcer))
                )
            )
        );

        ERC7943NonFungibleUpgradeableHarness nftImpl = new ERC7943NonFungibleUpgradeableHarness();
        nftProxy = ERC7943NonFungibleUpgradeableHarness(
            address(
                new ERC1967Proxy(
                    address(nftImpl), abi.encodeCall(ERC7943NonFungibleUpgradeableHarness.initialize, (enforcer))
                )
            )
        );

        ERC7943MultiTokenUpgradeableHarness multiImpl = new ERC7943MultiTokenUpgradeableHarness();
        multiProxy = ERC7943MultiTokenUpgradeableHarness(
            address(
                new ERC1967Proxy(
                    address(multiImpl), abi.encodeCall(ERC7943MultiTokenUpgradeableHarness.initialize, (enforcer))
                )
            )
        );

        vm.startPrank(enforcer);
        fungible.mint(alice, 1_000);
        fungibleProxy.mint(alice, 1_000);
        nft.mint(alice, ID);
        nftProxy.mint(alice, ID);
        multi.mint(alice, ID, 1_000);
        multiProxy.mint(alice, ID, 1_000);
        vm.stopPrank();
    }

    function test_interfaceIds() public view {
        assertEq(type(IERC7943Fungible).interfaceId, IF_FUNGIBLE);
        assertEq(type(IERC7943NonFungible).interfaceId, IF_NFT);
        assertEq(type(IERC7943MultiToken).interfaceId, IF_MULTI);
        assertTrue(fungible.supportsInterface(IF_FUNGIBLE));
        assertTrue(fungibleProxy.supportsInterface(IF_FUNGIBLE));
        assertTrue(nft.supportsInterface(IF_NFT));
        assertTrue(nftProxy.supportsInterface(IF_NFT));
        assertTrue(multi.supportsInterface(IF_MULTI));
        assertTrue(multiProxy.supportsInterface(IF_MULTI));
    }

    function test_setFrozen_overwrite_and_aboveBalance() public {
        vm.prank(enforcer);
        assertTrue(fungible.setFrozenTokens(alice, 300));
        assertEq(fungible.getFrozenTokens(alice), 300);

        vm.prank(enforcer);
        assertTrue(fungible.setFrozenTokens(alice, 2_000));
        assertEq(fungible.getFrozenTokens(alice), 2_000);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC7943Fungible.ERC7943InsufficientUnfrozenBalance.selector, alice, 100, 0)
        );
        fungible.transfer(bob, 100);

        vm.prank(carol);
        vm.expectRevert();
        fungible.setFrozenTokens(alice, 1);
    }

    function test_unfrozenShortfall_vs_baseInsufficientBalance() public {
        vm.prank(enforcer);
        fungible.setFrozenTokens(alice, 900);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC7943Fungible.ERC7943InsufficientUnfrozenBalance.selector, alice, 200, 100)
        );
        fungible.transfer(bob, 200);

        vm.prank(enforcer);
        fungible.setFrozenTokens(alice, 0);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 1_000, 2_000));
        fungible.transfer(bob, 2_000);
    }

    function test_canSend_canReceive_failures() public {
        fungible.setBlockedSend(alice, true);
        vm.prank(enforcer);
        fungible.setFrozenTokens(alice, 0);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC7943Fungible.ERC7943CannotSend.selector, alice));
        fungible.transfer(bob, 1);

        fungible.setBlockedSend(alice, false);
        fungible.setBlockedReceive(bob, true);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC7943Fungible.ERC7943CannotReceive.selector, bob));
        fungible.transfer(bob, 1);
    }

    function test_canTransfer_trueWhenAmountExceedsBalance() public view {
        assertTrue(fungible.canTransfer(alice, bob, 5_000));
    }

    function test_forcedTransfer_eventOrder_and_freezeReduced() public {
        vm.prank(enforcer);
        fungible.setFrozenTokens(alice, 400);

        vm.prank(enforcer);
        vm.recordLogs();
        fungible.forcedTransfer(alice, bob, 200);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 3);
        assertEq(entries[0].topics[0], keccak256("Frozen(address,uint256)"));
        assertEq(entries[1].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[2].topics[0], keccak256("ForcedTransfer(address,address,uint256)"));

        assertEq(fungible.getFrozenTokens(alice), 200);
        assertEq(fungible.balanceOf(bob), 200);
    }

    function test_forcedTransfer_blockedReceiver_unchanged() public {
        fungible.setBlockedReceive(bob, true);
        uint256 aliceBefore = fungible.balanceOf(alice);

        vm.prank(enforcer);
        vm.expectRevert(abi.encodeWithSelector(IERC7943Fungible.ERC7943CannotReceive.selector, bob));
        fungible.forcedTransfer(alice, bob, 50);

        assertEq(fungible.balanceOf(alice), aliceBefore);
    }

    function test_mint_blockedReceiver_reverts() public {
        fungible.setBlockedReceive(carol, true);
        vm.prank(enforcer);
        vm.expectRevert(abi.encodeWithSelector(IERC7943Fungible.ERC7943CannotReceive.selector, carol));
        fungible.mint(carol, 10);
    }

    function test_enforcerBurn_frozen_emitsFrozenFirst() public {
        vm.prank(enforcer);
        fungible.setFrozenTokens(alice, 800);

        vm.prank(enforcer);
        vm.recordLogs();
        fungible.enforcerBurn(alice, 300);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics[0], keccak256("Frozen(address,uint256)"));
        assertEq(entries[1].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(fungible.getFrozenTokens(alice), 500);
        assertEq(fungible.balanceOf(alice), 700);
    }

    function test_nft_frozen_transfer() public {
        vm.prank(enforcer);
        nft.setFrozenTokens(alice, ID, true);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC7943NonFungible.ERC7943InsufficientUnfrozenBalance.selector, alice, ID)
        );
        nft.transferFrom(alice, bob, ID);
    }

    function test_multi_batch_revertsWhenOneIdOverUnfrozen() public {
        uint256 id2 = 7;
        vm.startPrank(enforcer);
        multi.mint(alice, id2, 100);
        multi.setFrozenTokens(alice, ID, 950);
        vm.stopPrank();

        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = ID;
        ids[1] = id2;
        amounts[0] = 100;
        amounts[1] = 10;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC7943MultiToken.ERC7943InsufficientUnfrozenBalance.selector, alice, ID, 100, 50)
        );
        multi.safeBatchTransferFrom(alice, bob, ids, amounts, "");
    }

    function testFuzz_canTransferMatchesTransferOutcome(uint256 amount) public {
        amount = bound(amount, 0, 1_000);
        vm.assume(amount <= fungible.balanceOf(alice));

        bool allowed = fungible.canTransfer(alice, bob, amount);
        vm.prank(alice);
        if (allowed) {
            fungible.transfer(bob, amount);
        } else {
            vm.expectRevert();
            fungible.transfer(bob, amount);
        }
    }

    function test_upgradeable_initializerOnce_and_slots() public {
        vm.expectRevert();
        fungibleProxy.initialize(enforcer);

        assertEq(
            StorageSlot7201.erc7201Slot("curatedcontracts.storage.ERC7943Fungible"),
            bytes32(uint256(0x34a291192137eb57866d9ec1d5d6de7e99b16f165d8bc907abb999a5e466cd00))
        );
        assertEq(
            StorageSlot7201.erc7201Slot("curatedcontracts.storage.ERC7943NonFungible"),
            bytes32(uint256(0x41313f5e0fdc7e90cc10ebf0269315a123d7856358b6f848912a50642fcc1c00))
        );
        assertEq(
            StorageSlot7201.erc7201Slot("curatedcontracts.storage.ERC7943MultiToken"),
            bytes32(uint256(0x71efb3b4c3e3110e79d9a019d85b0030c87279f16f0f689c5995c94135b93900))
        );
    }

    function test_proxy_parity_freeze_and_forcedTransfer() public {
        vm.prank(enforcer);
        fungibleProxy.setFrozenTokens(alice, 500);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC7943Fungible.ERC7943InsufficientUnfrozenBalance.selector, alice, 600, 500)
        );
        fungibleProxy.transfer(bob, 600);

        vm.prank(enforcer);
        fungibleProxy.forcedTransfer(alice, bob, 100);
        assertEq(fungibleProxy.balanceOf(bob), 100);
    }

    function test_nft_forcedTransfer_withoutApproval() public {
        vm.prank(enforcer);
        nft.setFrozenTokens(alice, ID, true);

        vm.prank(enforcer);
        assertTrue(nft.forcedTransfer(alice, bob, ID));
        assertEq(nft.ownerOf(ID), bob);
        assertFalse(nft.getFrozenTokens(alice, ID));

        vm.prank(enforcer);
        nftProxy.setFrozenTokens(alice, ID, true);
        vm.prank(enforcer);
        assertTrue(nftProxy.forcedTransfer(alice, bob, ID));
        assertEq(nftProxy.ownerOf(ID), bob);
        assertFalse(nftProxy.getFrozenTokens(alice, ID));
    }

    function test_multi_batch_duplicateId_respectsUnfrozen() public {
        vm.startPrank(enforcer);
        multi.setFrozenTokens(alice, ID, 950);
        multiProxy.setFrozenTokens(alice, ID, 950);
        vm.stopPrank();

        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = ID;
        ids[1] = ID;
        amounts[0] = 40;
        amounts[1] = 40;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC7943MultiToken.ERC7943InsufficientUnfrozenBalance.selector, alice, ID, 80, 50)
        );
        multi.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        assertEq(multi.balanceOf(alice, ID), 1_000);
        assertEq(multi.getFrozenTokens(alice, ID), 950);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC7943MultiToken.ERC7943InsufficientUnfrozenBalance.selector, alice, ID, 80, 50)
        );
        multiProxy.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        assertEq(multiProxy.balanceOf(alice, ID), 1_000);
        assertEq(multiProxy.getFrozenTokens(alice, ID), 950);
    }

    function test_mint_toContractWithoutReceiver_reverts() public {
        ERC7943NoReceiver noRecv = new ERC7943NoReceiver();

        vm.prank(enforcer);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(noRecv)));
        nft.mint(address(noRecv), 99);
        assertEq(nft.ownerOf(ID), alice);

        vm.prank(enforcer);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(noRecv)));
        multi.mint(address(noRecv), 99, 1);
        assertEq(multi.balanceOf(alice, ID), 1_000);
    }

    function test_userBurn_respectsCanTransferOverride() public {
        fungible.setBlockCanTransfer(true);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC7943Fungible.ERC7943CannotTransfer.selector, alice, address(0), 100));
        fungible.userBurn(100);
        vm.prank(enforcer);
        fungible.enforcerBurn(alice, 100);
        assertEq(fungible.balanceOf(alice), 900);

        nft.setBlockCanTransfer(true);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC7943NonFungible.ERC7943CannotTransfer.selector, alice, address(0), ID)
        );
        nft.userBurn(ID);
        vm.prank(enforcer);
        nft.enforcerBurn(ID);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, ID));
        nft.ownerOf(ID);

        multi.setBlockCanTransfer(true);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC7943MultiToken.ERC7943CannotTransfer.selector, alice, address(0), ID, 100)
        );
        multi.userBurn(ID, 100);
        vm.prank(enforcer);
        multi.enforcerBurn(alice, ID, 100);
        assertEq(multi.balanceOf(alice, ID), 900);
    }

    function test_init_keepsNameSetBeforeParentInit() public {
        ERC7943FungibleNamedUpgradeableHarness impl = new ERC7943FungibleNamedUpgradeableHarness();
        ERC7943FungibleNamedUpgradeableHarness named = ERC7943FungibleNamedUpgradeableHarness(
            address(
                new ERC1967Proxy(
                    address(impl), abi.encodeCall(ERC7943FungibleNamedUpgradeableHarness.initialize, (enforcer))
                )
            )
        );
        assertEq(named.name(), "RWA");
    }

    function test_transferFrom_wrongFrom_frozen_usesOwnerError() public {
        vm.prank(enforcer);
        nft.setFrozenTokens(alice, ID, true);
        assertTrue(nft.canTransfer(carol, bob, ID));

        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721IncorrectOwner.selector, carol, ID, alice));
        nft.transferFrom(carol, bob, ID);
    }

    function test_zeroEnforcer_reverts() public {
        vm.expectRevert(ERC7943Fungible.ERC7943InvalidEnforcer.selector);
        new ERC7943FungibleHarness(address(0));

        ERC7943FungibleUpgradeableHarness impl = new ERC7943FungibleUpgradeableHarness();
        vm.expectRevert(ERC7943FungibleUpgradeable.ERC7943InvalidEnforcer.selector);
        new ERC1967Proxy(address(impl), abi.encodeCall(ERC7943FungibleUpgradeableHarness.initialize, (address(0))));
    }
}
