// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

interface IV3FactoryGraph {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IV3PoolGraph {
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

/// @notice Finds executable *candidate routes* for the valuable tokens already
/// collected from the USDT0-pool reconnaissance.  It does not assume that a
/// pool which earned fees is also a usable place to sell the token.
contract FeeBasketRouteGraph is Test {
    address constant FACTORY = 0x4B2ab38DBF28D31D467aA8993f6c2585981D6804;

    uint24[4] internal TIERS = [uint24(100), 500, 3000, 10_000];

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68_413_600);
    }

    function test_FindLiquidRoutesInsideTheFeeBasket() public view {
        address[] memory tokens = _tokens();
        string[] memory names = _names();
        IV3FactoryGraph factory = IV3FactoryGraph(FACTORY);

        console.log("=== Liquid route graph at the challenge fork ===");
        console.log("Only edges with non-zero active V3 liquidity are printed.");

        uint256 edges;
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                for (uint256 k; k < TIERS.length; ++k) {
                    address pool = factory.getPool(tokens[i], tokens[j], TIERS[k]);
                    if (pool == address(0)) continue;

                    uint128 activeLiquidity = IV3PoolGraph(pool).liquidity();
                    if (activeLiquidity == 0) continue;

                    (,,,,,, bool unlocked) = IV3PoolGraph(pool).slot0();
                    if (!unlocked) continue;

                    ++edges;
                    console.log("edge", names[i], names[j]);
                    console.log("pool", pool);
                    console.log("fee tier", TIERS[k]);
                    console.log("active liquidity");
                    console.logUint(activeLiquidity);
                }
            }
        }
        console.log("liquid edges found", edges);
    }

    function _tokens() internal pure returns (address[] memory tokens) {
        tokens = new address[](13);
        tokens[0] = address(bytes20(hex"779Ded0c9e1022225f8E0630b35a9b54bE713736")); // USDT0
        tokens[1] = address(bytes20(hex"e538905cf8410324e03A5A23C1c177a474D59b2b")); // WOKB
        tokens[2] = address(bytes20(hex"b7C00000bcDEeF966b20B3D884B98E64d2b06b4f")); // xBTC
        tokens[3] = address(bytes20(hex"E7B000003A45145decf8a28FC755aD5eC5EA025A")); // xETH
        tokens[4] = address(bytes20(hex"4ae46a509F6b1D9056937BA4500cb143933D2dc8")); // USDG
        tokens[5] = address(bytes20(hex"eB9580c3946BB47d73AAE1d4f7A94148B554b2F4")); // AOXC
        tokens[6] = address(bytes20(hex"87669801A1FaD6DAD9dB70d27Ac752f452989667")); // NIUMA
        tokens[7] = address(bytes20(hex"d624079F9062AAb098D28a05bAD2f19614e6C5Ac")); // GPU
        tokens[8] = address(bytes20(hex"a8ddb5Cd96b5222AFe198316E9A57CAA642850D5")); // wNVDAx
        tokens[9] = address(bytes20(hex"505000008DE8748DBd4422ff4687a4FC9bEba15b")); // xSOL
        tokens[10] = address(bytes20(hex"B6CEceAB302E2E4948951eE7843FC24E92933061")); // USDC
        tokens[11] = address(bytes20(hex"ceF6c74Ce218c0E1F48cA2430635D0a65Cd3737A")); // satUSD
        tokens[12] = address(bytes20(hex"5A77f1443D16ee5761d310e38b62f77f726bC71c")); // WETH
    }

    function _names() internal pure returns (string[] memory names) {
        names = new string[](13);
        names[0] = "USDT0";
        names[1] = "WOKB";
        names[2] = "xBTC";
        names[3] = "xETH";
        names[4] = "USDG";
        names[5] = "AOXC";
        names[6] = "NIUMA";
        names[7] = "GPU";
        names[8] = "wNVDAx";
        names[9] = "xSOL";
        names[10] = "USDC";
        names[11] = "satUSD";
        names[12] = "WETH";
    }
}
