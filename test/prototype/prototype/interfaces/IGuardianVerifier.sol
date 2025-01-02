// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

struct Guardian {
    bytes guardian;
    address guardianVerifier;
}

interface IGuardianVerifier {

    error CallerDoesNotMatchRecoveryModule(address recoveryModule, address caller);

    function handleAcceptVerification(
        // Action action, // what to verify, guardian acceptance, recovery
        address account,
        address recoveryModule,
        bytes memory guardian,
        bytes memory verficationData
    ) external;

    function handleProcessVerification(
        // Action action, // what to verify, guardian acceptance, recovery
        address account,
        address recoveryModule,
        bytes memory guardian,
        bytes memory verficationData
    ) external returns(bytes32);
}