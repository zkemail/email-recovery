// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { EmailRecoveryModule, ValidatorList } from "src/modules/EmailRecoveryModule.sol";

contract EmailRecoveryModuleHarness is EmailRecoveryModule {
    using SentinelListLib for SentinelListLib.SentinelList;

    constructor(address emailRecoveryManager) EmailRecoveryModule(emailRecoveryManager) { }

    function exposed_allowedSelectors(
        address validator,
        address account
    )
        external
        returns (bytes4)
    {
        return allowedSelectors[validator][account];
    }

    function exposed_selectorToValidator(
        bytes4 selector,
        address account
    )
        external
        returns (address)
    {
        return selectorToValidator[selector][account];
    }
}
