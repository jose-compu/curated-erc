// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC5267} from "../../src/utils/cryptography/ERC5267.sol";
import {ERC5267Upgradeable} from "../../src/utils/cryptography/ERC5267Upgradeable.sol";
import {IERC5267} from "../../src/utils/cryptography/IERC5267.sol";
import {StorageSlot7201} from "../../src/utils/StorageSlot7201.sol";

contract ERC5267Harness is ERC5267 {
    constructor(string memory name_, string memory version_) ERC5267(name_, version_) {}

    function exposeSetDomain(string memory name_, string memory version_) external {
        _setDomain(name_, version_);
    }
}

contract ERC5267UpgradeableHarness is ERC5267Upgradeable {
    function initialize(string memory name_, string memory version_) external initializer {
        __ERC5267_init(name_, version_);
    }

    function exposeSetDomain(string memory name_, string memory version_) external {
        _setDomain(name_, version_);
    }
}

contract ERC5267Test is Test {
    ERC5267Harness internal harness;

    function setUp() public {
        harness = new ERC5267Harness("Test", "1");
    }

    function _readDomain(ERC5267 target)
        internal
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return target.eip712Domain();
    }

    function test_defaultDomain() public view {
        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        ) = _readDomain(harness);
        assertEq(fields, hex"0f");
        assertEq(name, "Test");
        assertEq(version, "1");
        assertEq(chainId, block.chainid);
        assertEq(verifyingContract, address(harness));
        assertEq(salt, bytes32(0));
        assertEq(extensions.length, 0);
    }

    function test_chainIdFollowsBlock() public {
        (,,, uint256 chainIdBefore,,,) = _readDomain(harness);
        assertEq(chainIdBefore, block.chainid);

        vm.chainId(42);
        (,,, uint256 chainIdAfter,,,) = _readDomain(harness);
        assertEq(chainIdAfter, 42);
    }

    function test_setDomain_newVersion_emitsAndUpdates() public {
        vm.expectEmit(true, true, true, true);
        emit IERC5267.EIP712DomainChanged();

        harness.exposeSetDomain("Test", "2");
        (, string memory name, string memory version,,,,) = _readDomain(harness);
        assertEq(name, "Test");
        assertEq(version, "2");
    }

    function test_setDomain_sameValues_noEvent() public {
        vm.recordLogs();
        harness.exposeSetDomain("Test", "1");
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function test_constructor_emitsDomainChanged() public {
        vm.recordLogs();
        ERC5267Harness created = new ERC5267Harness("New", "1");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].emitter, address(created));
        assertEq(logs[0].topics[0], keccak256("EIP712DomainChanged()"));
    }

    function test_upgradeable_proxyDomain() public {
        ERC5267UpgradeableHarness impl = new ERC5267UpgradeableHarness();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(impl), abi.encodeCall(ERC5267UpgradeableHarness.initialize, ("Proxy", "1")));
        ERC5267UpgradeableHarness proxied = ERC5267UpgradeableHarness(address(proxy));

        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        ) = proxied.eip712Domain();
        assertEq(fields, hex"0f");
        assertEq(name, "Proxy");
        assertEq(version, "1");
        assertEq(chainId, block.chainid);
        assertEq(verifyingContract, address(proxy));
        assertEq(salt, bytes32(0));
        assertEq(extensions.length, 0);
    }

    function test_upgradeable_cannotReinitialize() public {
        ERC5267UpgradeableHarness impl = new ERC5267UpgradeableHarness();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(impl), abi.encodeCall(ERC5267UpgradeableHarness.initialize, ("Proxy", "1")));
        vm.expectRevert();
        ERC5267UpgradeableHarness(address(proxy)).initialize("x", "y");
    }

    function test_upgradeable_setDomainThroughProxy() public {
        ERC5267UpgradeableHarness impl = new ERC5267UpgradeableHarness();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(impl), abi.encodeCall(ERC5267UpgradeableHarness.initialize, ("Proxy", "1")));
        ERC5267UpgradeableHarness proxied = ERC5267UpgradeableHarness(address(proxy));

        vm.expectEmit(true, true, true, true);
        emit IERC5267.EIP712DomainChanged();
        proxied.exposeSetDomain("Proxy", "2");

        (,, string memory version,,,,) = proxied.eip712Domain();
        assertEq(version, "2");
    }

    function test_storageSlot_matchesLibrary() public pure {
        bytes32 expected = StorageSlot7201.erc7201Slot("curatedcontracts.storage.ERC5267");
        assertEq(expected, bytes32(uint256(0xa6975cdd03b545c71f44173764996f98911c37b038be6f5e1e2486b10ea0e300)));
    }

    function testFuzz_nameVersionRoundTrip(string calldata name, string calldata version) public {
        vm.assume(bytes(name).length <= 64);
        vm.assume(bytes(version).length <= 64);

        ERC5267Harness fuzzHarness = new ERC5267Harness(name, version);
        (, string memory readName, string memory readVersion,,,,) = _readDomain(fuzzHarness);
        assertEq(readName, name);
        assertEq(readVersion, version);
    }
}
