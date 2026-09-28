// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";

interface IOpenFeeAdapterRecent {
    struct CollectParams {
        address pool;
        uint128 amount0Requested;
        uint128 amount1Requested;
    }

    function collect(CollectParams[] calldata collectParams) external;
}

interface IERC20Recent {
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

/// @notice A *provisional* discovery check, not the final solution.
///
/// These pools come from the most recent `batchTriggerFeeUpdateByPool` calls
/// before the challenge fork, decoded from the official X Layer explorer.
/// This is deliberately a much narrower input set than a full factory scan:
/// the adapter itself tells us which pools were configured for protocol fees.
///
/// It is still an evidence-gathering step.  A later pass must add any older
/// fee-enabled pool that was not present in these recent update batches.
contract RecentFeeUpdateInspector is Test {
    address constant ADAPTER = 0x6A88EF2e6511CAFfE2D006e260e7A5d1E7D4d7D7;
    address constant TOKEN_JAR = 0x8Dd8B6D56e4a4A158EDbBfE7f2f703B8FFC1a754;
    bytes32 constant TRANSFER = keccak256("Transfer(address,address,uint256)");

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68_413_600);
    }

    function test_CollectRecentFeeUpdateCandidates() public {
        address[] memory pools = _pools();
        vm.recordLogs();

        uint256 collected;
        for (uint256 i; i < pools.length; ++i) {
            IOpenFeeAdapterRecent.CollectParams[] memory request = new IOpenFeeAdapterRecent.CollectParams[](1);
            request[0] = IOpenFeeAdapterRecent.CollectParams({
                pool: pools[i], amount0Requested: type(uint128).max, amount1Requested: type(uint128).max
            });
            try IOpenFeeAdapterRecent(ADAPTER).collect(request) {
                ++collected;
            } catch (bytes memory reason) {
                console.log("collection failed for pool", pools[i]);
                console.logBytes(reason);
            }
        }

        Vm.Log[] memory logs = vm.getRecordedLogs();
        address[] memory assets = new address[](logs.length);
        uint256[] memory totals = new uint256[](logs.length);
        uint256 assetCount;

        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory entry = logs[i];
            if (
                entry.topics.length != 3 || entry.topics[0] != TRANSFER
                    || entry.topics[2] != bytes32(uint256(uint160(TOKEN_JAR)))
            ) continue;

            uint256 amount = abi.decode(entry.data, (uint256));
            if (amount == 0) continue;

            uint256 index = assetCount;
            for (uint256 j; j < assetCount; ++j) {
                if (assets[j] == entry.emitter) {
                    index = j;
                    break;
                }
            }
            if (index == assetCount) assets[assetCount++] = entry.emitter;
            totals[index] += amount;
        }

        console.log("=== Recent adapter update-batch collection ===");
        console.log("candidate pools", pools.length);
        console.log("collect calls that did not revert", collected);
        console.log("assets sent to TokenJar:");
        for (uint256 i; i < assetCount; ++i) {
            console.log("token", assets[i]);
            try IERC20Recent(assets[i]).symbol() returns (string memory symbol) {
                console.log("symbol", symbol);
            } catch {}
            try IERC20Recent(assets[i]).decimals() returns (uint8 decimals) {
                console.log("decimals");
                console.logUint(decimals);
            } catch {}
            console.log("total raw");
            console.logUint(totals[i]);
        }
    }

    function _pools() internal pure returns (address[] memory pools) {
        pools = new address[](95);
        pools[0] = address(bytes20(hex"c8829A45464e0706988843Bc324a7072093C7786"));
        pools[1] = address(bytes20(hex"4781450957EE6A292C7D6D8e1C9415b899cDF3BF"));
        pools[2] = address(bytes20(hex"73c6C0CE7D71A4CEca79Ab9Aa77Cc7C2557B829a"));
        pools[3] = address(bytes20(hex"D08CB8D871192D1E2d5a7975560f4Da20eE4971c"));
        pools[4] = address(bytes20(hex"A6bD621b5CBC45609677611d4Db970DA76C972B1"));
        pools[5] = address(bytes20(hex"3adA9770563d333E5d1B2F77d64b33D62eFAff9d"));
        pools[6] = address(bytes20(hex"448A8cC34A2053C73B2D46E1468b4a43B7caE525"));
        pools[7] = address(bytes20(hex"64e11F5B88f8852B95cC970ECc37f8928E60b423"));
        pools[8] = address(bytes20(hex"E69cf1DA4C1243bF56Ca68cDD18dFc10FfF5A51c"));
        pools[9] = address(bytes20(hex"A24898C43B6bBe7E286E6f6185CCD94F78FF45e2"));
        pools[10] = address(bytes20(hex"c03ce701aE557E71ACd50977B3b417dC95C5c7D9"));
        pools[11] = address(bytes20(hex"542f782b4224369587C50d488F96a3211275Ba3D"));
        pools[12] = address(bytes20(hex"cDADbEE8edddC2B114A52e10e98Bf21323b5ac6E"));
        pools[13] = address(bytes20(hex"cc15155561023D581a5FC482Ab8d0122d580007a"));
        pools[14] = address(bytes20(hex"51B8bf5ed0642C6aABCB8a2C67408d3B0164ff48"));
        pools[15] = address(bytes20(hex"fAb66640BbBc28Bf699FE7E3c7Cb0aa68C178119"));
        pools[16] = address(bytes20(hex"d8Bd31E9bB415981fd0C8324ED14CCfCD0b82Db5"));
        pools[17] = address(bytes20(hex"82BE4135129985780193a03D6CD80BEE0bED2BF3"));
        pools[18] = address(bytes20(hex"1872A90D96027e0F10b6DB5842aB89C1ddb963a0"));
        pools[19] = address(bytes20(hex"88D37DC54a9c9D08a9498C0E2F965a2974d16AF5"));
        pools[20] = address(bytes20(hex"e2044D52447E6c707114eB1564fBA896eA745f10"));
        pools[21] = address(bytes20(hex"2e845951bAFb6aD245718836ceA8307431b705ef"));
        pools[22] = address(bytes20(hex"64f706208AD7D72262D5f1F48370Cd706D2A007e"));
        pools[23] = address(bytes20(hex"2aC06B5cd6eBB8ecBd7cA6bbF10E52C5402080E3"));
        pools[24] = address(bytes20(hex"737fe1eBe615B739eD28838CF53eBe271d38E0a5"));
        pools[25] = address(bytes20(hex"1F361469d9C527CACcd134690a13C15bD4990912"));
        pools[26] = address(bytes20(hex"035aF780B1f1437D00625fb6B0E0bC55Aa86C475"));
        pools[27] = address(bytes20(hex"0b1A5a6CA3B16E74eE72C5D0a1Eae2823f7FAdFE"));
        pools[28] = address(bytes20(hex"8aB294cec9d748e9209702b638465360C2C9CDA0"));
        pools[29] = address(bytes20(hex"D37aFAAb507111A8e7aff3802d00C444C62148B6"));
        pools[30] = address(bytes20(hex"1bF0Bc40301453BcAF170cB51f3483Aadaf25223"));
        pools[31] = address(bytes20(hex"5F96a1064e62021747372e27903EE99ac4c805A7"));
        pools[32] = address(bytes20(hex"84aE014C0a8d6FE60CAb94432a231a5e7bd2f7AE"));
        pools[33] = address(bytes20(hex"9D6365ed5edd1B3E52d9847dB432526217221bB8"));
        pools[34] = address(bytes20(hex"6c31b3a766C3Ffd1859628784E9b7E19082e8697"));
        pools[35] = address(bytes20(hex"4a21891cC033587799317Cb5F45AAa8Ee8043AB2"));
        pools[36] = address(bytes20(hex"B87B595CA5a94Fd8Ae6f9BdC9fF39E12e0B7de9a"));
        pools[37] = address(bytes20(hex"aB38a1caB4b2c6F47dC96fe7410E7DAeC5597A3c"));
        pools[38] = address(bytes20(hex"151b73429e1811dB6898926d32bd357fd93354f0"));
        pools[39] = address(bytes20(hex"42b30619474c9BAb049BEbB38BCE88C87825FeB7"));
        pools[40] = address(bytes20(hex"6442C11A2C8E707A68fb7E7D03EC592614CC6A78"));
        pools[41] = address(bytes20(hex"1aBAA79fbe183ba1D778003f90616b25B55c91D3"));
        pools[42] = address(bytes20(hex"5E5B3C1840877Fb9121Cd54Ce4c8D1A80D959C6F"));
        pools[43] = address(bytes20(hex"09451554391284D12f2e9772255f0E7E28dDEf01"));
        pools[44] = address(bytes20(hex"26fd9ba3797fD1a3E4eD7520901Eb5bD6435a3c7"));
        pools[45] = address(bytes20(hex"7cdBAC754fefF16bB40956fA77221af00476b130"));
        pools[46] = address(bytes20(hex"20082347915A9109646BC2a244db6409bD8CC718"));
        pools[47] = address(bytes20(hex"9FEaFEA705FaD3BBF605a729F109D1853B53d12E"));
        pools[48] = address(bytes20(hex"6d3B55F960d564C065501220232E7463105823DE"));
        pools[49] = address(bytes20(hex"77228e53f783dd25c2ac9810B8E93Df2ad3E9EEf"));
        pools[50] = address(bytes20(hex"99B8b5BC47D458c238400D76831997e45B7914f7"));
        pools[51] = address(bytes20(hex"4923E56D08C6095087f3837248958fD8918beC37"));
        pools[52] = address(bytes20(hex"c95B87193E3c0f7fE22c30d11EC5de32Cb0A361D"));
        pools[53] = address(bytes20(hex"1Bc07Db9174fF16D00e8E229967521BD5BfCaD4D"));
        pools[54] = address(bytes20(hex"923fEc7e4dBfb14aa0A492C95613F9242fbDcF6C"));
        pools[55] = address(bytes20(hex"d51eAea2863ADEe10c082Db27b12c84347103567"));
        pools[56] = address(bytes20(hex"A8A55346AD9cE2a0404f933B6129832AB622E0A6"));
        pools[57] = address(bytes20(hex"4E3178BFC5e2Cf6CFD1d1ff03790169c179B27FB"));
        pools[58] = address(bytes20(hex"5e5Bc4f105FDF1EaEA565AE1F843fF00EA5aBcCc"));
        pools[59] = address(bytes20(hex"d6B771421eA0594FC207DA23cE37D323290744BA"));
        pools[60] = address(bytes20(hex"b11E0F06d97D25C3934367652eD6ba9a7b43B378"));
        pools[61] = address(bytes20(hex"7EC2776276a9eDfc5F08d636F207AB8111100034"));
        pools[62] = address(bytes20(hex"28A9a52E6C94F1D6642daea4950D9708c81f52f5"));
        pools[63] = address(bytes20(hex"773719e0d6e36EF08B3CE4Cf3908e741be5cAB4C"));
        pools[64] = address(bytes20(hex"d625cF83BEF44f236858D6528e95391c10098883"));
        pools[65] = address(bytes20(hex"95b737Bd3b8097B20988B8d6eBEBbAAB88953fED"));
        pools[66] = address(bytes20(hex"4C59E966368292C543f61433B0fcD8424D2c2ec0"));
        pools[67] = address(bytes20(hex"be5e3c9f9e152D52C956E86e4bCa3E890c81D88E"));
        pools[68] = address(bytes20(hex"C967c816e4EEb925B5c7D636fFd195614e6Bef2b"));
        pools[69] = address(bytes20(hex"FeD4B35E05e3d87960beA5003269CE15b78c09BE"));
        pools[70] = address(bytes20(hex"bEe82Ef6e304C5DB6b9D2dE55681cda637eFf35D"));
        pools[71] = address(bytes20(hex"fcE872A10d902EEeDA8B25d7Df157038575f50e6"));
        pools[72] = address(bytes20(hex"c65fA41F8064c4feDCF6F17e906E7099A42D3B24"));
        pools[73] = address(bytes20(hex"E277C426E352F7E5b70592720aB5857eA380d1E6"));
        pools[74] = address(bytes20(hex"802c2B4B97F0835CB06b55e3aDDCeFa03B88fa3F"));
        pools[75] = address(bytes20(hex"6aDA685AAA79c12092AC039Da21c5fafc4622603"));
        pools[76] = address(bytes20(hex"e61Eb07A1332941Bdf88e3E63E81f745Ae10AD77"));
        pools[77] = address(bytes20(hex"84548f021944568f7a75B1F7dC69d2c36E419476"));
        pools[78] = address(bytes20(hex"53c3b24a3893Dc06Db765a27613E08276d93dDc0"));
        pools[79] = address(bytes20(hex"2A27E9D8dd4714E76D823d6a59BBa4a4BeF21c67"));
        pools[80] = address(bytes20(hex"fFf94088CaDf8e908aeeFf8569fC349a3eb07d6A"));
        pools[81] = address(bytes20(hex"fBB6D5fC9b86557F41774692e3C7b5eA1Bd0c430"));
        pools[82] = address(bytes20(hex"448b5416a6279f6444B4438F4B2cB863312b0bdD"));
        pools[83] = address(bytes20(hex"32344bf6cd5cA174b23791807592831491309244"));
        pools[84] = address(bytes20(hex"C2eCacDD527D6EDb32038e24837a929A8b1B6538"));
        pools[85] = address(bytes20(hex"31eA5237E52963e954Ba152a1cEb521F40988DcE"));
        pools[86] = address(bytes20(hex"1fd40184251dF69D473764e7E4140Bf6fEb822B9"));
        pools[87] = address(bytes20(hex"1F73153f84908619E1D8bD6a7ef26264F35C8632"));
        pools[88] = address(bytes20(hex"090e799B01bfa11AD6c4B327E5171Ab9471eC94B"));
        pools[89] = address(bytes20(hex"1714b8D2FfAb7574d32B320e02809C80423a1aDd"));
        pools[90] = address(bytes20(hex"4474787D2aBcE981DdB6e699E1c816Dbc69BFA94"));
        pools[91] = address(bytes20(hex"2b4164caB9877bf10100A4D9A3dE5768996c728D"));
        pools[92] = address(bytes20(hex"019b105a6c4f90a661a07F708f2D29f68B27Be69"));
        pools[93] = address(bytes20(hex"D810D5d9574CD66665B87302Fa8fbFF45C3c03D2"));
        pools[94] = address(bytes20(hex"3E210Edc59E9c98aEffd01e23512e488f9C45AcA"));
    }
}
