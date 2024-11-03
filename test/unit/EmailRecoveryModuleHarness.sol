// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";

contract EmailRecoveryModuleHarness is EmailRecoveryModule {
    using SentinelListLib for SentinelListLib.SentinelList;

    constructor(
        address verifier,
        address dkimRegistry,
        address emailAuthImpl,
        address commandHandler,
        uint256 minimumDelay,
        address killSwitchAuthorizer,
        address validator,
        bytes4 selector
    )
        EmailRecoveryModule(
            verifier,
            dkimRegistry,
            emailAuthImpl,
            commandHandler,
            minimumDelay,
            killSwitchAuthorizer,
            validator,
            selector
        )
    { }

    function exposed_recover(address account, bytes calldata recoveryData) external {
        recover(account, recoveryData);
    }
}
