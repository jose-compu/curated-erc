// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC7751} from "../../src/utils/ERC7751.sol";

// --- EIP-7751 reference vector (Token / Vault / Router) ---

contract ERC7751Token {
    mapping(address => uint256) public balanceOf;

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract ERC7751Vault {
    ERC7751Token public token;

    error ERC20TransferFailed(address recipient);

    constructor(ERC7751Token token_) {
        token = token_;
    }

    function withdraw(address to, uint256 amount) external {
        try token.transfer(to, amount) {}
        catch (bytes memory error) {
            ERC7751.bubbleRevert(
                address(token),
                abi.encodeCall(ERC7751Token.transfer, (to, amount)),
                error,
                abi.encodeWithSelector(ERC20TransferFailed.selector, to)
            );
        }
    }
}

contract ERC7751Router {
    ERC7751Vault public vault;

    constructor(ERC7751Vault vault_) {
        vault = vault_;
    }

    function withdraw(uint256 amount) external {
        try vault.withdraw(msg.sender, amount) {}
        catch (bytes memory error) {
            ERC7751.bubbleRevert(address(vault), abi.encodeCall(ERC7751Vault.withdraw, (msg.sender, amount)), error, "");
        }
    }
}

// --- Helpers for additional cases ---

contract EthReceiver {
    receive() external payable {
        revert();
    }
}

contract ERC7751Wrapper {
    error ContextNote(uint256 value);

    function wrapEthTransfer(address target, bytes memory reason, bytes memory details) external {
        ERC7751.bubbleRevert(target, "", reason, details);
    }

    function wrapWithDetails(bytes memory reason) external pure {
        ERC7751.revertWithWrappedError(
            address(1), bytes4(0x12345678), reason, abi.encodeWithSelector(ContextNote.selector, 42)
        );
    }

    function wrapEmptyDetails(address target, bytes4 selector, bytes memory reason) external pure {
        ERC7751.revertWithWrappedError(target, selector, reason, "");
    }
}

contract ERC7751Test is Test {
    function test_wrappedErrorSelector_matchesSpec() public pure {
        assertEq(ERC7751.WRAPPED_ERROR_SELECTOR, bytes4(0x90bfb865));
        assertEq(ERC7751.WrappedError.selector, bytes4(0x90bfb865));
    }

    function test_bubbledNestedReverts() public {
        uint256 amount = 1;
        ERC7751Token token = new ERC7751Token();
        ERC7751Vault vault = new ERC7751Vault(token);
        ERC7751Router router = new ERC7751Router(vault);

        bytes memory expectedError = abi.encodeWithSelector(
            ERC7751.WrappedError.selector,
            address(vault),
            ERC7751Vault.withdraw.selector,
            abi.encodeWithSelector(
                ERC7751.WrappedError.selector,
                address(token),
                ERC7751Token.transfer.selector,
                abi.encodeWithSignature("Error(string)", "insufficient balance"),
                abi.encodeWithSelector(ERC7751Vault.ERC20TransferFailed.selector, address(this))
            ),
            ""
        );

        vm.expectRevert(expectedError);
        router.withdraw(amount);
    }

    function test_emptyDetails() public {
        ERC7751Wrapper wrapper = new ERC7751Wrapper();
        bytes memory reason = abi.encodeWithSignature("Error(string)", "inner");

        vm.expectRevert(
            abi.encodeWithSelector(ERC7751.WrappedError.selector, address(0xBEEF), bytes4(0xdeadbeef), reason, "")
        );
        wrapper.wrapEmptyDetails(address(0xBEEF), bytes4(0xdeadbeef), reason);
    }

    function test_plainEthTransfer_usesZeroSelector() public {
        EthReceiver target = new EthReceiver();
        ERC7751Wrapper wrapper = new ERC7751Wrapper();

        bytes memory inner = abi.encodeWithSignature("Error(string)", "receive revert");
        bytes memory expected =
            abi.encodeWithSelector(ERC7751.WrappedError.selector, address(target), bytes4(0), inner, "");

        vm.expectRevert(expected);
        wrapper.wrapEthTransfer(address(target), inner, "");
    }

    function test_calledSelector_emptyCalldata() public pure {
        assertEq(ERC7751.calledSelector(""), bytes4(0));
    }

    function test_detailsAbiEncodedCustomError() public {
        ERC7751Wrapper wrapper = new ERC7751Wrapper();
        bytes memory inner = abi.encodeWithSignature("Error(string)", "x");

        bytes memory expected = abi.encodeWithSelector(
            ERC7751.WrappedError.selector,
            address(1),
            bytes4(0x12345678),
            inner,
            abi.encodeWithSelector(ERC7751Wrapper.ContextNote.selector, 42)
        );

        vm.expectRevert(expected);
        wrapper.wrapWithDetails(inner);
    }
}
