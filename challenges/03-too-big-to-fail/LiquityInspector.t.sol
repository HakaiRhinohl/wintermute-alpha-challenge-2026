// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "./Constants.sol";

/// @dev Minimal read surface for understanding this historical Liquity Trove.
interface ITroveManagerInspector {
    function getEntireDebtAndColl(address borrower)
        external
        view
        returns (uint256 debt, uint256 coll, uint256 pendingDebtReward, uint256 pendingCollReward);
    function getCurrentICR(address borrower, uint256 price) external view returns (uint256);
    function getTroveStatus(address borrower) external view returns (uint256);
    function checkRecoveryMode(uint256 price) external view returns (bool);
}

interface IPriceFeedInspector {
    function fetchPrice() external returns (uint256);
}

interface IStabilityPoolInspector {
    function getTotalLUSDDeposits() external view returns (uint256);
}

contract LiquityInspector is Test {
    address constant BORROWER = 0x903d12bf2c57A29f32365917c706ce0e1a84Cce3;
    address constant TROVE_MANAGER = 0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2;
    address constant PRICE_FEED = 0x4c517D4e2C851CA76d7eC94B805269Df0f2201De;
    address constant STABILITY_POOL = 0x66017D22b0f8556afDd19FC67041899Eb65a21bb;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), FORK_BLOCK);
    }

    function test_InspectBorrower() public {
        // fetchPrice is deliberately non-view: it is the same oracle entrypoint
        // that Liquity uses when it decides whether a liquidation is valid.
        uint256 price = IPriceFeedInspector(PRICE_FEED).fetchPrice();
        (uint256 debt, uint256 coll, uint256 pendingDebt, uint256 pendingColl) =
            ITroveManagerInspector(TROVE_MANAGER).getEntireDebtAndColl(BORROWER);
        uint256 icr = ITroveManagerInspector(TROVE_MANAGER).getCurrentICR(BORROWER, price);
        bool recoveryMode = ITroveManagerInspector(TROVE_MANAGER).checkRecoveryMode(price);
        uint256 stabilityPoolLUSD = IStabilityPoolInspector(STABILITY_POOL).getTotalLUSDDeposits();

        console.log("=== Liquity borrower at the historical fork ===");
        console.log("fork block", FORK_BLOCK);
        console.log("ETH/USD price (18 decimals)", price);
        console.log("Trove status (1 = active)", ITroveManagerInspector(TROVE_MANAGER).getTroveStatus(BORROWER));
        console.log("entire debt, LUSD raw", debt);
        console.log("entire collateral, ETH raw", coll);
        console.log("pending debt reward, raw", pendingDebt);
        console.log("pending collateral reward, raw", pendingColl);
        console.log("ICR (18 decimals)", icr);
        console.log("ICR as whole percent", icr * 100 / 1e18);
        console.log("system is in recovery mode", recoveryMode);
        console.log("Stability Pool LUSD, raw", stabilityPoolLUSD);
        console.log("0.5 percent ETH gas compensation, raw", coll / 200);
        console.log("0.5 percent ETH gas compensation, whole ETH", coll / 200 / 1e18);
    }
}
