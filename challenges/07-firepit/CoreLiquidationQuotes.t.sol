// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

interface IQuoterV2Core {
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

/// @notice Compares executable candidate exits discovered by FeeBasketRouteGraph.
/// Every amount is taken from the actual TokenJar transfers printed by
/// FeeBasketInspector at the historical fork.  Quotes are simulations only.
contract CoreLiquidationQuotes is Test {
    address constant QUOTER_V2 = address(bytes20(hex"d1b797d92d87b688193a2b976efc8d577d204343"));

    address constant USDT0 = address(bytes20(hex"779Ded0c9e1022225f8E0630b35a9b54bE713736"));
    address constant WOKB = address(bytes20(hex"e538905cf8410324e03A5A23C1c177a474D59b2b"));
    address constant XBTC = address(bytes20(hex"b7C00000bcDEeF966b20B3D884B98E64d2b06b4f"));
    address constant XETH = address(bytes20(hex"E7B000003A45145decf8a28FC755aD5eC5EA025A"));
    address constant USDG = address(bytes20(hex"4ae46a509F6b1D9056937BA4500cb143933D2dc8"));
    address constant NIUMA = address(bytes20(hex"87669801A1FaD6DAD9dB70d27Ac752f452989667"));
    address constant WNVDAX = address(bytes20(hex"a8ddb5Cd96b5222AFe198316E9A57CAA642850D5"));
    address constant XSOL = address(bytes20(hex"505000008DE8748DBd4422ff4687a4FC9bEba15b"));
    address constant USDC = address(bytes20(hex"B6CEceAB302E2E4948951eE7843FC24E92933061"));
    address constant SATUSD = address(bytes20(hex"ceF6c74Ce218c0E1F48cA2430635D0a65Cd3737A"));
    address constant GPU = address(bytes20(hex"d624079F9062AAb098D28a05bAD2f19614e6C5Ac"));

    uint256 constant WOKB_AMOUNT = 134_299_654_224_125_748_759;
    uint256 constant XBTC_AMOUNT = 4_374_949;
    uint256 constant XETH_AMOUNT = 2_299_560_121_383_716_032;
    uint256 constant USDG_AMOUNT = 2_712_818_973;
    uint256 constant NIUMA_AMOUNT = 1_539_782_936_394_972_950_734;
    uint256 constant WNVDAX_AMOUNT = 3_283_684_166_276_647_520;
    uint256 constant XSOL_AMOUNT = 47_504_167_956;
    uint256 constant USDC_AMOUNT = 226_529_596;
    uint256 constant SATUSD_AMOUNT = 209_677_955_016_814_116;
    uint256 constant GPU_AMOUNT = 162_809_673_320_463_391_868;

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68_413_600);
    }

    function test_QuoteLargeDirectExits() public {
        console.log("=== Large direct exits into USDT0 ===");
        console.log("USDT0 already collected (raw)");
        console.logUint(26_570_237_066);

        _quote("WOKB -> USDT0, 0.01%", WOKB, USDT0, WOKB_AMOUNT, 100);
        _quote("WOKB -> USDT0, 0.05%", WOKB, USDT0, WOKB_AMOUNT, 500);
        _quote("WOKB -> USDT0, 0.30%", WOKB, USDT0, WOKB_AMOUNT, 3000);
        _quote("xBTC -> USDT0, 0.01%", XBTC, USDT0, XBTC_AMOUNT, 100);
        _quote("xBTC -> USDT0, 0.05%", XBTC, USDT0, XBTC_AMOUNT, 500);
        _quote("xETH -> USDT0, 0.05%", XETH, USDT0, XETH_AMOUNT, 500);
        _quote("USDG -> USDT0, 0.01%", USDG, USDT0, USDG_AMOUNT, 100);
    }

    function test_QuoteSecondaryDirectExits() public {
        console.log("=== Secondary direct exits into USDT0 ===");
        _quote("NIUMA -> USDT0, 0.30%", NIUMA, USDT0, NIUMA_AMOUNT, 3000);
        _quote("wNVDAx -> USDT0, 0.30%", WNVDAX, USDT0, WNVDAX_AMOUNT, 3000);
        _quote("xSOL -> USDT0, 0.05%", XSOL, USDT0, XSOL_AMOUNT, 500);
        _quote("USDC -> USDT0, 0.01%", USDC, USDT0, USDC_AMOUNT, 100);
        _quote("satUSD -> USDT0, 0.30%", SATUSD, USDT0, SATUSD_AMOUNT, 3000);
    }

    function test_QuoteAlternativePaths() public {
        console.log("=== Alternative two-hop exits ===");

        (bool xbtcUsdGOk, uint256 xbtcUsdG) = _quote("xBTC -> USDG, 0.05%", XBTC, USDG, XBTC_AMOUNT, 500);
        if (xbtcUsdGOk) _quote("xBTC -> USDG -> USDT0", USDG, USDT0, xbtcUsdG, 100);

        (bool xethUsdGOk, uint256 xethUsdG) = _quote("xETH -> USDG, 0.05%", XETH, USDG, XETH_AMOUNT, 500);
        if (xethUsdGOk) _quote("xETH -> USDG -> USDT0", USDG, USDT0, xethUsdG, 100);

        (bool usdgUsdcOk, uint256 usdgUsdc) = _quote("USDG -> USDC, 0.01%", USDG, USDC, USDG_AMOUNT, 100);
        if (usdgUsdcOk) _quote("USDG -> USDC -> USDT0", USDC, USDT0, usdgUsdc, 100);

        (bool gpuNvdaxOk, uint256 gpuNvdax) = _quote("GPU -> wNVDAx, 1%", GPU, WNVDAX, GPU_AMOUNT, 10_000);
        if (gpuNvdaxOk) _quote("GPU -> wNVDAx -> USDT0", WNVDAX, USDT0, gpuNvdax, 3000);
    }

    function _quote(string memory label, address tokenIn, address tokenOut, uint256 amountIn, uint24 fee)
        internal
        returns (bool success, uint256 amountOut)
    {
        try IQuoterV2Core(QUOTER_V2)
            .quoteExactInputSingle(
                IQuoterV2Core.QuoteExactInputSingleParams({
                    tokenIn: tokenIn, tokenOut: tokenOut, amountIn: amountIn, fee: fee, sqrtPriceLimitX96: 0
                })
            ) returns (
            uint256 quoted, uint160, uint32, uint256
        ) {
            console.log(label);
            console.log("USDT0-or-intermediate output raw");
            console.logUint(quoted);
            return (true, quoted);
        } catch (bytes memory reason) {
            console.log(label);
            console.log("quote reverted");
            console.logBytes(reason);
            return (false, 0);
        }
    }
}
