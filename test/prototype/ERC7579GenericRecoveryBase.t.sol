// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test, Vm, console } from "forge-std/Test.sol";
import {ERC7579GenericRecoveryModule} from "../../src/prototype/ERC7579GenericRecoveryModule.sol";
import { RhinestoneModuleKit, AccountInstance } from "modulekit/ModuleKit.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

contract ERC7579GenericRecoveryBase is RhinestoneModuleKit, Test {

    ERC7579GenericRecoveryModule public genericRecoveryModule;

    address public killSwitchAuthorizer;
    uint256 public minimumDelay = 12 hours;

    // public account and owners
    address public owner1;
    address public owner2;
    address public owner3;
    address public newOwner1;
    address public newOwner2;
    address public newOwner3;
    AccountInstance public instance1;
    AccountInstance public instance2;
    AccountInstance public instance3;
    address public accountAddress1;
    address public accountAddress2;
    address public accountAddress3;

    OwnableValidator public validator;
    address public validatorAddress;

    // public recovery config
    Vm.Wallet[3] public guardians1;
    Vm.Wallet[3] public guardians2;
    Vm.Wallet[3] public guardians3;
    uint256[] public guardianWeights;
    uint256 public totalWeight;
    uint256 public delay;
    uint256 public expiry;
    uint256 public threshold;
    bytes public isInstalledContext;

    bytes4 public functionSelector;

    bytes public recoveryData1;
    bytes public recoveryData2;
    bytes public recoveryData3;
    bytes32 public recoveryDataHash1;
    bytes32 public recoveryDataHash2;
    bytes32 public recoveryDataHash3;

    function setUp() public virtual {
        // Deploy validator to be recovered
        validator = new OwnableValidator();
        validatorAddress = address(validator);

        killSwitchAuthorizer = vm.addr(2);

        functionSelector = bytes4(keccak256("changeOwner(address)"));

        genericRecoveryModule = new ERC7579GenericRecoveryModule(
            validatorAddress,
            functionSelector,
            minimumDelay,
            killSwitchAuthorizer
        );

        // create owners
        owner1 = vm.createWallet("owner1").addr;
        owner2 = vm.createWallet("owner2").addr;
        owner3 = vm.createWallet("owner3").addr;
        newOwner1 = vm.createWallet("newOwner1").addr;
        newOwner2 = vm.createWallet("newOwner2").addr;
        newOwner3 = vm.createWallet("newOwner3").addr;

        // Deploy and fund the accounts
        instance1 = makeAccountInstance("account1");
        instance2 = makeAccountInstance("account2");
        instance3 = makeAccountInstance("account3");
        accountAddress1 = instance1.account;
        accountAddress2 = instance2.account;
        accountAddress3 = instance3.account;
        vm.deal(address(instance1.account), 10 ether);
        vm.deal(address(instance2.account), 10 ether);
        vm.deal(address(instance3.account), 10 ether);

        bytes memory changeOwnerCalldata1 = abi.encodeWithSelector(functionSelector, newOwner1);
        bytes memory changeOwnerCalldata2 = abi.encodeWithSelector(functionSelector, newOwner2);
        bytes memory changeOwnerCalldata3 = abi.encodeWithSelector(functionSelector, newOwner3);
        console.log(validatorAddress);
        recoveryData1 = abi.encode(validatorAddress, changeOwnerCalldata1);
        recoveryData2 = abi.encode(validatorAddress, changeOwnerCalldata2);
        recoveryData3 = abi.encode(validatorAddress, changeOwnerCalldata3);
        recoveryDataHash1 = keccak256(recoveryData1);
        recoveryDataHash2 = keccak256(recoveryData2);
        recoveryDataHash3 = keccak256(recoveryData3);

         // Compute guardian addresses
        // guardians1 = new Vm.Wallet[](3);
        guardians1[0] = vm.createWallet("guardians.1_1");
        guardians1[1] = vm.createWallet("guardians.1_2");
        guardians1[2] = vm.createWallet("guardians.1_3");
        // guardians2 = new Vm.Wallet[](3);
        guardians2[0] = vm.createWallet("guardians.2_1");
        guardians2[1] = vm.createWallet("guardians.2_2");
        guardians2[2] = vm.createWallet("guardians.2_3");
        // guardians3 = new Vm.Wallet[](3);
        guardians3[0] = vm.createWallet("guardians.3_1");
        guardians3[1] = vm.createWallet("guardians.3_2");
        guardians3[2] = vm.createWallet("guardians.3_3");

        // Set recovery config variables
        guardianWeights = new uint256[](3);
        guardianWeights[0] = 1;
        guardianWeights[1] = 2;
        guardianWeights[2] = 1;
        totalWeight = 4;
        delay = 1 days;
        expiry = 2 weeks;
        threshold = 3;
        isInstalledContext = bytes("0");
    }
}