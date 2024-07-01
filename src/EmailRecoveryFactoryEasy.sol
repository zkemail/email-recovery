// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { EmailRecoveryManager } from "./EmailRecoveryManager.sol";
import { UniversalEmailRecoveryModule } from "./modules/UniversalEmailRecoveryModule.sol";
import { EmailRecoveryModule } from "./modules/EmailRecoveryModule.sol";

contract EmailRecoveryFactoryEasy {
    address public immutable VERIFIER;
    address public immutable DKIM_REGISTRY;
    address public immutable EMAIL_AUTH_IMPL;

    event ZkEmailRecoveryModuleCreated(
        address emailRecoveryModule, address emailRecoveryManager, address subjectHandler
    );

    event ZkEmailRecoveryManager(
        address emailRecoveryManager, address subjectHandler, address forModule
    );

    constructor(address verifier, address dkimRegistry, address emailAuthImpl) {
        VERIFIER = verifier;
        DKIM_REGISTRY = dkimRegistry;
        EMAIL_AUTH_IMPL = emailAuthImpl;
    }

    function deployForModule(
        address module,
        bytes calldata subjectHandlerBytecode,
        bytes32 subjectHandlerSalt,
        bytes32 recoveryManagerSalt
    )
        external
        returns (address emailRecoveryManager, address subjectHandler)
    {
        // Deploy subject handler
        subjectHandler = Create2.deploy(0, subjectHandlerSalt, subjectHandlerBytecode);
        // Deploy recovery manager
        emailRecoveryManager = address(
            new EmailRecoveryManager{ salt: recoveryManagerSalt }(
                VERIFIER, DKIM_REGISTRY, EMAIL_AUTH_IMPL, subjectHandler
            )
        );

        emit ZkEmailRecoveryManager(emailRecoveryManager, subjectHandler, module);

        // Initialize recovery manager with module address
        EmailRecoveryManager(emailRecoveryManager).initialize(module);
    }

    function predictAddressesForModule(
        bytes32 subjectHandlerSalt,
        bytes calldata subjectHandlerBytecode,
        bytes32 recoveryManagerSalt
    )
        external
        view
        returns (address subjectHandler, address emailRecoveryManager)
    {
        subjectHandler =
            Create2.computeAddress(subjectHandlerSalt, keccak256(subjectHandlerBytecode));

        emailRecoveryManager = Create2.computeAddress(
            recoveryManagerSalt,
            keccak256(
                abi.encodePacked(
                    type(EmailRecoveryManager).creationCode,
                    abi.encode(VERIFIER, DKIM_REGISTRY, EMAIL_AUTH_IMPL, subjectHandler)
                )
            )
        );
    }

    function createZkEmailRecoveryModule(
        bytes32 subjectHandlerSalt,
        bytes32 recoveryManagerSalt,
        bytes32 recoveryModuleSalt,
        bytes calldata subjectHandlerBytecode,
        address validator,
        bytes4 recoverySelector
    )
        external
        returns (address emailRecoveryModule, address emailRecoveryManager, address subjectHandler)
    {
        // Deploy subject handler
        subjectHandler = Create2.deploy(0, subjectHandlerSalt, subjectHandlerBytecode);

        // Deploy recovery manager
        emailRecoveryManager = address(
            new EmailRecoveryManager{ salt: recoveryManagerSalt }(
                VERIFIER, DKIM_REGISTRY, EMAIL_AUTH_IMPL, subjectHandler
            )
        );

        // Deploy recovery module
        emailRecoveryModule = address(
            new EmailRecoveryModule{ salt: recoveryModuleSalt }(
                emailRecoveryManager, validator, recoverySelector
            )
        );

        // Initialize recovery manager with module address
        EmailRecoveryManager(emailRecoveryManager).initialize(emailRecoveryModule);

        emit ZkEmailRecoveryModuleCreated(emailRecoveryModule, emailRecoveryManager, subjectHandler);
    }

    function createUniversalZkEmailRecovery(
        bytes32 subjectHandlerSalt,
        bytes32 recoveryManagerSalt,
        bytes32 recoveryModuleSalt,
        bytes calldata subjectHandlerBytecode
    )
        external
        returns (address emailRecoveryModule, address emailRecoveryManager, address subjectHandler)
    {
        // Deploy subject handler
        subjectHandler = Create2.deploy(0, subjectHandlerSalt, subjectHandlerBytecode);

        // Deploy recovery manager
        emailRecoveryManager = address(
            new EmailRecoveryManager{ salt: recoveryManagerSalt }(
                VERIFIER, DKIM_REGISTRY, EMAIL_AUTH_IMPL, subjectHandler
            )
        );

        // Deploy recovery module
        emailRecoveryModule = address(
            new UniversalEmailRecoveryModule{ salt: recoveryModuleSalt }(emailRecoveryManager)
        );

        // Initialize recovery manager with module address
        EmailRecoveryManager(emailRecoveryManager).initialize(emailRecoveryModule);
        emit ZkEmailRecoveryModuleCreated(emailRecoveryModule, emailRecoveryManager, subjectHandler);
    }
}
