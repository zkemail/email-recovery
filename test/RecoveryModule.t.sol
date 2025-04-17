// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {RhinestoneModuleKit, ModuleKitHelpers, AccountInstance} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {OwnableValidator} from "@rhinestone/core-modules/src/OwnableValidator/OwnableValidator.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {RecoveryModule} from "../src/RecoveryModule.sol";
import {ECDSAGuardian} from "../src/ECDSAGuardian.sol";

contract RecoveryModuleTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;

    RecoveryModule public recoveryModule;
    OwnableValidator public validator;

    address public recoveryModuleAddress;
    address public validatorAddress;

    ECDSAGuardian public ecdsaGuardian;
    address public ecdsaGuardianAddress;
    address public ecdsaGuardianSigner;
    uint256 public ecdsaGuardianSignerPk;

    AccountInstance public account;
    address public accountAddress;

    address[] public owners;
    uint256[] public ownerPks;
    uint256 public ownersThreshold;

    address[] public guardians;
    uint256 public recoveryThreshold;
    uint256 public delay;
    uint256 public expiry;

    function setUp() public {
        recoveryModule = new RecoveryModule();
        validator = new OwnableValidator();

        recoveryModuleAddress = address(recoveryModule);
        validatorAddress = address(validator);

        (ecdsaGuardianSigner, ecdsaGuardianSignerPk) = makeAddrAndKey(
            "ecdsaGuardianSigner"
        );
        ECDSAGuardian ecdsaGuardianImpl = new ECDSAGuardian();
        ERC1967Proxy ecdsaGuardianProxy = new ERC1967Proxy(
            address(ecdsaGuardianImpl),
            abi.encodeCall(ecdsaGuardianImpl.initialize, (ecdsaGuardianSigner))
        );
        ecdsaGuardian = ECDSAGuardian(address(ecdsaGuardianProxy));
        ecdsaGuardianAddress = address(ecdsaGuardianProxy);

        account = makeAccountInstance("account");
        accountAddress = account.account;

        vm.deal(address(accountAddress), 10 ether);

        owners = new address[](2);
        owners[0] = vm.createWallet("owner1").addr;
        owners[1] = vm.createWallet("owner2").addr;
        ownersThreshold = 2;

        recoveryThreshold = 1;
        delay = 1 days;
        expiry = 2 weeks;

        guardians = new address[](1);
        guardians[0] = ecdsaGuardianAddress;

        (owners, ) = generateAndsortOwners();
        bytes memory data = abi.encode(ownersThreshold, owners);

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
                recoveryThreshold,
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

    function test_RecoveryModule_RecoversAValidator() public {
        bytes4 functionSelector = bytes4(
            keccak256(bytes("setThreshold(uint256)"))
        );
        bytes memory recoveryCalldata = abi.encodeWithSelector(
            functionSelector,
            1
        );

        bytes32 hash = keccak256(recoveryCalldata);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ecdsaGuardianSignerPk, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        recoveryModule.approveRecovery(
            accountAddress,
            validatorAddress,
            ecdsaGuardianAddress,
            signature,
            hash
        );

        vm.warp(block.timestamp + delay);

        uint256 thresholdBefore = validator.threshold(accountAddress);
        recoveryModule.executeRecovery(
            accountAddress,
            validatorAddress,
            recoveryCalldata
        );
        uint256 thresholdAfter = validator.threshold(accountAddress);

        assertEq(thresholdBefore, 2);
        assertEq(thresholdAfter, 1);
    }
}
