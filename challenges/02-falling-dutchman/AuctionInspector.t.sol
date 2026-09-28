// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "./Constants.sol";

/// @dev The small read-only slice of the DutchX ABI needed for this lesson.
interface IDutchXAuctionView {
    function getAuctionIndex(address token1, address token2) external view returns (uint256);
    function getAuctionStart(address token1, address token2) external view returns (uint256);
    function getCurrentAuctionPrice(address sellToken, address buyToken, uint256 auctionIndex)
        external
        view
        returns (uint256 num, uint256 den);
    function getPriceInPastAuction(address token1, address token2, uint256 auctionIndex)
        external
        view
        returns (uint256 num, uint256 den);
    function sellVolumesCurrent(address sellToken, address buyToken) external view returns (uint256);
    function buyVolumes(address sellToken, address buyToken) external view returns (uint256);
    function getClearingTime(address token1, address token2, uint256 auctionIndex) external view returns (uint256);
}

contract AuctionInspector is Test {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant KNC = 0xdd974D5C2e2928deA5F71b9825b8b646686BD200;
    uint256 constant EXPECTED_AUCTION = 1051;

    IDutchXAuctionView constant EXCHANGE = IDutchXAuctionView(DUTCHX);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), FORK_BLOCK);
    }

    function test_InspectAuction() public view {
        uint256 auctionIndex = EXCHANGE.getAuctionIndex(WETH, KNC);
        uint256 auctionStart = EXCHANGE.getAuctionStart(WETH, KNC);
        (uint256 currentNum, uint256 currentDen) = EXCHANGE.getCurrentAuctionPrice(WETH, KNC, auctionIndex);
        (uint256 previousNum, uint256 previousDen) = EXCHANGE.getPriceInPastAuction(WETH, KNC, auctionIndex - 1);
        uint256 sellVolume = EXCHANGE.sellVolumesCurrent(WETH, KNC);
        uint256 buyVolume = EXCHANGE.buyVolumes(WETH, KNC);
        uint256 clearingTime = EXCHANGE.getClearingTime(WETH, KNC, auctionIndex);

        console.log("=== DutchX historical auction inspector ===");
        console.log("fork block", FORK_BLOCK);
        console.log("auction index", auctionIndex);
        console.log("auction start (Unix seconds)", auctionStart);
        console.log("current price numerator", currentNum);
        console.log("current price denominator", currentDen);
        console.log("previous closing price numerator", previousNum);
        console.log("previous closing price denominator", previousDen);
        console.log("current WETH sell volume (raw)", sellVolume);
        console.log("current KNC buy volume (raw)", buyVolume);
        console.log("clearing time (0 means not cleared)", clearingTime);

        require(auctionIndex == EXPECTED_AUCTION, "unexpected historical auction index");
    }
}
