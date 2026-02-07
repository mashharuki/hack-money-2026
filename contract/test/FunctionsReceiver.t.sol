// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockOracle} from "../src/MockOracle.sol";
import {FunctionsReceiver} from "../src/functions/FunctionsReceiver.sol";

contract FunctionsReceiverTest is Test {
    FunctionsReceiver internal receiver;
    MockOracle internal oracle;

    bytes32 internal constant DON_ID = bytes32("fun-base-sepolia-1");
    uint64 internal constant SUBSCRIPTION_ID = 123;
    uint32 internal constant CALLBACK_GAS_LIMIT = 300_000;

    function setUp() public {
        oracle = new MockOracle();
        receiver = new FunctionsReceiver(address(oracle), DON_ID, SUBSCRIPTION_ID, CALLBACK_GAS_LIMIT);
    }

    function test_constructor_setsCoreConfig() public view {
        assertEq(address(receiver.oracle()), address(oracle));
        assertEq(receiver.donId(), DON_ID);
        assertEq(receiver.subscriptionId(), SUBSCRIPTION_ID);
        assertEq(receiver.callbackGasLimit(), CALLBACK_GAS_LIMIT);
        assertEq(receiver.minUpkeepInterval(), 600);
        assertEq(receiver.owner(), address(this));
    }

    function test_checkUpkeep_respectsMinInterval() public {
        (bool upkeepNeeded,) = receiver.checkUpkeep("");
        assertFalse(upkeepNeeded);

        vm.warp(block.timestamp + receiver.minUpkeepInterval());
        (upkeepNeeded,) = receiver.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    function test_adminSetters_updateValues() public {
        receiver.setSource("return Functions.encodeUint256(42);");
        assertEq(receiver.source(), "return Functions.encodeUint256(42);");

        string[] memory newArgs = new string[](2);
        newArgs[0] = "https://base-sepolia.example";
        newArgs[1] = "60";
        receiver.setArgs(newArgs);
        assertEq(receiver.args(0), "https://base-sepolia.example");
        assertEq(receiver.args(1), "60");

        receiver.setSubscriptionId(456);
        assertEq(receiver.subscriptionId(), 456);

        receiver.setMinUpkeepInterval(900);
        assertEq(receiver.minUpkeepInterval(), 900);
    }

    function test_adminSetters_revertForNonOwner() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0xBEEF)));
        receiver.setSource("x");

        string[] memory newArgs = new string[](1);
        newArgs[0] = "y";
        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0xBEEF)));
        receiver.setArgs(newArgs);

        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0xBEEF)));
        receiver.setSubscriptionId(789);

        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0xBEEF)));
        receiver.setMinUpkeepInterval(1);
    }
}
