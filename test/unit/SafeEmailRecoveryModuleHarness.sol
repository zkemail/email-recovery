// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";

contract SafeEmailRecoveryModuleHarness is SafeEmailRecoveryModule {
    constructor(
        address verifier,
        address dkimRegistry,
        address emailAuthImpl,
        address commandHandler,
        uint256 minimumDelay
    )
        SafeEmailRecoveryModule(verifier, dkimRegistry, emailAuthImpl, commandHandler, minimumDelay)
    { }

    function exposed_recover(address account, bytes calldata recoveryData) external {
        recover(account, recoveryData);
    }
}
