// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "./Constants.sol";

/// @dev Only the two historical Uniswap V1 read methods needed in this lesson.
interface IUniswapV1Factory {
    function getExchange(address token) external view returns (address exchange);
}

interface IUniswapV1Exchange {
    function getEthToTokenInputPrice(uint256 ethSold) external view returns (uint256 tokensBought);
}

/// @notice This test is an observation tool, not a trading solution.
/// It asks the state of Ethereum at FORK_BLOCK what 0.1 ETH could buy in KNC.
contract ExternalPriceInspector is Test {
    address constant KNC = 0xdd974D5C2e2928deA5F71b9825b8b646686BD200;
    address constant UNISWAP_V1_FACTORY = 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95;
    uint256 constant STARTING_ETH = 0.1 ether;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), FORK_BLOCK);
    }

    function test_InspectKncMarket() public view {
        address exchange = IUniswapV1Factory(UNISWAP_V1_FACTORY).getExchange(KNC);
        require(exchange != address(0), "KNC had no Uniswap V1 exchange");

        uint256 kncBought = IUniswapV1Exchange(exchange).getEthToTokenInputPrice(STARTING_ETH);

        console.log("=== External KNC market at the fork block ===");
        console.log("fork block", FORK_BLOCK);
        console.log("Uniswap V1 KNC exchange", exchange);
        console.log("input ETH (raw)", STARTING_ETH);
        console.log("KNC quote for 0.1 ETH (raw)", kncBought);
        console.log("whole KNC in quote", kncBought / 1e18);
        console.log("KNC remainder (18-decimal units)", kncBought % 1e18);
    }
}
