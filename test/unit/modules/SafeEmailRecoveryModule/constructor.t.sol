// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { SafeNativeIntegrationBase } from
    "../../../integration/SafeRecovery/SafeNativeIntegrationBase.t.sol";

import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";

contract SafeEmailRecoveryModule_constructor_Test is SafeNativeIntegrationBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Constructor() public {
        skipIfNotSafeAccountType();
        new SafeEmailRecoveryModule(
            address(verifier), address(dkimRegistry), address(emailAuthImpl), commandHandlerAddress
        );
    }
}
