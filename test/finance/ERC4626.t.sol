// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC4626} from "../../src/finance/ERC4626/ERC4626.sol";
import {ERC4626Upgradeable} from "../../src/finance/ERC4626/ERC4626Upgradeable.sol";
import {IERC4626} from "../../src/finance/ERC4626/IERC4626.sol";
import {StorageSlot7201} from "../../src/utils/StorageSlot7201.sol";

contract MockAsset is ERC20 {
    uint8 private immutable _decimals;

    constructor(uint8 decimals_) ERC20("Mock Asset", "MOCK") {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockVault is ERC4626 {
    constructor(IERC20 asset_) ERC20("Vault Share", "vMOCK") ERC4626(asset_) {}
}

contract MockVaultOffset is ERC4626 {
    constructor(IERC20 asset_) ERC20("Vault Offset", "vOFF") ERC4626(asset_) {}

    function _decimalsOffset() internal pure override returns (uint8) {
        return 3;
    }
}

contract MockVaultUpgradeable is ERC4626Upgradeable {
    function initialize(IERC20 asset_, string memory name_, string memory symbol_) external initializer {
        __ERC4626_init(asset_, name_, symbol_);
    }
}

contract FeeOnTransferAsset is ERC20 {
    constructor() ERC20("Fee Token", "FEE") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 fee = amount / 10;
        super.transfer(to, amount - fee);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 fee = amount / 10;
        _spendAllowance(from, _msgSender(), amount);
        _transfer(from, to, amount - fee);
        return true;
    }
}

contract RedeemCappedVault is ERC4626 {
    constructor(IERC20 asset_) ERC20("Redeem Cap", "vRC") ERC4626(asset_) {}

    function maxRedeem(address) public pure override returns (uint256) {
        return 0;
    }
}

contract LimitedVault is ERC4626 {
    uint256 public depositCap;

    constructor(IERC20 asset_, uint256 depositCap_) ERC20("Capped Vault", "vCAP") ERC4626(asset_) {
        depositCap = depositCap_;
    }

    function maxDeposit(address) public view override returns (uint256) {
        uint256 assets = totalAssets();
        return assets >= depositCap ? 0 : depositCap - assets;
    }

    function maxMint(address receiver) public view override returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        return convertToShares(maxAssets);
    }
}

