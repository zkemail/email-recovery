// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { ExecutorTemplate } from "src/ExecutorTemplate.sol";

contract ExecutorTemplateTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // account and modules
    AccountInstance internal instance;
    ExecutorTemplate internal executor;

    function setUp() public {
        init();

        // Create the executor
        executor = new ExecutorTemplate();
        vm.label(address(executor), "ExecutorTemplate");

        // Create the account and install the executor
        instance = makeAccountInstance("ExecutorTemplate");
        vm.deal(address(instance.account), 10 ether);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(executor),
            data: ""
        });
    }

    function testExec() public {
        // Create a target address and send some ether to it
        address target = makeAddr("target");
        uint256 value = 1 ether;

        // Get the current balance of the target
        uint256 prevBalance = target.balance;

        // Encode the execution data sent to the account
        bytes memory callData = ExecutionLib.encodeSingle(target, value, "");

        // Execute the call
        // EntryPoint -> Account -> Executor -> Account -> Target
        instance.exec({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(ExecutorTemplate.execute.selector, callData)
        });

        // Check if the balance of the target has increased
        assertEq(target.balance, prevBalance + value);
    }
}
