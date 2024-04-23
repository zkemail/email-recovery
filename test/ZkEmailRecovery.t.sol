// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {RhinestoneModuleKit, ModuleKitHelpers, ModuleKitUserOp, AccountInstance, UserOpData} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR} from "modulekit/external/ERC7579.sol";
import {ZkEmailRecovery} from "src/ZkEmailRecovery.sol";

contract ZkEmailRecoveryTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // account and modules
    AccountInstance internal instance;
    ZkEmailRecovery internal executor;

    function setUp() public {
        init();

        // Create the executor
        executor = new ZkEmailRecovery(address(0), address(0), address(0));
        vm.label(address(executor), "ZkEmailRecovery");

        // Create the account and install the executor
        instance = makeAccountInstance("ZkEmailRecovery");
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

        // Execute the call
        // EntryPoint -> Account -> Executor -> Account -> Swap
        UserOpData memory userOpData = instance.getExecOps({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(
                ZkEmailRecovery.completeRecovery.selector
            ),
            txValidator: address(instance.defaultValidator)
        });

        // Execute the userOp
        userOpData.execUserOps();

        // Check if the balance of the target has increased
        assertEq(target.balance, prevBalance + value);
    }
}
