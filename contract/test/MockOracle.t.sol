// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {MockOracle} from "../src/MockOracle.sol";

contract MockOracleTest is Test {
    MockOracle private oracle;

    function setUp() public {
        oracle = new MockOracle();
    }

    function test_GetUtilization_DefaultIs50() public {
        assertEq(oracle.getUtilization(), 50);
    }

    function test_SetUtilization_WithinRange() public {
        oracle.setUtilization(0);
        assertEq(oracle.getUtilization(), 0);

        oracle.setUtilization(100);
        assertEq(oracle.getUtilization(), 100);
    }

    function test_SetUtilization_RevertsIfOutOfRange() public {
        vm.expectRevert(bytes("MockOracle: utilization out of range"));
        oracle.setUtilization(101);
    }

    function test_SetUtilization_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit MockOracle.UtilizationUpdated(77);
        oracle.setUtilization(77);
    }

    function test_GetUtilizationWithMeta_ReturnsCurrentUtilization() public {
        oracle.setUtilization(66);
        (uint256 utilization,,,) = oracle.getUtilizationWithMeta();
        assertEq(utilization, 66);
    }

    function test_NewUpdateMethods_AreCallable() public {
        oracle.setUtilizationFromBot(45, block.timestamp);
        assertEq(oracle.getUtilization(), 45);

        oracle.setUtilizationFromFunctions(55, block.timestamp, bytes32("req-1"));
        assertEq(oracle.getUtilization(), 55);
    }

    function test_NewAdminMethods_AreCallable() public {
        oracle.setStaleTtl(1200);
        oracle.setAuthorizedUpdater(address(this), true);
    }

    function test_Constants_AreDefinedWithExpectedValues() public view {
        assertEq(oracle.SOURCE_BOT(), 1);
        assertEq(oracle.SOURCE_FUNCTIONS(), 2);
        assertEq(oracle.DIVERGENCE_THRESHOLD(), 15);
        assertEq(oracle.DEFAULT_STALE_TTL(), 20 minutes);
    }

    function test_SourceMeta_UsesDefinedConstants() public {
        oracle.setUtilizationFromBot(60, block.timestamp);
        (,,, uint8 botSource) = oracle.getUtilizationWithMeta();
        assertEq(botSource, oracle.SOURCE_BOT());

        oracle.setUtilizationFromFunctions(61, block.timestamp, bytes32("req-2"));
        (,,, uint8 functionsSource) = oracle.getUtilizationWithMeta();
        assertEq(functionsSource, oracle.SOURCE_FUNCTIONS());
    }

    function test_SetUtilization_LegacyPathUpdatesSourceAndTimestamp() public {
        vm.warp(12345);
        oracle.setUtilization(88);

        (uint256 utilization, uint256 updatedAt,, uint8 source) = oracle.getUtilizationWithMeta();
        assertEq(utilization, 88);
        assertEq(updatedAt, 12345);
        assertEq(source, oracle.SOURCE_BOT());
    }

    function test_SetUtilizationFromFunctions_RecordsRequestId() public {
        bytes32 requestId = keccak256("functions-request");
        oracle.setUtilizationFromFunctions(70, block.timestamp, requestId);
        assertEq(oracle.lastFunctionsRequestId(), requestId);
    }

    function test_SetUtilizationFromBot_RevertsIfTimestampInFuture() public {
        uint256 futureDrift = oracle.MAX_TIMESTAMP_FUTURE_DRIFT();
        vm.expectRevert(bytes("MockOracle: timestamp in future"));
        oracle.setUtilizationFromBot(70, block.timestamp + futureDrift + 1);
    }

    function test_SetUtilizationFromFunctions_RevertsIfTimestampTooOld() public {
        uint256 maxAge = oracle.MAX_TIMESTAMP_AGE();
        vm.warp(maxAge + 100);
        vm.expectRevert(bytes("MockOracle: timestamp too old"));
        oracle.setUtilizationFromFunctions(70, block.timestamp - maxAge - 1, bytes32("req-old"));
    }

    function test_GetUtilizationWithMeta_InitialStateIsStale() public view {
        (,, bool stale,) = oracle.getUtilizationWithMeta();
        assertTrue(stale);
    }

    function test_GetUtilizationWithMeta_BecomesStaleAfterTtl() public {
        oracle.setUtilization(50);
        vm.warp(block.timestamp + oracle.DEFAULT_STALE_TTL() + 1);

        (,, bool stale,) = oracle.getUtilizationWithMeta();
        assertTrue(stale);
    }

    function test_SetUtilizationFromBot_RevertsIfTimestampAlreadyStaleAtWrite() public {
        uint256 staleTtl = oracle.DEFAULT_STALE_TTL();
        vm.warp(staleTtl + 100);
        vm.expectRevert(bytes("MockOracle: timestamp already stale"));
        oracle.setUtilizationFromBot(70, block.timestamp - staleTtl - 1);
    }
}
