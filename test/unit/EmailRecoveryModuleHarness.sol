// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { EnumerableGuardianMap, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";

contract EmailRecoveryModuleHarness is EmailRecoveryModule {
    using SentinelListLib for SentinelListLib.SentinelList;

    constructor(
        address verifier,
        address dkimRegistry,
        address emailAuthImpl,
        address subjectHandler,
        address validator,
        bytes4 selector
    )
        EmailRecoveryModule(verifier, dkimRegistry, emailAuthImpl, subjectHandler, validator, selector)
    { }

    function exposed_recover(address account, bytes calldata recoveryData) external {
        recover(account, recoveryData);
    }
}
