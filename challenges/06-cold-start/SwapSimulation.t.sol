// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";
import "./Constants.sol";

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}

/// @notice A disposable fork simulation of the L2 call we plan to deliver.
/// No Ethereum Inbox message is posted here; each test run starts from the
/// historical fork again, so the swap leaves no persistent state behind.
contract SwapSimulation is Test {
    uint256 l2Fork;
    address user = vm.envAddress("USER_ADDRESS");
    address constant SWAP_ROUTER = 0xCaf681a66D020601342297493863E78C959E5cb2;
    address constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
    uint24 constant POOL_FEE = 10_000;

    function setUp() public {
        l2Fork = vm.createFork(vm.envString("ROBINHOOD_RPC_URL"), L2_FORK_BLOCK);
        vm.selectFork(l2Fork);
    }

    function test_SimulateInnerL2Call() public {
        address alias_ = address(uint160(user) + uint160(0x1111000000000000000000000000000000001111));
        uint256 amountIn = 0.20 ether;
        uint256 beforeBalance = IERC20(CASHCAT).balanceOf(user);

        // This models `_relay`: the L2 call is from the aliased sender and
        // carries ETH. The router wraps that ETH to WETH internally.
        vm.deal(alias_, amountIn);
        vm.prank(alias_);
        uint256 amountOut = ISwapRouter(SWAP_ROUTER).exactInputSingle{value: amountIn}(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: CASHCAT,
                fee: POOL_FEE,
                recipient: user,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        uint256 received = IERC20(CASHCAT).balanceOf(user) - beforeBalance;
        console.log("=== L2 swap simulation ===");
        console.log("ETH sent to router", amountIn);
        console.log("router amount out raw", amountOut);
        console.log("CASHCAT received raw", received);
        console.log("CASHCAT received whole", received / 1e18);
    }
}
