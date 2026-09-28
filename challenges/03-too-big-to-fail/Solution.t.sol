// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";
import "./Interfaces.sol";
import "./Constants.sol";

contract TooBigToFail is Test {
    address user = vm.envAddress("USER_ADDRESS");
    address constant BORROWER = 0x903d12bf2c57A29f32365917c706ce0e1a84Cce3;
    address constant TROVE_MANAGER = 0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), FORK_BLOCK);
        vm.deal(user, 0.1 ether);
    }

    function test_Solution() public {
        vm.startBroadcast(user);

        // In Liquity Recovery Mode this Trove is eligible for liquidation.
        // The Stability Pool repays its LUSD debt; the caller receives the
        // protocol's 0.5% ETH collateral gas compensation.
        ITroveManager(TROVE_MANAGER).liquidate(BORROWER);

        vm.stopBroadcast();
        checkSolve();
    }

    function checkSolve() public view {
        require(user.balance >= 2500 ether, "not enough ETH");
        console.log("Solved. Ending balance in ETH: %18e", user.balance);
    }
}
