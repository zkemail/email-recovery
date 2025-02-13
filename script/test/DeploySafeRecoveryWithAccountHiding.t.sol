// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalEmailRecoveryTest } from "./base/BaseDeployUniversalEmailRecovery.t.sol";
import { DeploySafeRecoveryWithAccountHidingScript } from
    "../DeploySafeRecoveryWithAccountHiding.s.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

contract DeploySafeRecoveryWithAccountHidingTest is BaseDeployUniversalEmailRecoveryTest {
    function setUp() public override {
        super.setUp();
        target = new DeploySafeRecoveryWithAccountHidingScript();
    }

    function test_Deployment() public {
        setAllEnvVars();

        address expectedCommandHandler = computeAddress(
            config.create2Salt,
            type(AccountHidingRecoveryCommandHandler).creationCode,
            "",
            config.recoveryFactory
        );

        address expectedRecoveryModule = computeAddress(
            config.create2Salt,
            type(UniversalEmailRecoveryModule).creationCode,
            abi.encode(
                config.verifier,
                config.dkimRegistry,
                config.emailAuthImpl,
                expectedCommandHandler,
                config.minimumDelay,
                config.killSwitchAuthorizer
            ),
            config.recoveryFactory
        );

        assert(!isContractDeployed(expectedCommandHandler));
        assert(!isContractDeployed(expectedRecoveryModule));
        target.run();
        assert(isContractDeployed(expectedCommandHandler));
        assert(isContractDeployed(expectedRecoveryModule));
        // also checking returned addresses
        assertEq(target.emailRecoveryHandler(), expectedCommandHandler);
        assertEq(target.emailRecoveryModule(), expectedRecoveryModule);
    }
}
