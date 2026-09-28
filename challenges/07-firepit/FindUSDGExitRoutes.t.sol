// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

interface IV3FactoryUSDGRoutes {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IV3PoolUSDGLiquidity {
    function liquidity() external view returns (uint128);
}

/// @notice Searches the next evidence-based two-hop anchor:
/// fee asset -> USDG -> USDT0.  USDG is an anchor because the prior fork
/// quote independently established an executable USDG -> USDT0 route.
contract FindUSDGExitRoutes is Test {
    address constant FACTORY = 0x4B2ab38DBF28D31D467aA8993f6c2585981D6804;
    address constant USDG = 0x4ae46a509F6b1D9056937BA4500cb143933D2dc8;

    address constant AOXC = 0xeB9580c3946BB47d73AAE1d4f7A94148B554b2F4;
    address constant NIUMA = 0x87669801A1FaD6DAD9dB70d27Ac752f452989667;
    address constant GPU = 0xd624079F9062AAb098D28a05bAD2f19614e6C5Ac;
    address constant WNVDAx = 0xa8ddb5Cd96b5222AFe198316E9A57CAA642850D5;
    address constant XSOL = 0x505000008DE8748DBd4422ff4687a4FC9bEba15b;
    address constant BOOST = 0xc48E258b6dB8Bc00F6715B471BE48D4DD2B12533;

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68_413_600);
    }

    function test_FindUSDGExitRoutes() public view {
        _find("AOXC", AOXC);
        _find("NIUMA", NIUMA);
        _find("GPU", GPU);
        _find("wNVDAx", WNVDAx);
        _find("xSOL", XSOL);
        _find("boost", BOOST);
    }

    function _find(string memory symbol, address token) internal view {
        uint24[4] memory fees = [uint24(100), 500, 3_000, 10_000];
        console.log("===", symbol);
        for (uint256 i; i < fees.length; ++i) {
            address pool = IV3FactoryUSDGRoutes(FACTORY).getPool(token, USDG, fees[i]);
            if (pool == address(0)) continue;

            console.log("fee tier", fees[i]);
            console.log("pool", pool);
            console.log("active liquidity");
            console.logUint(IV3PoolUSDGLiquidity(pool).liquidity());
        }
    }
}
