// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";

/// @notice Read-only reconnaissance for case 07. It does not solve the challenge.
interface IFirepit {
    function threshold() external view returns (uint256);
    function nonce() external view returns (uint256);
    function RESOURCE() external view returns (address);
    function RESOURCE_RECIPIENT() external view returns (address);
    function TOKEN_JAR() external view returns (address);
}

contract FirepitInspector is Test {
    address user = vm.envAddress("USER_ADDRESS");

    address constant UNI = 0x57FB37d035e6Ad0E687E0a50dC3F515691deB815;
    address constant USDT = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736;
    address constant FIREPIT = 0xe122E231cb52aea99690963Fd73E91e33E97468f;

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68_413_600);
        // The challenge replaces the X Layer Standard Bridge with a harmless stub.
        // Do the same here so this environment matches Solution.t.sol exactly.
        vm.etch(0x4200000000000000000000000000000000000010, hex"60006000f3");
        deal(UNI, user, 2_000e18);
    }

    function test_InspectFirepit() public view {
        IFirepit firepit = IFirepit(FIREPIT);
        address jar = firepit.TOKEN_JAR();

        console.log("=== Uniswap Firepit reconnaissance ===");
        console.log("fork block");
        console.logUint(68_413_600);
        console.log("firepit", FIREPIT);
        console.log("token jar", jar);
        console.log("resource configured", firepit.RESOURCE());
        console.log("resource recipient", firepit.RESOURCE_RECIPIENT());
        console.log("required UNI raw");
        console.logUint(firepit.threshold());
        console.log("current release nonce");
        console.logUint(firepit.nonce());
        console.log("user UNI raw");
        console.logUint(IERC20(UNI).balanceOf(user));
        console.log("user UNI allowance to firepit");
        console.logUint(IERC20(UNI).allowance(user, FIREPIT));
        console.log("USDT held by token jar raw");
        console.logUint(IERC20(USDT).balanceOf(jar));
        console.log("USDT held by token jar whole");
        console.logUint(IERC20(USDT).balanceOf(jar) / 1e6);
        console.log("target USDT whole");
        console.logUint(45_000);
    }
}
