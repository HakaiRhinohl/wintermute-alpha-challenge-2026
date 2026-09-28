// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

interface IV3FactoryLookup {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

/// @notice Identifies, at the fork block, which standard USDT0 pool can
/// actually price each additional fee asset.  This does not collect or trade.
contract FindLiquidBasketPools is Test {
    address constant FACTORY = 0x4B2ab38DBF28D31D467aA8993f6c2585981D6804;
    address constant USDT0 = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736;
    address constant AOXC = 0xeB9580c3946BB47d73AAE1d4f7A94148B554b2F4;
    address constant XSOL = 0x505000008DE8748DBd4422ff4687a4FC9bEba15b;

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68_413_600);
    }

    function test_FindDirectUSDT0Pools() public view {
        _find("AOXC", AOXC);
        _find("xSOL", XSOL);
    }

    function _find(string memory symbol, address token) internal view {
        uint24[4] memory fees = [uint24(100), 500, 3_000, 10_000];
        console.log("===", symbol);
        for (uint256 i; i < fees.length; ++i) {
            address pool = IV3FactoryLookup(FACTORY).getPool(token, USDT0, fees[i]);
            if (pool != address(0)) {
                console.log("fee tier", fees[i]);
                console.log("pool", pool);
            }
        }
    }
}
