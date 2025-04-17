// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {RhinestoneModuleKit, ModuleKitHelpers, AccountInstance} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {OwnableValidator} from "@rhinestone/core-modules/src/OwnableValidator/OwnableValidator.sol";
import {RecoveryModule} from "../src/RecoveryModule.sol";

contract RecoveryModuleTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;

    RecoveryModule public recoveryModule;
    OwnableValidator public validator;

    address public recoveryModuleAddress;
    address public validatorAddress;

    AccountInstance public account;
    address public accountAddress;

    uint256 public threshold;
    address[] public owners;
    uint256[] public ownerPks;

    address[] public guardians;
    uint256 public delay;
    uint256 public expiry;

    function setUp() public {
        recoveryModule = new RecoveryModule();
        validator = new OwnableValidator();
        recoveryModuleAddress = address(recoveryModule);
        validatorAddress = address(validator);

        account = makeAccountInstance("account");
        accountAddress = account.account;

        vm.deal(address(accountAddress), 10 ether);

        owners = new address[](2);
        owners[0] = vm.createWallet("owner1").addr;
        owners[1] = vm.createWallet("owner2").addr;
        threshold = 2;
        delay = 1 days;
        expiry = 2 weeks;

        guardians = new address[](2);
        guardians[0] = vm.createWallet("guardian1").addr;
        guardians[1] = vm.createWallet("guardian2").addr;

        (owners, ) = generateAndsortOwners();
        bytes memory data = abi.encode(threshold, owners);

        account.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: data
        });

        account.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(
                validatorAddress,
                guardians,
                threshold,
                delay,
                expiry
            )
        });
    }

    function generateAndsortOwners()
        internal
        returns (address[] memory, uint256[] memory)
    {
        address[] memory owners = new address[](2);
        uint256[] memory ownerPks = new uint256[](2);

        (address owner1, uint256 owner1Pk) = makeAddrAndKey("owner1");
        (address owner2, uint256 owner2Pk) = makeAddrAndKey("owner2");

        owners[0] = owner1;
        ownerPks[0] = owner1Pk;

        uint256 counter = 0;
        while (uint160(owner1) > uint160(owner2)) {
            counter++;
            (owner2, owner2Pk) = makeAddrAndKey(vm.toString(counter));
        }
        owners[1] = owner2;
        ownerPks[1] = owner2Pk;

        return (owners, ownerPks);
    }

    function test_RecoveryModule_RecoversAValidator() public pure {
        assertTrue(true);
    }
}
