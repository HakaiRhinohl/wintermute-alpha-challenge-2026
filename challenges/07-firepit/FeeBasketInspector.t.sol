// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";

interface IV3FeeCollector {
    struct CollectParams {
        address pool;
        uint128 amount0Requested;
        uint128 amount1Requested;
    }

    function collect(CollectParams[] calldata collectParams) external;
}

interface IERC20Metadata {
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface IV3PoolMetadata {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
}

/// @notice Rehearses collecting every USDT0-pool candidate found by the
/// historical event scan. This runs only on the local fork.
contract FeeBasketInspector is Test {
    address constant ADAPTER = 0x6A88EF2e6511CAFfE2D006e260e7A5d1E7D4d7D7;
    address constant TOKEN_JAR = 0x8Dd8B6D56e4a4A158EDbBfE7f2f703B8FFC1a754;
    address constant USDT0 = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736;
    address constant WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
    address constant XBTC = 0xb7C00000bcDEeF966b20B3D884B98E64d2b06b4f;
    address constant XETH = 0xE7B000003A45145decf8a28FC755aD5eC5EA025A;
    address constant USDG = 0x4ae46a509F6b1D9056937BA4500cb143933D2dc8;
    address constant AOXC = 0xeB9580c3946BB47d73AAE1d4f7A94148B554b2F4;
    address constant XSOL = 0x505000008DE8748DBd4422ff4687a4FC9bEba15b;
    bytes32 constant TRANSFER = keccak256("Transfer(address,address,uint256)");

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68_413_600);
    }

    function test_InspectCollectableBasket() public {
        address[] memory pools = new address[](76);
        pools[0] = address(bytes20(hex"63d62734847e55a266fca4219a9ad0a02d5f6e02"));
        pools[1] = address(bytes20(hex"5fcfb33c9ab1665fee892eb2af163e863a874d73"));
        pools[2] = address(bytes20(hex"9e485cc2ec10e87a9b6e58602889df392b7f6453"));
        pools[3] = address(bytes20(hex"e3be6a0137f1b0602fc1a4841686f43b340a5082"));
        pools[4] = address(bytes20(hex"77ef18adf35f62b2ad442e4370cdbc7fe78b7dcc"));
        pools[5] = address(bytes20(hex"849aea45a38e0ee2459be4cec52cb5d73bfc5761"));
        pools[6] = address(bytes20(hex"1200e29a106f9e1ee5334d741a1f26346aa49af2"));
        pools[7] = address(bytes20(hex"2b702e9d8925251eb7e59950cc22e4110750d59d"));
        pools[8] = address(bytes20(hex"75255002fec0e917bf3c8fb588c4c0218460ec5c"));
        pools[9] = address(bytes20(hex"3e832e40fc59062c0fb6994cad7fbe54cfb2768d"));
        pools[10] = address(bytes20(hex"805c404d40c8c1f470c3c078f70a30b1b8746460"));
        pools[11] = address(bytes20(hex"4a17bda067c9a824a3aac43e1b688315744410ea"));
        pools[12] = address(bytes20(hex"89fed5b8f1378e6adf96472c95dd391b01992d3f"));
        pools[13] = address(bytes20(hex"5f2233457c93d3b17cadc4ef99042dd5c608ba8b"));
        pools[14] = address(bytes20(hex"ea12abced99c5f1c951b391a406a4816f022fb41"));
        pools[15] = address(bytes20(hex"73d74d0745057873dfa8c2a0560f7944410d8272"));
        pools[16] = address(bytes20(hex"277e7dd1b3642b4e34dd9d97093688071809c958"));
        pools[17] = address(bytes20(hex"8f4e0c0602e071ad2d11c591f41a8a948b859aa0"));
        pools[18] = address(bytes20(hex"313d96ebdff7cdb597c45b7c41ed5e74a1c50814"));
        pools[19] = address(bytes20(hex"b2275ef9be7835dc7bd2196da76a5267311cfb82"));
        pools[20] = address(bytes20(hex"1598889895752de04cb12d23ef60fc7ca7907922"));
        pools[21] = address(bytes20(hex"6cf6a073dddd6fdd74b1b9f149621e85f01aacb9"));
        pools[22] = address(bytes20(hex"5539be38f9fa8ee76ae7cb77f66d87c42bc35705"));
        pools[23] = address(bytes20(hex"dc5df853a89ac964b94abf46dad8ab536fd8c2cf"));
        pools[24] = address(bytes20(hex"20f9ee5455d5cbdab8b310de8c7968858a067f4c"));
        pools[25] = address(bytes20(hex"eeeb3c1f61dc3070c675c2670a3f2188a060012d"));
        pools[26] = address(bytes20(hex"a094c31e5be6406163b5b67d82b49b478692af52"));
        pools[27] = address(bytes20(hex"66d18056c9ce5e9164a2f7fe92d30072ec5201b1"));
        pools[28] = address(bytes20(hex"52a36606d26acb07aaa105bc285bb43279fc601e"));
        pools[29] = address(bytes20(hex"ed7ac259da1eb90c77e007e01c220b25df1b0030"));
        pools[30] = address(bytes20(hex"941a4e58755a5fec66a5134d5799dd261dd62176"));
        pools[31] = address(bytes20(hex"c247a01c1428ad65810650063a026b8884d122ff"));
        pools[32] = address(bytes20(hex"292a28c5a775d7d6db2af7981e4e070cc0f6a3a3"));
        pools[33] = address(bytes20(hex"a575234cc82be1dd41d133ca33e879287d6751a0"));
        pools[34] = address(bytes20(hex"cb096d1f87a105709629ceb3d60dbf842c8ebe96"));
        pools[35] = address(bytes20(hex"ead65dc8da6a93c1f18a0bc22f2b90e47c25f572"));
        pools[36] = address(bytes20(hex"e5dd009eb81b150ba306a01d2096d7523093f662"));
        pools[37] = address(bytes20(hex"b87139329b0fb33e5d29036fa1292af5a9053eb6"));
        pools[38] = address(bytes20(hex"b63b6c848b89de0a80ac0a9f1a80332926841167"));
        pools[39] = address(bytes20(hex"45d0ed1e574d574f5726fed4b5acfbdc95675d10"));
        pools[40] = address(bytes20(hex"9d138b1e5ced5e38cc906538d7f67784ed8413e6"));
        pools[41] = address(bytes20(hex"0a6be92d8b015e626a9f81526c3cbd65176d662a"));
        pools[42] = address(bytes20(hex"8978d46a21e2a9ecfb34d8c1b63d061a198c7a91"));
        pools[43] = address(bytes20(hex"ce7b8e36bde4edb5161244d62a91689618f5d087"));
        pools[44] = address(bytes20(hex"894cfaa2dfe6f257caf7ca2c65a1a49028d6d43b"));
        pools[45] = address(bytes20(hex"232a6679ea123ea8dea06d6caa707ec337400871"));
        pools[46] = address(bytes20(hex"802c2b4b97f0835cb06b55e3addcefa03b88fa3f"));
        pools[47] = address(bytes20(hex"a10f7ce05b9149a3c91261d4dbb13fbf8f632a0f"));
        pools[48] = address(bytes20(hex"93b2e507fffc810e35e2981efdee68dc1377c430"));
        pools[49] = address(bytes20(hex"4651300221f345a4c6f566079bd1ddc291049c7d"));
        pools[50] = address(bytes20(hex"0cbe0dbe1400e57f371a38bd3b9bc80f7c3676da"));
        pools[51] = address(bytes20(hex"645d981a004036346c7f44c53f569580d383f29c"));
        pools[52] = address(bytes20(hex"b524efba890ed7087a4188b9b0148eb7fb954da9"));
        pools[53] = address(bytes20(hex"6d8cbf53b42195c2e924087ca1ac9bbd2eca6042"));
        pools[54] = address(bytes20(hex"b864f203fc61acea1f4c98cf80a6e59132e079af"));
        pools[55] = address(bytes20(hex"7c8c5e085ce308093ead0a52c94161a24ab2c617"));
        pools[56] = address(bytes20(hex"e3efb3e9db557240da1c6d84c25e19806d8f15c6"));
        pools[57] = address(bytes20(hex"68e7e2204a4bf67f7fe6f98777bf128a9f69d6b3"));
        pools[58] = address(bytes20(hex"258e56f87273e1103999201a116dadfd25f93d83"));
        pools[59] = address(bytes20(hex"aac7e6cfbbb93e00f68d257e2592760207f179ff"));
        pools[60] = address(bytes20(hex"9a04935e89793e0340b32314591f7dcedc5f9466"));
        pools[61] = address(bytes20(hex"c19f5db3551ced3bc41f83edf77730ec276c731c"));
        pools[62] = address(bytes20(hex"97b990141409686c4ba78a0509faf9f860b11387"));
        pools[63] = address(bytes20(hex"637986a6cee97e1f3e3a9a2b01a01c6327da0869"));
        pools[64] = address(bytes20(hex"cff7b66459b610d1f8e04a0c254657e840df0f13"));
        pools[65] = address(bytes20(hex"8cd4e9edc09d2c186048005db2f753fc8088c482"));
        pools[66] = address(bytes20(hex"c4ec18043977b63249e1983bfe0cfd030cc00459"));
        pools[67] = address(bytes20(hex"7f8538a5de9dc71c44bf048df5006dff13344289"));
        pools[68] = address(bytes20(hex"a266be7c9f22ad71f1a5aa169e22bc88f78e655c"));
        pools[69] = address(bytes20(hex"5e32f41ac751c3ff17c4f79c4bdc8947c36ebf8c"));
        pools[70] = address(bytes20(hex"aa21bf5b5322b9c7b6f6e1e24f284ba80e18adf6"));
        pools[71] = address(bytes20(hex"ce8ff48eeafa516e615251e9cbcc23db66f80f6c"));
        pools[72] = address(bytes20(hex"b950aca3c8af801156a105fdff78162b1ee69209"));
        pools[73] = address(bytes20(hex"2cd2533a86c4dab3d203e02b5996c09d35203b68"));
        pools[74] = address(bytes20(hex"ae045ae0ac018be3bf4219a67775458d59a025a7"));
        pools[75] = address(bytes20(hex"8be3d6ad021f59758dc3ad73aa7f30e6827eae38"));

        vm.recordLogs();
        for (uint256 i; i < pools.length; ++i) {
            IV3PoolMetadata metadata = IV3PoolMetadata(pools[i]);
            address token0 = metadata.token0();
            address token1 = metadata.token1();
            address other = token0 == USDT0 ? token1 : token0;
            if (_isRelevant(other)) {
                console.log("relevant direct USDT0 pool", pools[i]);
                console.log("other token", other);
                console.log("fee tier", metadata.fee());
            }
            // Do not let a single problematic pool hide the rest of the fee basket.
            // The final solution can simply omit pools that are not collectable.
            IV3FeeCollector.CollectParams[] memory one = new IV3FeeCollector.CollectParams[](1);
            one[0] = IV3FeeCollector.CollectParams({
                pool: pools[i], amount0Requested: type(uint128).max, amount1Requested: type(uint128).max
            });
            try IV3FeeCollector(ADAPTER).collect(one) {} catch (bytes memory reason) {
                console.log("collection failed for pool", pools[i]);
                console.logBytes(reason);
            }
        }
        Vm.Log[] memory entries = vm.getRecordedLogs();

        address[] memory assets = new address[](entries.length);
        uint256[] memory totals = new uint256[](entries.length);
        uint256 assetCount;
        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];
            if (
                entry.topics.length == 3 && entry.topics[0] == TRANSFER
                    && entry.topics[2] == bytes32(uint256(uint160(TOKEN_JAR)))
            ) {
                uint256 amount = abi.decode(entry.data, (uint256));
                if (amount == 0) continue;
                uint256 index = assetCount;
                for (uint256 j; j < assetCount; ++j) {
                    if (assets[j] == entry.emitter) {
                        index = j;
                        break;
                    }
                }
                if (index == assetCount) {
                    assets[assetCount++] = entry.emitter;
                }
                totals[index] += amount;
            }
        }

        console.log("=== Aggregated assets transferred to TokenJar by collect() ===");
        for (uint256 i; i < assetCount; ++i) {
            console.log("token", assets[i]);
            try IERC20Metadata(assets[i]).symbol() returns (string memory symbol) {
                console.log("symbol", symbol);
            } catch {}
            try IERC20Metadata(assets[i]).decimals() returns (uint8 decimals) {
                console.log("decimals");
                console.logUint(decimals);
            } catch {}
            console.log("total raw");
            console.logUint(totals[i]);
        }
    }

    function _isRelevant(address token) internal pure returns (bool) {
        return token == WOKB || token == XBTC || token == XETH || token == USDG || token == AOXC || token == XSOL;
    }
}
