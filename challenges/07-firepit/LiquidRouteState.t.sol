// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

interface IV3LiquiditySnapshot {
    function liquidity() external view returns (uint128);
}

/// @notice A pool address alone does not make a route tradable.  This reads
/// the active in-range liquidity for every direct USDT0 route found in the
/// historical PoolCreated inventory.
contract LiquidRouteState is Test {
    struct Route {
        string asset;
        uint24 fee;
        address pool;
        bool collectable;
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68_413_600);
    }

    function test_ListActiveLiquidity() public view {
        Route[12] memory routes = [
            Route("WOKB", 100, 0x9e485CC2Ec10E87A9B6e58602889Df392B7F6453, true),
            Route("WOKB", 500, 0xe3BE6A0137f1b0602Fc1a4841686f43B340a5082, true),
            Route("WOKB", 3000, 0x63d62734847E55A266FCa4219A9aD0a02D5F6e02, true),
            Route("xBTC", 100, 0x6CF6A073dDdd6fdD74b1b9f149621E85f01AACb9, true),
            Route("xBTC", 500, 0x5fcFb33C9AB1665FeE892eB2aF163e863a874D73, true),
            Route("xBTC", 3000, 0x75255002FEc0E917BF3c8FB588c4C0218460eC5c, true),
            Route("xETH", 100, 0x1598889895752De04cb12d23ef60fC7Ca7907922, true),
            Route("xETH", 500, 0x77ef18adF35f62B2Ad442e4370cDbC7fe78B7dcC, true),
            Route("xETH", 3000, 0x2B702e9D8925251eB7e59950Cc22e4110750D59d, true),
            Route("USDG", 100, 0x0cBe0dBE1400e57f371a38BD3b9bC80F7C3676dA, true),
            Route("AOXC", 3000, 0x1200E29A106F9e1eE5334D741A1f26346AA49aF2, true),
            Route("xSOL", 500, 0x4651300221f345a4c6F566079BD1DDC291049c7d, true)
        ];

        console.log("=== Direct USDT0 routes with active liquidity ===");
        for (uint256 i; i < routes.length; ++i) {
            Route memory route = routes[i];
            uint128 active = IV3LiquiditySnapshot(route.pool).liquidity();
            console.log("asset", route.asset);
            console.log("fee tier", route.fee);
            console.log("pool", route.pool);
            console.log("active liquidity");
            console.logUint(active);
        }
    }
}
