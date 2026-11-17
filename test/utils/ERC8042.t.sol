// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC8042} from "../../src/utils/ERC8042.sol";
import {StorageSlot7201} from "../../src/utils/StorageSlot7201.sol";

/// @custom:storage-location erc8042:myproject.erc721.registry
struct ERC8042RegistryFixture {
    uint256 value;
}

contract ERC8042Caller {
    function slot(string memory id) external pure returns (bytes32) {
        return ERC8042.erc8042Slot(id);
    }
}

contract ERC8042StorageHarness {
    function writeAt(bytes32 slot, uint256 value) external {
        assembly {
            sstore(slot, value)
        }
    }

    function readAt(bytes32 slot) external view returns (uint256 value) {
        assembly {
            value := sload(slot)
        }
    }
}

contract ERC8042Test is Test {
    ERC8042Caller internal caller = new ERC8042Caller();
    ERC8042StorageHarness internal harness = new ERC8042StorageHarness();

    function test_specExample_matchesKeccak() public pure {
        assertEq(ERC8042.erc8042Slot("myproject.erc721.registry"), keccak256("myproject.erc721.registry"));
    }

    function test_differsFromErc7201() public pure {
        string memory id = "myproject.erc721.registry";
        assertTrue(ERC8042.erc8042Slot(id) != StorageSlot7201.erc7201Slot(id));
    }

    function test_acceptsAsciiBounds() public pure {
        assertEq(ERC8042.erc8042Slot(" "), keccak256(" "));
        assertEq(ERC8042.erc8042Slot("~"), keccak256("~"));
    }

    function test_revertsEmpty() public {
        vm.expectRevert(ERC8042.ERC8042InvalidIdentifier.selector);
        caller.slot("");
    }

    function test_revertsBelowSpace() public {
        vm.expectRevert(ERC8042.ERC8042InvalidIdentifier.selector);
        caller.slot(string(abi.encodePacked(bytes1(0x1F))));
    }

    function test_revertsDel() public {
        vm.expectRevert(ERC8042.ERC8042InvalidIdentifier.selector);
        caller.slot(string(abi.encodePacked(bytes1(0x7F))));
    }

    function test_revertsNullAndUtf8() public {
        vm.expectRevert(ERC8042.ERC8042InvalidIdentifier.selector);
        caller.slot(string(abi.encodePacked("a", bytes1(0x00), "b")));

        vm.expectRevert(ERC8042.ERC8042InvalidIdentifier.selector);
        caller.slot(string(abi.encodePacked(bytes1(0xC3), bytes1(0xA9))));
    }

    function testFuzz_printableMatchesKeccak(uint8 len, bytes32 seed) public pure {
        len = uint8(bound(len, 1, 64));
        bytes memory data = new bytes(len);
        for (uint256 i = 0; i < len; ++i) {
            uint8 b = uint8(uint256(seed) >> ((i % 32) * 8));
            data[i] = bytes1(uint8(bound(b, 0x20, 0x7E)));
        }
        string memory id = string(data);
        assertEq(ERC8042.erc8042Slot(id), keccak256(data));
    }

    function testFuzz_nonAsciiReverts(uint8 len, bytes32 seed) public {
        len = uint8(bound(len, 0, 64));
        bytes memory data = new bytes(len);
        for (uint256 i = 0; i < len; ++i) {
            uint8 b = uint8(uint256(seed) >> ((i % 32) * 8));
            data[i] = bytes1(b);
        }

        bool invalid = len == 0;
        if (!invalid) {
            for (uint256 i = 0; i < len; ++i) {
                uint8 b = uint8(data[i]);
                if (b < 0x20 || b > 0x7E) {
                    invalid = true;
                    break;
                }
            }
        }

        if (invalid) {
            vm.expectRevert(ERC8042.ERC8042InvalidIdentifier.selector);
            caller.slot(string(data));
        } else {
            assertEq(caller.slot(string(data)), keccak256(data));
        }
    }

    function test_storageRoundtrip_isolatedById() public {
        bytes32 slotA = ERC8042.erc8042Slot("myproject.erc721.registry");
        bytes32 slotB = ERC8042.erc8042Slot("myproject.erc1155.metadata");

        harness.writeAt(slotA, 111);
        harness.writeAt(slotB, 222);

        assertEq(harness.readAt(slotA), 111);
        assertEq(harness.readAt(slotB), 222);
    }
}
