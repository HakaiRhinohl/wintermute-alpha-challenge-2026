// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";

interface IV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IV3PoolFees {
    function protocolFees() external view returns (uint128 token0, uint128 token1);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IV3OpenFeeAdapter {
    struct CollectParams {
        address pool;
        uint128 amount0Requested;
        uint128 amount1Requested;
    }

    function collect(CollectParams[] calldata collectParams) external;
}

/// @notice A fork-only rehearsal of the fee-collection leg. No UNI is spent here.
contract CollectionSimulation is Test {
    address constant USDT = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736;
    address constant WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
    address constant FACTORY = 0x4B2ab38DBF28D31D467aA8993f6c2585981D6804;
    address constant ADAPTER = 0x6A88EF2e6511CAFfE2D006e260e7A5d1E7D4d7D7;
    address constant TOKEN_JAR = 0x8Dd8B6D56e4a4A158EDbBfE7f2f703B8FFC1a754;

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68_413_600);
    }

    function test_SimulateCollection() public {
        address pool = IV3Factory(FACTORY).getPool(USDT, WOKB, 3_000);
        require(pool != address(0), "USDT0/WOKB 0.30% pool not found");

        (uint128 fee0Before, uint128 fee1Before) = IV3PoolFees(pool).protocolFees();
        console.log("=== V3 protocol-fee collection rehearsal ===");
        console.log("pool", pool);
        console.log("token0", IV3PoolFees(pool).token0());
        console.log("token1", IV3PoolFees(pool).token1());
        console.log("protocol fee token0 raw before");
        console.logUint(fee0Before);
        console.log("protocol fee token1 raw before");
        console.logUint(fee1Before);

        IV3OpenFeeAdapter.CollectParams[] memory params = new IV3OpenFeeAdapter.CollectParams[](1);
        params[0] = IV3OpenFeeAdapter.CollectParams({
            pool: pool,
            amount0Requested: type(uint128).max,
            amount1Requested: type(uint128).max
        });
        IV3OpenFeeAdapter(ADAPTER).collect(params);

        uint256 jarUsdt = IERC20(USDT).balanceOf(TOKEN_JAR);
        console.log("USDT0 now in TokenJar raw");
        console.logUint(jarUsdt);
        console.log("USDT0 now in TokenJar whole");
        console.logUint(jarUsdt / 1e6);
    }
}
