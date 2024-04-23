// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {RhinestoneModuleKit, ModuleKitHelpers, ModuleKitUserOp, AccountInstance, UserOpData} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_VALIDATOR} from "modulekit/external/ERC7579.sol";
import {ZkEmailRecovery} from "src/ZkEmailRecovery.sol";

contract ZkEmailRecoveryTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // account and modules
    AccountInstance internal instance;
    ZkEmailRecovery internal validator;

    function setUp() public {
        init();

        // Create the validator
        validator = new ZkEmailRecovery();
        vm.label(address(validator), "ZkEmailRecovery");

        // Create the account and install the validator
        instance = makeAccountInstance("ZkEmailRecovery");
        vm.deal(address(instance.account), 10 ether);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: ""
        });
    }

    function testExec() public {
        // Create a target address and send some ether to it
        address target = makeAddr("target");
        uint256 value = 1 ether;

        // Get the current balance of the target
        uint256 prevBalance = target.balance;

        // Get the UserOp data (UserOperation and UserOperationHash)
        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: "",
            txValidator: address(validator)
        });

        // Set the signature
        bytes memory signature = hex"414141";
        userOpData.userOp.signature = signature;

        // Execute the UserOp
        userOpData.execUserOps();

        // Check if the balance of the target has increased
        assertEq(target.balance, prevBalance + value);
    }
}
