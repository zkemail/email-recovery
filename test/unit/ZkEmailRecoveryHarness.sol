// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import "forge-std/console2.sol";
import {ZkEmailRecovery} from "src/ZkEmailRecovery.sol";

contract ZkEmailRecoveryHarness is ZkEmailRecovery {
    constructor(
        address _verifier,
        address _dkimRegistry,
        address _emailAuthImpl
    ) ZkEmailRecovery(_verifier, _dkimRegistry, _emailAuthImpl) {}

    function exposed_acceptGuardian(
        address guardian,
        uint templateIdx,
        bytes[] memory subjectParams,
        bytes32 nullifier
    ) external {
        acceptGuardian(guardian, templateIdx, subjectParams, nullifier);
    }
}
