// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

interface IV3OpenFeeAdapterState {
    function FACTORY() external view returns (address);
    function TOKEN_JAR() external view returns (address);
    function defaultFee() external view returns (uint8);
    function feeTiers(uint256 index) external view returns (uint24);
}

interface IV3FactoryOwner {
    function owner() external view returns (address);
}

/// @notice Verifies the fee-control relationship before using adapter events
/// as our discovery index. All reads use the challenge fork.
contract FeeSystemInspector is Test {
    address constant ADAPTER = 0x6A88EF2e6511CAFfE2D006e260e7A5d1E7D4d7D7;

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68_413_600);
    }

    function test_InspectFeeControlPlane() public view {
        IV3OpenFeeAdapterState adapter = IV3OpenFeeAdapterState(ADAPTER);
        address factory = adapter.FACTORY();
        console.log("=== X Layer V3 protocol-fee control plane ===");
        console.log("adapter", ADAPTER);
        console.log("adapter factory", factory);
        console.log("factory owner", IV3FactoryOwner(factory).owner());
        console.log("token jar", adapter.TOKEN_JAR());
        console.log("encoded global default fee", adapter.defaultFee());
        console.log("stored fee tiers:");

        for (uint256 i; i < 16; ++i) {
            try adapter.feeTiers(i) returns (uint24 tier) {
                console.logUint(tier);
            } catch {
                break;
            }
        }
    }
}
