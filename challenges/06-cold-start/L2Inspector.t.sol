// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";
import "./Constants.sol";

interface IERC20Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

/// @notice Read-only reconnaissance for the Robinhood Chain fork.
/// It intentionally does not post an Inbox message or change any state.
contract L2Inspector is Test {
    address user = vm.envAddress("USER_ADDRESS");
    uint256 l2Fork;

    function setUp() public {
        l2Fork = vm.createFork(vm.envString("ROBINHOOD_RPC_URL"), L2_FORK_BLOCK);
        vm.selectFork(l2Fork);
    }

    function test_InspectCashcat() public view {
        address alias_ = address(uint160(user) + uint160(0x1111000000000000000000000000000000001111));

        console.log("=== Robinhood L2 reconnaissance ===");
        console.log("fork block", L2_FORK_BLOCK);
        console.log("CASHCAT", CASHCAT);
        console.log("CASHCAT bytecode bytes", CASHCAT.code.length);
        console.log("name", IERC20Metadata(CASHCAT).name());
        console.log("symbol", IERC20Metadata(CASHCAT).symbol());
        console.log("decimals", IERC20(CASHCAT).decimals());
        console.log("total supply raw", IERC20(CASHCAT).totalSupply());
        console.log("user", user);
        console.log("user CASHCAT raw", IERC20(CASHCAT).balanceOf(user));
        console.log("L2 alias", alias_);
        console.log("alias CASHCAT raw", IERC20(CASHCAT).balanceOf(alias_));
    }
}
