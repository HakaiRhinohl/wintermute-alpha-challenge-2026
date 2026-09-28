// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";

/// @notice Permissionless adapter used by the Uniswap fee system.
interface IOpenFeeAdapter {
    struct CollectParams {
        address pool;
        uint128 amount0Requested;
        uint128 amount1Requested;
    }

    function collect(CollectParams[] calldata collectParams) external;
}

/// @notice In the releaser source this is `Currency[]`; Currency is an
/// address-sized value type, therefore `address[]` has identical ABI encoding.
interface IExchangeReleaser {
    function release(uint256 nonce, address[] calldata assets, address recipient) external;
}

interface IV3SwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract Firepit is Test {
    address user = vm.envAddress("USER_ADDRESS");

    address constant UNI = 0x57FB37d035e6Ad0E687E0a50dC3F515691deB815;
    address constant USDT0 = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736;
    address constant ADAPTER = 0x6A88EF2e6511CAFfE2D006e260e7A5d1E7D4d7D7;
    address constant FIREPIT = 0xe122E231cb52aea99690963Fd73E91e33E97468f;
    address constant ROUTER = address(bytes20(hex"4f0c28f5926afda16bf2506d5d9e57ea190f9bca"));

    address constant WOKB = address(bytes20(hex"e538905cf8410324e03a5a23c1c177a474d59b2b"));
    address constant XBTC = address(bytes20(hex"b7c00000bcdeef966b20b3d884b98e64d2b06b4f"));
    address constant USDG = address(bytes20(hex"4ae46a509f6b1d9056937ba4500cb143933d2dc8"));

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68_413_600);
        vm.etch(0x4200000000000000000000000000000000000010, hex"60006000f3");
        deal(UNI, user, 2000e18);
    }

    function test_Solution() public {
        vm.startPrank(user);

        // 1. Anyone may sweep the protocol fees. Calls are independent so the
        // one pool returning LOK cannot undo the other successful collections.
        _collectFees();

        // 2. Spend the 2,000 UNI threshold and select only assets with a
        // measured liquid exit. xETH stays in the TokenJar by choice: releasing
        // it is optional, and its direct exit is extremely illiquid at this fork.
        IERC20(UNI).approve(FIREPIT, 2000e18);
        address[] memory assets = new address[](4);
        assets[0] = USDT0;
        assets[1] = WOKB;
        assets[2] = XBTC;
        assets[3] = USDG;
        IExchangeReleaser(FIREPIT).release(0, assets, user);

        // 3. Sell the released non-USDT assets through the best direct routes
        // measured at the fork. A live trade would use quote-derived min-outs;
        // zero is appropriate only for this deterministic historical exercise.
        _swapAll(WOKB, 500); // WOKB/USDT0, 0.05%
        _swapAll(XBTC, 100); // xBTC/USDT0, 0.01%
        _swapAll(USDG, 100); // USDG/USDT0, 0.01%

        vm.stopPrank();
        checkSolve();
    }

    function _swapAll(address tokenIn, uint24 fee) internal {
        uint256 amountIn = IERC20(tokenIn).balanceOf(user);
        if (amountIn == 0) return;

        IERC20(tokenIn).approve(ROUTER, amountIn);
        IV3SwapRouter(ROUTER)
            .exactInputSingle(
                IV3SwapRouter.ExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: USDT0,
                    fee: fee,
                    recipient: user,
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );
    }

    function _collectFees() internal {
        address[] memory pools = _candidatePools();
        for (uint256 i; i < pools.length; ++i) {
            IOpenFeeAdapter.CollectParams[] memory params = new IOpenFeeAdapter.CollectParams[](1);
            params[0] = IOpenFeeAdapter.CollectParams({
                pool: pools[i], amount0Requested: type(uint128).max, amount1Requested: type(uint128).max
            });
            try IOpenFeeAdapter(ADAPTER).collect(params) {} catch {}
        }
    }

    /// @dev Factory PoolCreated logs through the fork, filtered for USDT0 as
    /// either token. The packed form keeps the solution readable above.
    function _candidatePools() internal pure returns (address[] memory pools) {
        bytes memory packed =
            hex"63d62734847e55a266fca4219a9ad0a02d5f6e025fcfb33c9ab1665fee892eb2af163e863a874d739e485cc2ec10e87a9b6e58602889df392b7f6453e3be6a0137f1b0602fc1a4841686f43b340a508277ef18adf35f62b2ad442e4370cdbc7fe78b7dcc849aea45a38e0ee2459be4cec52cb5d73bfc57611200e29a106f9e1ee5334d741a1f26346aa49af22b702e9d8925251eb7e59950cc22e4110750d59d75255002fec0e917bf3c8fb588c4c0218460ec5c3e832e40fc59062c0fb6994cad7fbe54cfb2768d805c404d40c8c1f470c3c078f70a30b1b87464604a17bda067c9a824a3aac43e1b688315744410ea89fed5b8f1378e6adf96472c95dd391b01992d3f5f2233457c93d3b17cadc4ef99042dd5c608ba8bea12abced99c5f1c951b391a406a4816f022fb4173d74d0745057873dfa8c2a0560f7944410d8272277e7dd1b3642b4e34dd9d97093688071809c9588f4e0c0602e071ad2d11c591f41a8a948b859aa0313d96ebdff7cdb597c45b7c41ed5e74a1c50814b2275ef9be7835dc7bd2196da76a5267311cfb821598889895752de04cb12d23ef60fc7ca79079226cf6a073dddd6fdd74b1b9f149621e85f01aacb95539be38f9fa8ee76ae7cb77f66d87c42bc35705dc5df853a89ac964b94abf46dad8ab536fd8c2cf20f9ee5455d5cbdab8b310de8c7968858a067f4ceeeb3c1f61dc3070c675c2670a3f2188a060012da094c31e5be6406163b5b67d82b49b478692af5266d18056c9ce5e9164a2f7fe92d30072ec5201b152a36606d26acb07aaa105bc285bb43279fc601eed7ac259da1eb90c77e007e01c220b25df1b0030941a4e58755a5fec66a5134d5799dd261dd62176c247a01c1428ad65810650063a026b8884d122ff292a28c5a775d7d6db2af7981e4e070cc0f6a3a3a575234cc82be1dd41d133ca33e879287d6751a0cb096d1f87a105709629ceb3d60dbf842c8ebe96ead65dc8da6a93c1f18a0bc22f2b90e47c25f572e5dd009eb81b150ba306a01d2096d7523093f662b87139329b0fb33e5d29036fa1292af5a9053eb6b63b6c848b89de0a80ac0a9f1a8033292684116745d0ed1e574d574f5726fed4b5acfbdc95675d109d138b1e5ced5e38cc906538d7f67784ed8413e60a6be92d8b015e626a9f81526c3cbd65176d662a8978d46a21e2a9ecfb34d8c1b63d061a198c7a91ce7b8e36bde4edb5161244d62a91689618f5d087894cfaa2dfe6f257caf7ca2c65a1a49028d6d43b232a6679ea123ea8dea06d6caa707ec337400871802c2b4b97f0835cb06b55e3addcefa03b88fa3fa10f7ce05b9149a3c91261d4dbb13fbf8f632a0f93b2e507fffc810e35e2981efdee68dc1377c4304651300221f345a4c6f566079bd1ddc291049c7d0cbe0dbe1400e57f371a38bd3b9bc80f7c3676da645d981a004036346c7f44c53f569580d383f29cb524efba890ed7087a4188b9b0148eb7fb954da96d8cbf53b42195c2e924087ca1ac9bbd2eca6042b864f203fc61acea1f4c98cf80a6e59132e079af7c8c5e085ce308093ead0a52c94161a24ab2c617e3efb3e9db557240da1c6d84c25e19806d8f15c668e7e2204a4bf67f7fe6f98777bf128a9f69d6b3258e56f87273e1103999201a116dadfd25f93d83aac7e6cfbbb93e00f68d257e2592760207f179ff9a04935e89793e0340b32314591f7dcedc5f9466c19f5db3551ced3bc41f83edf77730ec276c731c97b990141409686c4ba78a0509faf9f860b11387637986a6cee97e1f3e3a9a2b01a01c6327da0869cff7b66459b610d1f8e04a0c254657e840df0f138cd4e9edc09d2c186048005db2f753fc8088c482c4ec18043977b63249e1983bfe0cfd030cc004597f8538a5de9dc71c44bf048df5006dff13344289a266be7c9f22ad71f1a5aa169e22bc88f78e655c5e32f41ac751c3ff17c4f79c4bdc8947c36ebf8caa21bf5b5322b9c7b6f6e1e24f284ba80e18adf6ce8ff48eeafa516e615251e9cbcc23db66f80f6cb950aca3c8af801156a105fdff78162b1ee692092cd2533a86c4dab3d203e02b5996c09d35203b68ae045ae0ac018be3bf4219a67775458d59a025a78be3d6ad021f59758dc3ad73aa7f30e6827eae38";
        pools = new address[](packed.length / 20);
        for (uint256 i; i < pools.length; ++i) {
            address pool;
            assembly {
                pool := shr(96, mload(add(add(packed, 0x20), mul(i, 20))))
            }
            pools[i] = pool;
        }
    }

    function checkSolve() public view {
        require(IERC20(USDT0).balanceOf(user) >= 45_000e6, "not enough USDT");
        console.log("Firepit solved. USDT: %6e", IERC20(USDT0).balanceOf(user));
    }
}
