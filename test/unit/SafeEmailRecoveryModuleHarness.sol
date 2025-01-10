// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";

contract SafeEmailRecoveryModuleHarness is SafeEmailRecoveryModule {
    constructor(
        address verifier,
        address eoaVerifier,
        address dkimRegistry,
        address emailAuthImpl,
        address eoaAuthImpl,
        address commandHandler,
        uint256 minimumDelay,
        address killSwitchAuthorizer
    )
        SafeEmailRecoveryModule(
            verifier,
            eoaVerifier,
            dkimRegistry,
            emailAuthImpl,
            eoaAuthImpl,
            commandHandler,
            minimumDelay,
            killSwitchAuthorizer
        )
    { }

    function exposed_recover(address account, bytes calldata recoveryData) external {
        recover(account, recoveryData);
    }
}
