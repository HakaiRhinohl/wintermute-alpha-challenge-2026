// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/Test.sol";
import {IERC20} from "../../src/Interfaces.sol";
import {Firepit, IExchangeReleaser} from "./Solution.t.sol";

/// @notice A screenshot-friendly, fork-only evidence run for Case 07.
///
/// It inherits the final solution's pool set and collection code, but logs the
/// three economic checkpoints in a compact form. The displayed numbers are
/// calculated during this test run, not copied from the article.
contract FirepitEvidenceSummary is Firepit {
    address constant TOKEN_JAR = 0x8Dd8B6D56e4a4A158EDbBfE7f2f703B8FFC1a754;
    address constant XETH = 0xE7B000003A45145decf8a28FC755aD5eC5EA025A;

    function test_EvidenceSummary() public {
        vm.startPrank(user);

        uint256 jarUsdtBefore = IERC20(USDT0).balanceOf(TOKEN_JAR);
        uint256 jarWokbBefore = IERC20(WOKB).balanceOf(TOKEN_JAR);
        uint256 jarXbtcBefore = IERC20(XBTC).balanceOf(TOKEN_JAR);
        uint256 jarXethBefore = IERC20(XETH).balanceOf(TOKEN_JAR);
        uint256 jarUsdgBefore = IERC20(USDG).balanceOf(TOKEN_JAR);

        _collectFees();

        uint256 collectedUsdt = IERC20(USDT0).balanceOf(TOKEN_JAR) - jarUsdtBefore;
        uint256 collectedWokb = IERC20(WOKB).balanceOf(TOKEN_JAR) - jarWokbBefore;
        uint256 collectedXbtc = IERC20(XBTC).balanceOf(TOKEN_JAR) - jarXbtcBefore;
        uint256 collectedXeth = IERC20(XETH).balanceOf(TOKEN_JAR) - jarXethBefore;
        uint256 collectedUsdg = IERC20(USDG).balanceOf(TOKEN_JAR) - jarUsdgBefore;

        console.log("=== Assets collected into TokenJar ===");
        console.log("Asset   | Amount collected");
        console.log(string.concat("USDTe0  | ", _format2(collectedUsdt, 6)));
        console.log(string.concat("WOKB    | ", _format2(collectedWokb, 18)));
        console.log(string.concat("xBTC    | ", _format2(collectedXbtc, 8)));
        console.log(string.concat("xETH    | ", _format2(collectedXeth, 18)));
        console.log(string.concat("USDG    | ", _format2(collectedUsdg, 6)));

        IERC20(UNI).approve(FIREPIT, 2_000e18);
        address[] memory assets = new address[](4);
        assets[0] = USDT0;
        assets[1] = WOKB;
        assets[2] = XBTC;
        assets[3] = USDG;
        IExchangeReleaser(FIREPIT).release(0, assets, user);

        uint256 directUsdt = IERC20(USDT0).balanceOf(user);

        uint256 beforeWokbSwap = IERC20(USDT0).balanceOf(user);
        _swapAll(WOKB, 500);
        uint256 wokbOut = IERC20(USDT0).balanceOf(user) - beforeWokbSwap;

        uint256 beforeXbtcSwap = IERC20(USDT0).balanceOf(user);
        _swapAll(XBTC, 100);
        uint256 xbtcOut = IERC20(USDT0).balanceOf(user) - beforeXbtcSwap;

        uint256 beforeUsdgSwap = IERC20(USDT0).balanceOf(user);
        _swapAll(USDG, 100);
        uint256 usdgOut = IERC20(USDT0).balanceOf(user) - beforeUsdgSwap;

        console.log("=== Liquidation routes selected ===");
        console.log("Route           | Fee tier | USDTe0 output");
        console.log(string.concat("WOKB -> USDTe0  | 0.05%    | ", _format2(wokbOut, 6)));
        console.log(string.concat("xBTC -> USDTe0  | 0.01%    | ", _format2(xbtcOut, 6)));
        console.log(string.concat("USDG -> USDTe0  | 0.01%    | ", _format2(usdgOut, 6)));

        console.log("=== Final USDTe0 balance ===");
        console.log(string.concat("USDTe0 collected directly: ", _format2(directUsdt, 6)));
        console.log(string.concat("WOKB liquidation:          ", _format2(wokbOut, 6)));
        console.log(string.concat("xBTC liquidation:          ", _format2(xbtcOut, 6)));
        console.log(string.concat("USDG liquidation:          ", _format2(usdgOut, 6)));
        console.log("-------------------------------------------");
        console.log(string.concat("Final USDTe0:              ", _format2(IERC20(USDT0).balanceOf(user), 6)));

        vm.stopPrank();
    }

    function _format2(uint256 value, uint8 decimals) private view returns (string memory) {
        uint256 scale = 10 ** decimals;
        uint256 cents = (value % scale) * 100 / scale;
        return string.concat(vm.toString(value / scale), ".", _leftPad(vm.toString(cents), 2));
    }

    function _leftPad(string memory raw, uint8 width) private pure returns (string memory) {
        bytes memory input = bytes(raw);
        bytes memory output = new bytes(width);
        uint256 offset = uint256(width) - input.length;
        for (uint256 i; i < offset; ++i) output[i] = "0";
        for (uint256 i; i < input.length; ++i) output[offset + i] = input[i];
        return string(output);
    }
}
