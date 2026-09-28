// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import "../../src/Interfaces.sol";
import "./Interfaces.sol";
import "./Constants.sol";

interface ISwapRouter02 {
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

contract ColdStart is Test {
    address user = vm.envAddress("USER_ADDRESS");

    uint256 l1Fork;
    uint256 l2Fork;
    address constant ROLLUP = 0x23A19d23e89166adedbDcB432518AB01e4272D94;
    address constant SWAP_ROUTER = 0xCaf681a66D020601342297493863E78C959E5cb2;
    address constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
    bool relayed;

    function setUp() public {
        l1Fork = vm.createFork(vm.envString("ETH_RPC_URL"), L1_FORK_BLOCK);
        string memory l2url = vm.envOr("ROBINHOOD_RPC_URL", string(""));
        require(bytes(l2url).length > 0, "set ROBINHOOD_RPC_URL in .env");
        l2Fork = vm.createFork(l2url, L2_FORK_BLOCK);

        vm.selectFork(l1Fork);
        vm.deal(user, 10 ether);
        vm.prank(ROLLUP);
        IInbox(INBOX).setAllowListEnabled(false);
    }

    function test_Solution() public {
        vm.selectFork(l1Fork);
        vm.recordLogs();
        vm.startBroadcast(user);

        // The payload that will execute on Robinhood Chain after relaying.
        uint256 l2CallValue = 0.20 ether;
        bytes memory l2Calldata = abi.encodeWithSelector(
            ISwapRouter02.exactInputSingle.selector,
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: CASHCAT,
                fee: 10_000,
                recipient: user,
                amountIn: l2CallValue,
                amountOutMinimum: 1_000_000e18,
                sqrtPriceLimitX96: 0
            })
        );

        // A retryable ticket has three distinct ETH components: the value that
        // reaches L2, the L1 submission fee, and the L2 gas budget.
        uint256 gasLimit = 500_000;
        uint256 maxFeePerGas = 1 gwei;
        uint256 submissionCost = IInbox(INBOX).calculateRetryableSubmissionFee(
            l2Calldata.length, block.basefee
        );
        uint256 l1Value = l2CallValue + submissionCost + gasLimit * maxFeePerGas;

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

        vm.stopBroadcast();

        _relay();
        checkSolve();
    }

    // Executes every L1->L2 message you posted, on the L2, as your aliased
    // address, standing in for the sequencer. Do not edit.
    function _relay() internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        address alias_ = address(uint160(user) + uint160(0x1111000000000000000000000000000000001111));
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != INBOX) continue;
            bytes memory m = abi.decode(logs[i].data, (bytes));
            if (m.length < 288) continue;
            address to = address(uint160(_word(m, 0)));
            uint256 l2CallValue = _word(m, 1);
            uint256 len = _word(m, 8);
            bytes memory cd = new bytes(len);
            for (uint256 k = 0; k < len; k++) cd[k] = m[288 + k];

            vm.selectFork(l2Fork);
            vm.deal(alias_, alias_.balance + l2CallValue);
            vm.prank(alias_);
            (bool ok,) = to.call{value: l2CallValue}(cd);
            ok;
            relayed = true;
        }
    }

    function checkSolve() public view {
        require(relayed, "you never posted a message to the inbox");
        require(IERC20(CASHCAT).balanceOf(user) >= 1_000_000e18, "not enough CASHCAT");
        console.log("Cold Start solved. CASHCAT: %18e", IERC20(CASHCAT).balanceOf(user));
    }

    function _word(bytes memory m, uint256 i) private pure returns (uint256 v) {
        assembly {
            v := mload(add(add(m, 32), mul(i, 32)))
        }
    }
}
