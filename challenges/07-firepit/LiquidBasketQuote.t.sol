// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

interface IQuoterV2 {
    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
        external
        returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate);
}

interface IV3PoolState {
    function liquidity() external view returns (uint128);
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}

/// @notice Quotes only assets already proven collectable in FeeBasketInspector.
/// The quoter simulates swaps; it does not transfer the basket or spend UNI.
contract LiquidBasketQuote is Test {
    address constant USDT0 = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736;
    address constant WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
    address constant XBTC = 0xb7C00000bcDEeF966b20B3D884B98E64d2b06b4f;
    address constant XETH = 0xE7B000003A45145decf8a28FC755aD5eC5EA025A;
    address constant USDG = 0x4ae46a509F6b1D9056937BA4500cb143933D2dc8;
    address constant AOXC = 0xeB9580c3946BB47d73AAE1d4f7A94148B554b2F4;
    address constant AOXC_USDT0_POOL = 0x1200E29A106F9e1eE5334D741A1f26346AA49aF2;
    address constant QUOTER_V2 = address(bytes20(hex"d1b797d92d87b688193a2b976efc8d577d204343"));

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68_413_600);
    }

    function test_QuoteLiquidBasketToUSDT0() public {
        console.log("=== Historical liquidation quotes into USDTe0 ===");
        console.log("USDTe0 already collected (raw)");
        console.logUint(26_570_237_066);

        uint256 wokbOut = _quote(WOKB, 134_299654224125748759, 3_000);
        uint256 xbtcOut = _quote(XBTC, 4_374_949, 500);
        uint256 xethOut = _quote(XETH, 2_299560121383716032, 500);
        uint256 usdgOut = _quote(USDG, 2_712_818_973, 100);

        uint256 total = 26_570_237_066 + wokbOut + xbtcOut + xethOut + usdgOut;
        console.log("total USDT0 after quoted liquidations (raw)");
        console.logUint(total);
        console.log("total USDT0 after quoted liquidations (whole)");
        console.logUint(total / 1e6);
    }

    /// @dev Run this test alone first: AOXC has a single direct USDT0 route
    /// in the historical PoolCreated inventory, at the 0.30% tier.
    function test_QuoteAOXCOnly() public {
        console.log("AOXC/USDT0 active liquidity");
        console.logUint(IV3PoolState(AOXC_USDT0_POOL).liquidity());
        (
            uint160 price,
            int24 ignoredTick,
            uint16 ignoredObservationIndex,
            uint16 ignoredObservationCardinality,
            uint16 ignoredObservationCardinalityNext,
            uint8 ignoredFeeProtocol,
            bool unlocked
        ) = IV3PoolState(AOXC_USDT0_POOL).slot0();
        ignoredTick;
        ignoredObservationIndex;
        ignoredObservationCardinality;
        ignoredObservationCardinalityNext;
        ignoredFeeProtocol;
        console.log("AOXC/USDT0 sqrtPriceX96");
        console.logUint(price);
        console.log("AOXC/USDT0 unlocked", unlocked);

        try IQuoterV2(QUOTER_V2).quoteExactInputSingle(
            IQuoterV2.QuoteExactInputSingleParams({
                tokenIn: AOXC,
                tokenOut: USDT0,
                amountIn: 13_142411495872273743286,
                fee: 3_000,
                sqrtPriceLimitX96: 0
            })
        ) returns (uint256 aoxcOut, uint160, uint32, uint256) {
            console.log("AOXC USDT0 output (whole)");
            console.logUint(aoxcOut / 1e6);
            uint256 deficit = 2_211_046_373;
            console.log("amount still needed after AOXC, if any (raw)");
            console.logUint(aoxcOut >= deficit ? 0 : deficit - aoxcOut);
        } catch (bytes memory reason) {
            console.log("full AOXC quote reverted; raw revert data follows");
            console.logBytes(reason);
        }
    }

    function _quote(address tokenIn, uint256 amountIn, uint24 fee) internal returns (uint256 amountOut) {
        (amountOut,,,) = IQuoterV2(QUOTER_V2).quoteExactInputSingle(
            IQuoterV2.QuoteExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: USDT0,
                amountIn: amountIn,
                fee: fee,
                sqrtPriceLimitX96: 0
            })
        );
        console.log("token in", tokenIn);
        console.log("quoted USDT0 raw out");
        console.logUint(amountOut);
    }
}
