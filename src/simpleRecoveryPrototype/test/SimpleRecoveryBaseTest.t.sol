// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";
import { RhinestoneModuleKit, AccountInstance } from "modulekit/ModuleKit.sol";
import { SimpleRecoveryModule } from "../modules/SimpleRecoveryModule.sol";
import { EmailRecoveryCommandHandler } from "../../handlers/EmailRecoveryCommandHandler.sol";
import "../interfaces/ISimpleGuardianManager.sol";
import {
    EmailAuth,
    EmailAuthMsg,
    EmailProof
} from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { CommandUtils } from "@zk-email/ether-email-auth-contracts/src/libraries/CommandUtils.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { MockGroth16Verifier } from "src/test/MockGroth16Verifier.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

abstract contract BaseTest is RhinestoneModuleKit, Test {
    using Strings for uint256;

    // Core contracts
    address public zkEmailDeployer;
    SimpleRecoveryModule public recoveryModule;
    UserOverrideableDKIMRegistry public dkimRegistry;
    MockGroth16Verifier public verifier;
    EmailAuth public emailAuthImpl;

    OwnableValidator public validator;
    address public accountAddress1;
    
    address public eoaGuardian1;
    address public eoaGuardian2;

    address public emailGuardian1;
    
    address public owner1;
    address public newOwner;

    AccountInstance public instance1;
    AccountInstance public instance2;

    address public accountAddress2;
    
    address public killSwitchAuthorizer;

    // public Account salts
    bytes32 public accountSalt1;
    bytes32 public accountSalt2;
    bytes32 public accountSalt3;

    // Configuration
    bytes32[] public accountSalts;
    address[] public guardians;
    uint256[] public weights;
    ISimpleGuardianManager.GuardianType[] public guardianTypes;

    uint256 public threshold;
    uint256 public delay;
    uint256 public expiry;
    uint256 public totalWeight;

    // Email verification constants
    string public constant DOMAIN_NAME = "gmail.com";
    bytes32 public constant PUBLIC_KEY_HASH = 0x0ea9c777dc7110e5a9e89b13f0cfc540e3845ba120b2b6dc24024d61488d4788;
    uint256 public constant MINIMUM_DELAY = 12 hours;
    bytes4 public constant RECOVERY_SELECTOR = bytes4(keccak256(bytes("changeOwner(address)")));

    EmailRecoveryCommandHandler public commandHandler;
    address public simpleRecoveryaddress;

    bytes public recoveryData;
    bytes32 public recoveryDataHash;
    
    bytes public recoveryCallData;
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      TEST SETUP FUNCTION                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Initializes the testing environment by setting up the account instances, 
     *         deploying contracts, and configuring the recovery module with mock data.
     * 
     * @dev This function:
     *  - Creates mock accounts (owner1 and newOwner) and funds them.
     *  - Deploys core contracts such as `OwnableValidator`, `EmailAuth`, `DKIMRegistry`, 
     *    `EmailRecoveryCommandHandler`, and `SimpleRecoveryModule`.
     *  - Configures the `recoveryModule` with mixed guardians (EOA and EmailVerified).
     *  - Prepares the initial recovery data for tests.
     */
    function setUp() public virtual {
        init();
        
        newOwner = vm.createWallet("newOwner").addr;

        // Deploy and fund the accounts
        instance1 = makeAccountInstance("account1");
        instance2 = makeAccountInstance("account2");

        validator = new OwnableValidator();
        accountAddress1 = address(validator);
        owner1 = instance2.account;
        
        vm.deal(address(instance2.account), 10 ether);

        accountSalt1 = keccak256(abi.encode("account salt 1"));
        accountSalt2 = keccak256(abi.encode("account salt 2"));
        accountSalt3 = keccak256(abi.encode("account salt 3"));

        zkEmailDeployer = vm.addr(1);
        killSwitchAuthorizer = vm.addr(2);

        vm.startPrank(zkEmailDeployer);

        uint256 setTimeDelay = 0;
        UserOverrideableDKIMRegistry overrideableDkimImpl = new UserOverrideableDKIMRegistry();
        ERC1967Proxy dkimProxy = new ERC1967Proxy(
            address(overrideableDkimImpl),
            abi.encodeCall(
                overrideableDkimImpl.initialize, (zkEmailDeployer, zkEmailDeployer, setTimeDelay)
            )
        );
        dkimRegistry = UserOverrideableDKIMRegistry(address(dkimProxy));

        dkimRegistry.setDKIMPublicKeyHash(DOMAIN_NAME, PUBLIC_KEY_HASH, zkEmailDeployer, new bytes(0));

        verifier = new MockGroth16Verifier();
        emailAuthImpl = new EmailAuth();
        vm.stopPrank();
        
        eoaGuardian1 = makeAddr("eoaGuardian1");
        eoaGuardian2 = makeAddr("eoaGuardian2");

        commandHandler = new EmailRecoveryCommandHandler();
        
        accountSalts = new bytes32[](3);
        accountSalts[0] = keccak256(abi.encode("salt1"));
        accountSalts[1] = keccak256(abi.encode("salt2"));
        accountSalts[2] = keccak256(abi.encode("salt3"));

        emailAuthImpl = new EmailAuth();

        // Prepare recovery data
        recoveryData = abi.encode(
            address(owner1),
            abi.encodeWithSelector(RECOVERY_SELECTOR, accountAddress1)
        );
        recoveryDataHash = keccak256(recoveryData);

        // Deploy recovery module
        recoveryModule = new SimpleRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl), // emailAuthImpl
            address(commandHandler), // commandHandler
            MINIMUM_DELAY,
            killSwitchAuthorizer,
            address(accountAddress1), // Initial validator
            RECOVERY_SELECTOR
        );

        // Compute email guardian addresses
        emailGuardian1 = recoveryModule.computeEmailAuthAddress(
            address(owner1),
            accountSalts[1]
        );

        // Setup mixed guardians (2 EOA, 1 Email)
        guardians = new address[](3);
        weights = new uint256[](3);
        guardianTypes = new ISimpleGuardianManager.GuardianType[](3);

        // EOA Guardian 1
        guardians[0] = eoaGuardian1;
        weights[0] = 1;
        guardianTypes[0] = ISimpleGuardianManager.GuardianType.EOA;

        // EOA Guardian 2
        guardians[1] = eoaGuardian2;
        weights[1] = 1;
        guardianTypes[1] = ISimpleGuardianManager.GuardianType.EOA;

        // Email Guardian
        guardians[2] = emailGuardian1;
        weights[2] = 1;
        guardianTypes[2] = ISimpleGuardianManager.GuardianType.EmailVerified;

        // Set recovery configuration
        threshold = 2;
        delay = 1 days;
        expiry = 7 days;
        // simpleRecoveryaddress = address(recoveryModule);
    }
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   GENERATE MOCK EMAIL PROOF                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Generates a mock `EmailProof` for testing email verification logic.
     * 
     * @dev This function creates a proof with pre-defined data for:
     *  - Domain name (`gmail.com`) and a public key hash (`PUBLIC_KEY_HASH`).
     *  - Command string (`maskedCommand`) for validation.
     *  - Nullifier to prevent replay attacks.
     *  - Account salt for generating unique proofs.
     * 
     * @param command The command string used to create the masked proof.
     * @param nullifier The nullifier that makes each proof unique and prevents reuse.
     * @param accountSalt The account-specific salt used in the verification process.
     * @return emailProof A populated `EmailProof` struct.
     */

    function generateMockEmailProof(
        string memory command,
        bytes32 nullifier,
        bytes32 accountSalt
    )
        public
        view
        returns (EmailProof memory)
    {
        EmailProof memory emailProof;
        emailProof.domainName = "gmail.com";
        emailProof.publicKeyHash = PUBLIC_KEY_HASH;
        emailProof.timestamp = block.timestamp;
        emailProof.maskedCommand = command;
        emailProof.emailNullifier = nullifier;
        emailProof.accountSalt = accountSalt;
        emailProof.isCodeExist = true;
        emailProof.proof = bytes("0");

        return emailProof;
    }
}