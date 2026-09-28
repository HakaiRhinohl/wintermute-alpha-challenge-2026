// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import "./Constants.sol";
import "./Interfaces.sol";

interface ISwapRouter02Envelope {
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
        external payable returns (uint256);
}

/// @notice Shows the L1 retryable-ticket envelope without relaying it to L2.
contract InboxEnvelopeInspector is Test {
    address user = vm.envAddress("USER_ADDRESS");
    address constant ROLLUP = 0x23A19d23e89166adedbDcB432518AB01e4272D94;
    address constant SWAP_ROUTER = 0xCaf681a66D020601342297493863E78C959E5cb2;
    address constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;

    function test_InspectEnvelope() public {
        uint256 l1Fork = vm.createFork(vm.envString("ETH_RPC_URL"), L1_FORK_BLOCK);
        vm.selectFork(l1Fork);
        vm.deal(user, 10 ether);
        vm.prank(ROLLUP);
        IInbox(INBOX).setAllowListEnabled(false);

        uint256 l2CallValue = 0.20 ether;
        bytes memory l2Calldata = abi.encodeWithSelector(
            ISwapRouter02Envelope.exactInputSingle.selector,
            ISwapRouter02Envelope.ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: CASHCAT,
                fee: 10_000,
                recipient: user,
                amountIn: l2CallValue,
                amountOutMinimum: 1_000_000e18,
                sqrtPriceLimitX96: 0
            })
        );

        uint256 gasLimit = 500_000;
        uint256 maxFeePerGas = 1 gwei;
        uint256 submissionCost = IInbox(INBOX).calculateRetryableSubmissionFee(
            l2Calldata.length, block.basefee
        );
        uint256 l1Value = l2CallValue + submissionCost + gasLimit * maxFeePerGas;

        vm.recordLogs();
        vm.prank(user);
        IInbox(INBOX).createRetryableTicket{value: l1Value}(
            SWAP_ROUTER,
            l2CallValue,
            submissionCost,
            user,
            user,
            gasLimit,
            maxFeePerGas,
            l2Calldata
        );

        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != INBOX) continue;
            bytes memory message = abi.decode(logs[i].data, (bytes));
            console.log("=== retryable-ticket envelope ===");
            console.log("L1 ETH attached", l1Value);
            console.log("submission fee", submissionCost);
            console.log("retryable gas budget", gasLimit * maxFeePerGas);
            console.log("L2 destination", address(uint160(_word(message, 0))));
            console.log("L2 call value", _word(message, 1));
            console.log("embedded calldata bytes", _word(message, 8));
        }
    }

    function _word(bytes memory data, uint256 index) private pure returns (uint256 value) {
        assembly {
            value := mload(add(add(data, 32), mul(index, 32)))
        }
    }
}