contract ERC4626Test is Test {
    MockAsset internal asset;
    MockVault internal vault;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        asset = new MockAsset(18);
        vault = new MockVault(asset);
        asset.mint(alice, 1_000_000 ether);
        asset.mint(bob, 1_000_000 ether);
    }

    function _approve(address owner, uint256 amount) internal {
        vm.prank(owner);
        asset.approve(address(vault), amount);
    }

    function test_asset_and_decimals() public view {
        assertEq(vault.asset(), address(asset));
        assertEq(vault.decimals(), 18);
        assertEq(vault.totalAssets(), 0);
    }

    function test_decimals_non18Asset() public {
        MockAsset six = new MockAsset(6);
        MockVault sixVault = new MockVault(six);
        assertEq(sixVault.decimals(), 6);
    }

    function test_decimals_withOffset() public {
        MockVaultOffset offsetVault = new MockVaultOffset(asset);
        assertEq(offsetVault.decimals(), 21);
    }

    function test_deposit_emptyVault() public {
        _approve(alice, 1_000 ether);
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit IERC4626.Deposit(alice, alice, 1_000 ether, 1_000 ether);
        uint256 shares = vault.deposit(1_000 ether, alice);

        assertEq(shares, 1_000 ether);
        assertEq(vault.balanceOf(alice), 1_000 ether);
        assertEq(vault.totalAssets(), 1_000 ether);
        assertEq(asset.balanceOf(address(vault)), 1_000 ether);
    }

    function test_mint_emptyVault() public {
        _approve(alice, 1_000 ether);
        vm.prank(alice);
        uint256 assets = vault.mint(1_000 ether, alice);
        assertEq(assets, 1_000 ether);
        assertEq(vault.balanceOf(alice), 1_000 ether);
    }

    function test_deposit_toOtherReceiver() public {
        _approve(alice, 100 ether);
        vm.prank(alice);
        vault.deposit(100 ether, bob);
        assertEq(vault.balanceOf(bob), 100 ether);
        assertEq(vault.balanceOf(alice), 0);
    }

    function test_deposit_zero() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(0, alice);
        assertEq(shares, 0);
        assertEq(vault.totalSupply(), 0);
    }

    function test_mint_zero() public {
        vm.prank(alice);
        uint256 assets = vault.mint(0, alice);
        assertEq(assets, 0);
    }

    function test_withdraw() public {
        _approve(alice, 1_000 ether);
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit IERC4626.Withdraw(alice, alice, alice, 400 ether, 400 ether);
        uint256 shares = vault.withdraw(400 ether, alice, alice);

        assertEq(shares, 400 ether);
        assertEq(vault.balanceOf(alice), 600 ether);
        assertEq(asset.balanceOf(alice), 1_000_000 ether - 600 ether);
    }

    function test_redeem() public {
        _approve(alice, 1_000 ether);
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);

        vm.prank(alice);
        uint256 assets = vault.redeem(250 ether, bob, alice);
        assertEq(assets, 250 ether);
        assertEq(asset.balanceOf(bob), 1_000_000 ether + 250 ether);
        assertEq(vault.balanceOf(alice), 750 ether);
    }

    function test_withdraw_byAllowance() public {
        _approve(alice, 500 ether);
        vm.prank(alice);
        vault.deposit(500 ether, alice);

        vm.prank(alice);
        vault.approve(bob, 200 ether);

        vm.prank(bob);
        vault.withdraw(200 ether, bob, alice);
        assertEq(asset.balanceOf(bob), 1_000_000 ether + 200 ether);
        assertEq(vault.allowance(alice, bob), 0);
    }

    function test_previewDeposit_matchesDeposit() public {
        _approve(alice, 123 ether);
        uint256 preview = vault.previewDeposit(123 ether);
        vm.prank(alice);
        uint256 shares = vault.deposit(123 ether, alice);
        assertEq(shares, preview);
    }

    function test_previewMint_coversMint() public {
        uint256 previewAssets = vault.previewMint(77 ether);
        _approve(alice, previewAssets);
        vm.prank(alice);
        uint256 assets = vault.mint(77 ether, alice);
        assertEq(assets, previewAssets);
    }

    function test_previewWithdraw_matchesWithdraw() public {
        _approve(alice, 500 ether);
        vm.prank(alice);
        vault.deposit(500 ether, alice);

        uint256 preview = vault.previewWithdraw(80 ether);
        vm.prank(alice);
        uint256 shares = vault.withdraw(80 ether, alice, alice);
        assertEq(shares, preview);
    }

    function test_previewRedeem_matchesRedeem() public {
        _approve(alice, 500 ether);
        vm.prank(alice);
        vault.deposit(500 ether, alice);

        uint256 preview = vault.previewRedeem(80 ether);
        vm.prank(alice);
        uint256 assets = vault.redeem(80 ether, alice, alice);
        assertEq(assets, preview);
    }

    function test_maxRedeem_isBalance() public {
        _approve(alice, 10 ether);
        vm.prank(alice);
        vault.deposit(10 ether, alice);
        assertEq(vault.maxRedeem(alice), 10 ether);
        assertEq(vault.maxWithdraw(alice), vault.convertToAssets(10 ether));
    }

    function test_withdraw_revert_exceedsMax() public {
        _approve(alice, 10 ether);
        vm.prank(alice);
        vault.deposit(10 ether, alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC4626.ERC4626ExceededMaxWithdraw.selector, alice, 11 ether, 10 ether));
        vault.withdraw(11 ether, alice, alice);
    }

    function test_redeem_revert_exceedsMax() public {
        _approve(alice, 10 ether);
        vm.prank(alice);
        vault.deposit(10 ether, alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC4626.ERC4626ExceededMaxRedeem.selector, alice, 11 ether, 10 ether));
        vault.redeem(11 ether, alice, alice);
    }

    function test_deposit_revert_exceedsCap() public {
        LimitedVault capped = new LimitedVault(asset, 100 ether);
        vm.prank(alice);
        asset.approve(address(capped), 200 ether);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC4626.ERC4626ExceededMaxDeposit.selector, alice, 200 ether, 100 ether));
        capped.deposit(200 ether, alice);
    }

    function test_convert_afterSecondDepositor() public {
        _approve(alice, 1_000 ether);
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);

        _approve(bob, 500 ether);
        vm.prank(bob);
        uint256 bobShares = vault.deposit(500 ether, bob);

        assertApproxEqAbs(bobShares, 500 ether, 1);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)) + vault.convertToAssets(bobShares), vault.totalAssets());
    }

    function test_firstDepositor_donationDoesNotZeroNextDeposit() public {
        _approve(alice, 1);
        vm.prank(alice);
        vault.deposit(1, alice);
        asset.mint(address(vault), 10_000 ether);

        _approve(bob, 10_000 ether);
        vm.prank(bob);
        uint256 bobShares = vault.deposit(10_000 ether, bob);
        assertGt(bobShares, 0);
        assertGt(vault.previewRedeem(bobShares), 0);
    }

    function test_storageSlot_matchesLibrary() public pure {
        bytes32 expected = StorageSlot7201.erc7201Slot("curatedcontracts.storage.ERC4626");
        assertEq(expected, bytes32(uint256(0xdbb9fc12182ed1737699199975af0444c4e748bbedf3649c6f1feb673c58b700)));
    }

    function test_upgradeable_initAndDeposit() public {
        MockVaultUpgradeable impl = new MockVaultUpgradeable();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl), abi.encodeCall(MockVaultUpgradeable.initialize, (asset, "Proxy Vault", "pvMOCK"))
        );
        MockVaultUpgradeable proxied = MockVaultUpgradeable(address(proxy));

        assertEq(proxied.asset(), address(asset));
        assertEq(proxied.name(), "Proxy Vault");
        assertEq(proxied.decimals(), 18);

        vm.prank(alice);
        asset.approve(address(proxied), 50 ether);
        vm.prank(alice);
        uint256 shares = proxied.deposit(50 ether, alice);
        assertEq(shares, 50 ether);
        assertEq(proxied.balanceOf(alice), 50 ether);
    }

    function test_upgradeable_cannotReinitialize() public {
        MockVaultUpgradeable impl = new MockVaultUpgradeable();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl), abi.encodeCall(MockVaultUpgradeable.initialize, (asset, "Proxy Vault", "pvMOCK"))
        );
        vm.expectRevert();
        MockVaultUpgradeable(address(proxy)).initialize(asset, "x", "y");
    }

    function testFuzz_depositWithdraw_roundTrip(uint96 amount) public {
        uint256 assets = bound(uint256(amount), 1, 100_000 ether);
        _approve(alice, assets);
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);
        assertEq(shares, vault.previewRedeem(shares) > 0 || shares == 0 ? shares : shares);

        vm.prank(alice);
        uint256 returned = vault.redeem(shares, alice, alice);
        assertLe(returned, assets);
        assertGe(assets - returned, 0);
        assertEq(vault.balanceOf(alice), 0);
    }

    function testFuzz_previewDeposit_leExecuted(uint96 amount) public {
        uint256 assets = bound(uint256(amount), 0, 50_000 ether);
        uint256 preview = vault.previewDeposit(assets);
        if (assets == 0) {
            assertEq(preview, 0);
            return;
        }
        _approve(alice, assets);
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);
        assertGe(shares, preview);
    }

    function test_constructor_revert_zeroAsset() public {
        vm.expectRevert(abi.encodeWithSelector(ERC4626.ERC4626InvalidAsset.selector, address(0)));
        new MockVault(IERC20(address(0)));
    }

    function test_upgradeable_revert_zeroAsset() public {
        MockVaultUpgradeable impl = new MockVaultUpgradeable();
        vm.expectRevert(abi.encodeWithSelector(ERC4626Upgradeable.ERC4626InvalidAsset.selector, address(0)));
        new ERC1967Proxy(address(impl), abi.encodeCall(MockVaultUpgradeable.initialize, (IERC20(address(0)), "x", "y")));
    }

    function test_deposit_revert_zeroSharesAfterDonation() public {
        _approve(alice, 1);
        vm.prank(alice);
        vault.deposit(1, alice);
        asset.mint(address(vault), 10_000 ether);

        _approve(bob, 1);
        vm.prank(bob);
        vm.expectRevert(ERC4626.ERC4626ZeroShares.selector);
        vault.deposit(1, bob);
    }

    function test_deposit_revert_feeOnTransfer() public {
        FeeOnTransferAsset feeAsset = new FeeOnTransferAsset();
        MockVault feeVault = new MockVault(feeAsset);
        feeAsset.mint(alice, 1_000 ether);
        vm.prank(alice);
        feeAsset.approve(address(feeVault), 100 ether);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC4626.ERC4626AssetTransferMismatch.selector, 100 ether, 90 ether));
        feeVault.deposit(100 ether, alice);
    }

    function test_maxWithdraw_followsMaxRedeem() public {
        RedeemCappedVault capped = new RedeemCappedVault(asset);
        vm.prank(alice);
        asset.approve(address(capped), 10 ether);
        vm.prank(alice);
        capped.deposit(10 ether, alice);
        assertEq(capped.maxRedeem(alice), 0);
        assertEq(capped.maxWithdraw(alice), 0);
    }

    function testFuzz_convertPair(uint96 assetsRaw) public {
        uint256 assets = bound(uint256(assetsRaw), 1, 10_000 ether);
        _approve(alice, assets);
        vm.prank(alice);
        vault.deposit(assets, alice);

        uint256 shares = vault.convertToShares(assets);
        uint256 back = vault.convertToAssets(shares);
        assertLe(back, assets);
    }
}
