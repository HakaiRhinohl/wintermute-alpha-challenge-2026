// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";
import "./Interfaces.sol";
import "./Constants.sol";

contract FallingDutchman is Test {
    address user = vm.envAddress("USER_ADDRESS");

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant KNC = 0xdd974D5C2e2928deA5F71b9825b8b646686BD200;
    address constant UNISWAP_V1_FACTORY = 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), FORK_BLOCK);
        vm.deal(user, 0.1 ether);
    }

    function test_Solution() public {
        vm.startBroadcast(user);

        // 1. Buy KNC with the 0.1 ETH supplied by the challenge.
        address kncExchange = IUniswapV1Factory(UNISWAP_V1_FACTORY).getExchange(KNC);
        IUniswapV1Exchange(kncExchange).ethToTokenSwapInput{value: 0.1 ether}(1, block.timestamp);

        // 2. Put all the KNC into DutchX. ERC-20 approval lets DutchX pull it.
        uint256 kncBalance = IERC20(KNC).balanceOf(user);
        IERC20(KNC).approve(DUTCHX, kncBalance);
        IDutchX(DUTCHX).deposit(KNC, kncBalance);

        // 3. Use that deposited KNC to buy WETH from the unusually cheap active auction.
        uint256 auctionIndex = IDutchX(DUTCHX).getAuctionIndex(WETH, KNC);
        IDutchX(DUTCHX).postBuyOrder(WETH, KNC, auctionIndex, kncBalance);

        // 4. Claim the WETH available immediately, withdraw it, then unwrap it into native ETH.
        IDutchX(DUTCHX).claimBuyerFunds(WETH, KNC, user, auctionIndex);
        IDutchX(DUTCHX).withdraw(WETH, type(uint256).max);
        IWETH(WETH).withdraw(IERC20(WETH).balanceOf(user));

        vm.stopBroadcast();
        checkSolve();
    }

    function checkSolve() public view {
        require(user.balance >= 4 ether, "not enough ETH");
        console.log("Solved. Ending balance in ETH: %18e", user.balance);
    }
}
