// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC6909
 * @dev Interface of the ERC-6909 Minimal Multi-Token Interface.
 * See https://eips.ethereum.org/EIPS/eip-6909
 */
interface IERC6909 {
    event Transfer(
        address caller, address indexed sender, address indexed receiver, uint256 indexed id, uint256 amount
    );

    event OperatorSet(address indexed owner, address indexed spender, bool approved);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);

    function balanceOf(address owner, uint256 id) external view returns (uint256);

    function allowance(address owner, address spender, uint256 id) external view returns (uint256);

    function isOperator(address owner, address spender) external view returns (bool);

    function transfer(address receiver, uint256 id, uint256 amount) external returns (bool);

    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external returns (bool);

    function approve(address spender, uint256 id, uint256 amount) external returns (bool);

    function setOperator(address spender, bool approved) external returns (bool);
}
