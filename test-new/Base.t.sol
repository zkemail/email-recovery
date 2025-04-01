// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {RhinestoneModuleKit, AccountInstance} from "modulekit/ModuleKit.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {OwnableValidator} from "src/test/OwnableValidator.sol";

/* solhint-disable gas-custom-errors, custom-errors, reason-string, max-states-count */

abstract contract BaseTest is RhinestoneModuleKit, Test {
    using Strings for uint256;

    // ZK Email contracts and variables
    address public zkEmailDeployer;

    OwnableValidator public validator;
    address public validatorAddress;

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
    address public killSwitchAuthorizer;

    // public Account salts
    bytes32 public accountSalt1;
    bytes32 public accountSalt2;
    bytes32 public accountSalt3;

    // public recovery config
    address[] public guardians1;
    address[] public guardians2;
    address[] public guardians3;
    uint256[] public guardianWeights;
    uint256 public totalWeight;
    uint256 public delay;
    uint256 public expiry;
    uint256 public threshold;
    uint256 public templateIdx;
    bytes public isInstalledContext;

    string public selector = "12345";
    string public domainName = "gmail.com";
    bytes32 public publicKeyHash =
        0x0ea9c777dc7110e5a9e89b13f0cfc540e3845ba120b2b6dc24024d61488d4788;
    uint256 public minimumDelay = 12 hours;

    bytes4 public functionSelector;
    bytes public recoveryCalldata;
    bytes public recoveryData;
    bytes32 public recoveryDataHash;

    uint256 public nullifierCount;

    function setUp() public virtual {
        init();

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

        accountSalt1 = keccak256(abi.encode("account salt 1"));
        accountSalt2 = keccak256(abi.encode("account salt 2"));
        accountSalt3 = keccak256(abi.encode("account salt 3"));

        zkEmailDeployer = vm.addr(1);
        killSwitchAuthorizer = vm.addr(2);

        // Deploy validator to be recovered
        validator = new OwnableValidator();
        validatorAddress = address(validator);

        setRecoveryData();

        // Deploy the module
        deployModule();

        // Set recovery config variables
        guardianWeights = new uint256[](3);
        guardianWeights[0] = 1;
        guardianWeights[1] = 2;
        guardianWeights[2] = 1;
        totalWeight = 4;
        delay = 1 days;
        expiry = 2 weeks;
        threshold = 3;
        templateIdx = 0;
        isInstalledContext = bytes("0");
    }

    /**
     * Return if current account type is safe or not
     */
    function isAccountTypeSafe() public view returns (bool) {
        string memory currentAccountType = vm.envOr("ACCOUNT_TYPE", string(""));
        if (Strings.equal(currentAccountType, "SAFE")) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * Skip the test if the account type is not safe
     */
    function skipIfNotSafeAccountType() public {
        if (isAccountTypeSafe()) {
            vm.skip(false);
        } else {
            vm.skip(true);
        }
    }

    function setRecoveryData() public virtual;

    function deployModule() public virtual;

    function computeGuardianVerifierAuthAddress(
        address guardianVerifierImplementation,
        address account,
        bytes32 accountSalt,
        bytes memory verifierInitData
    ) public view virtual returns (address);

    function getAccountSaltForGuardian(
        address account,
        address guardian
    ) public view returns (bytes32) {
        address[] memory guardians;
        if (account == instance1.account) {
            guardians = guardians1;
        } else if (account == instance2.account) {
            guardians = guardians2;
        } else if (account == instance3.account) {
            guardians = guardians3;
        } else {
            revert("getAccountSaltForGuardian - Invalid account address");
        }
        if (guardian == guardians[0]) {
            return accountSalt1;
        }
        if (guardian == guardians[1]) {
            return accountSalt2;
        }
        if (guardian == guardians[2]) {
            return accountSalt3;
        }

        revert("getAccountSaltForGuardian - Invalid guardian address");
    }

    function generateNewNullifier() public returns (bytes32) {
        return keccak256(abi.encode(nullifierCount++));
    }
}
