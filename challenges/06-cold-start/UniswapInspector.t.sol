// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "./Constants.sol";

interface IPositionManagerRead {
    function factory() external view returns (address);
    function WETH9() external view returns (address);
}

interface IV3FactoryRead {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

interface IV3PoolRead {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function liquidity() external view returns (uint128);
    function slot0()
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint16, uint16, uint16, uint8, bool);
}

/// @notice Finds the real CASHCAT/WETH V3 pool from on-chain infrastructure.
contract UniswapInspector is Test {
    uint256 l2Fork;
    address constant POSITION_MANAGER = 0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3;

    function setUp() public {
        l2Fork = vm.createFork(vm.envString("ROBINHOOD_RPC_URL"), L2_FORK_BLOCK);
        vm.selectFork(l2Fork);
    }

    function test_InspectCashcatPool() public view {
        address factory = IPositionManagerRead(POSITION_MANAGER).factory();
        address weth = IPositionManagerRead(POSITION_MANAGER).WETH9();
        uint24[4] memory feeTiers = [uint24(100), 500, 3_000, 10_000];

        console.log("=== CASHCAT / WETH pool reconnaissance ===");
        console.log("position manager", POSITION_MANAGER);
        console.log("factory", factory);
        console.log("WETH", weth);

        for (uint256 i = 0; i < feeTiers.length; i++) {
            address pool = IV3FactoryRead(factory).getPool(CASHCAT, weth, feeTiers[i]);
            if (pool == address(0)) continue;

            (uint160 sqrtPriceX96, int24 tick,,,,,) = IV3PoolRead(pool).slot0();
            console.log("pool", pool);
            console.log("fee tier", feeTiers[i]);
            console.log("token0", IV3PoolRead(pool).token0());
            console.log("token1", IV3PoolRead(pool).token1());
            console.log("liquidity", IV3PoolRead(pool).liquidity());
            console.log("sqrtPriceX96", sqrtPriceX96);
            console.logInt(tick);
        }
    }
}
