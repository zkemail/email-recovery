// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {EmailRecoverySubjectHandler} from "src/handlers/EmailRecoverySubjectHandler.sol";
import {EmailRecoveryManager} from "src/EmailRecoveryManager.sol";
import {EmailRecoveryModule} from "src/modules/EmailRecoveryModule.sol";
import {Verifier} from "ether-email-auth/packages/contracts/src/utils/Verifier.sol";
import {ECDSAOwnedDKIMRegistry} from "ether-email-auth/packages/contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import {EmailAuth} from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import {EmailAccountRecovery} from "ether-email-auth/packages/contracts/src/EmailAccountRecovery.sol";
import {EmailRecoveryFactory} from "src/EmailRecoveryFactory.sol";
import {RhinestoneModuleKit, AccountInstance} from "modulekit/ModuleKit.sol";
import {OwnableValidator} from "src/test/OwnableValidator.sol";
import {SubjectUtils} from "ether-email-auth/packages/contracts/src/libraries/SubjectUtils.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR} from "modulekit/external/ERC7579.sol";
import {ModuleKitHelpers, ModuleKitUserOp} from "modulekit/ModuleKit.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Deploy7579TestAccountScript is RhinestoneModuleKit, Script {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using Strings for uint256;
    using Strings for address;

    function run() public {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privKey);
        address deployer = vm.addr(privKey);

        bytes32 accountSalt = vm.envBytes32("ACCOUNT_SALT");
        require(accountSalt != bytes32(0), "ACCOUNT_SALT is required");
        AccountInstance memory instance = makeAccountInstance(accountSalt);

        address validatorAddress = vm.envOr("VALIDATOR", address(0));
        if (validatorAddress == address(0)) {
            validatorAddress = address(new OwnableValidator());
            // vm.setEnv("VALIDATOR", vm.toString(validatorAddress));
            console.log("Deployed Ownable Validator at", validatorAddress);
        }
        OwnableValidator validator = OwnableValidator(validatorAddress);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(
                vm.envOr("OWNER", deployer),
                vm.envAddress("RECOVERY_MODULE")
            )
        });

        bytes4 functionSelector = bytes4(
            keccak256(bytes("changeOwner(address,address,address)"))
        );
        address managerAddr = vm.envAddress("RECOVERY_MANAGER");
        require(managerAddr != address(0), "RECOVERY_MANAGER is required");

        address guardianAddr = EmailAccountRecovery(managerAddr)
            .computeEmailAuthAddress(instance.account, accountSalt);
        console.log("Guardian's EmailAuth address", guardianAddr);
        address[] memory guardians = new address[](1);
        guardians[0] = guardianAddr;
        uint256[] memory guardianWeights = new uint256[](1);
        guardianWeights[0] = 1;
        uint threshold = 1;
        bytes memory recoveryModuleInstallData = abi.encode(
            validatorAddress,
            bytes("0"),
            functionSelector,
            guardians,
            guardianWeights,
            threshold,
            1 seconds,
            2 weeks
        );
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: vm.envAddress("RECOVERY_MODULE"),
            data: recoveryModuleInstallData
        });
        vm.stopBroadcast();
    }
}
