## ZK Email Recovery

## Overview

Account recovery has traditionally been one of the most complex UX hurdles that account holders have to contend with. The ZK Email Recovery contracts provide a robust and simple mechanism for account holders to recover modular accounts via email guardians.

Modular accounts get account recovery for 'free' by using our pre-deployed universal email recovery module. Since Safe's can be made 7579 compatible, the following contracts also support Safe account recovery out of the box too. For older existing Safes that are not compatible with ERC4337 (and subsequenty ERC7579), we provide a native Safe module too.

Modular account developers can easily integrate email recovery with richer and more specific commands in the email body by writing their own command handler contracts, which are designed to be simple and contain the modular account-specific logic to recover an account.

## Usage

### Install dependencies

```shell
pnpm install
```

### Build

```shell
pnpm build
# or
# forge build
```

### Test

```shell
pnpm test
# or
# forge test --match-path "test/**/*.sol" or
```

### Test for scripts

```shell
pnpm test:script
# or
# forge test --match-path "script/test/**/*.sol" --threads 1
```

# ZK Email Recovery

### EmailRecoveryManager.sol

`EmailRecoveryManager.sol` is an abstract contract that defines the main logic for email-based recovery. It is designed to provide the core logic for email based account recovery that can be used across different modular account implementations. For the end user, the core `EmailRecoveryManager` contract aims to provide a robust and simple mechanism to recover accounts via email guardians.

It inherits from a ZK Email contract called `EmailAccountRecovery.sol` which defines some basic recovery logic that interacts with lower level ZK Email contracts. `EmailAccountRecovery.sol` holds the logic that interacts with the lower level ZK Email contracts `EmailAuth.sol`, verifier, dkim registry etc. More info on the underlying `EmailAccountRecovery.sol` contract can be found [here](https://github.com/zkemail/ether-email-auth/tree/main/packages/contracts#emailaccountrecovery-contract).

The guardians are represented onchain by `EmailAuth.sol` instances. `EmailAuth.sol` is designed to authenticate that a user is a correct holder of the specific email address and authorize anything described in the email. The guardians privacy is protected onchain, for more info on ZK Email privacy and EmailAuth - see the [ZK Email docs](https://zkemail.gitbook.io/zk-email).

Note: `EmailAccountRecovery.sol` & `EmailAuth.sol` can be found in the [ether-email-auth](https://github.com/zkemail/ether-email-auth) repo

`EmailRecoveryManager` relies on a dedicated recovery module to execute a recovery attempt - the recovery module inherits from the email recovery manager contract. The `EmailRecoveryManager` contract defines "what a valid recovery attempt is for an account", and the recovery module defines “how that recovery attempt is executed on the account”. One motivation for having the 7579 recovery module and the core `EmailRecoveryManager` contract being seperated is to allow the core recovery logic to be used across different account implementations and module standards. The core `EmailRecoveryManager.sol` contract is designed to be account implementation agnostic. For example, we have a native Safe module as well as two 7579 modules that use the same underlying manager. It's functionality can be extended by creating new command handler contracts such as `EmailRecoveryCommandHandler.sol`.

## EmailRecoveryManager flow walkthrough

The core functions that must be called in the end-to-end flow for recovery are

1. configureRecovery (does not need to be called again for subsequent recovery attempts)
2. handleAcceptance - called for each guardian. Defined on `EmailAccountRecovery.sol`, calls acceptGuardian in this contract
3. handleRecovery - called for each guardian. Defined on `EmailAccountRecovery.sol`, calls processRecovery in this contract
4. completeRecovery

Before proceeding, ensure that you deploy the email recovery contracts via one of the email recovery factories.

### Configure Recovery

After deployment, this is the first core function in the recovery flow, setting up the recovery module, guardians, guardian weights, threshold, and delay/expiry. It only needs to be called once. The threshold must be set appropriately to balance security and usability. The same goes for the delay and expiry - there is a minimum recovery window time that protects against an account giving itself a prohibitively small window in which to complete a recovery attempt.

`configureRecovery` is called during the installation phase of the recovery module. This ensures that a user cannot forget to install the recovery module, go to configure recovery, and end up with a broken recovery config.

```ts
function configureRecovery(
    address[] memory guardians,
    uint256[] memory weights,
    uint256 threshold,
    uint256 delay,
    uint256 expiry
) external;
```

### Handle Acceptance

This function handles the acceptance of each guardian. Each guardian must accept their role to be a part of the recovery process. This is an important step as it ensures that the guardian consents to the responsibility of being a guardian for a specific account, is in control of the specific email address, and protects against typos from entering the wrong email. Such a typo would render the guardian unusable. `handleAcceptance` must be called for each guardian until the threshold is reached.

```ts
function handleAcceptance(
    address guardian,
    uint256 templateIdx,
    bytes[] memory commandParams,
    bytes32
) internal;
```

### Handle Recovery

This function processes each guardian's recovery request. A guardian can initiate a recovery request by replying to an email. The contract verifies the guardian's status and checks if the threshold is met. Once the threshold is met and the delay has passed, anyone can complete the recovery process. The recovery delay is a security feature that gives the wallet owner time to react to a recovery attempt in case of a malicious guardian or guardians. This is possible from guardians who act maliciously, but also from attackers who have access to a guardians email address. Although since guardian email privacy is preserved on chain, this reduces the attack surface further since someone with access to a someone elses email account would not automatically know if the email address is used in a recovery setup, or if they did, which account to target. They could find this information out by searching for recovery setup in the email inbox however. There is also an expiry time, which once expires, invalidates the recovery attempt. This encourages timely execution of recovery attempts and reduces the attack surface that could result from recovery attempts that have been stagnent and uncompleted for long periods of time.

```ts
function handleRecovery(
    address guardian,
    uint256 templateIdx,
    bytes[] memory commandParams,
    bytes32
) internal;
```

### Complete Recovery

The final function to complete the recovery process. This function completes the recovery process by validating the recovery request and triggering the recovery module to perform the recovery on the account itself.

```ts
function completeRecovery(address account, bytes memory recoveryCalldata) public;
```

## Command Handlers

Command handlers define the commands for recovery emails and how they should be validated. They are designed to be simple and self-contained contracts that hold the modular account-specific logic needed for adding email recovery. We currently define three command handlers. We have a universal command handler which essentially gives 7579 module developers recovery for free that is generic to any validator (so long as the validator has functionality to recover itself). We provide a Safe account command handler which provides email account recovery for Safe's. The third is an address hiding email command handler which offers offchain privacy protection for accounts from guardians.

Command handlers contain functions for defining the commands in the email body, of which there are two command types - acceptance and recovery commands. The acceptance command is for the email that is displayed to the guardian when they have to accept becoming a guardian for an account. The recovery command is for the email displayed to the guardian when an account is actually being recovered. Handlers also contain helper functions to extract the account address from both command types. The acceptance and recovery templates can be written to contain any functional info, but they must contain the account address. The command is an important part of the functional info that is used to generate and verify the zkp.

Once a new command has been written and audited, the deployment bytecode of the command handler can be passed into one of the provided factories, which ensures that the deployment of a module, manager and command handler are tightly coupled. The deployment of these contracts can be attested to via the use of an [ERC-7484 resistry](https://eips.ethereum.org/EIPS/eip-7484).

### Why write your own command handler?

The generic command handler supported out of the box is sufficiently generic for recovering any modular account via the use of a recovery hash in the command, which is validated against when executing recovery. A modular account developer may want to provide a more specifc and human readable command handler for their users. It's also possible to write a command template in a non-english language to support non-english speakers.

It is important to re-iterate that modular accounts already get account recovery out of the box with these contracts, via the use of the universal email recovery module.

### EmailRecoveryCommandHandler.sol

`EmailRecoveryCommandHandler` is a generic command handler that can be used to recovery any validator.

The acceptance command template is:
`Accept guardian request for {ethAddr}`

The recovery command template is:
`Recover account {ethAddr} using recovery hash {string}`

### SafeRecoveryCommandHandler.sol

`SafeRecoveryCommandHandler` is a specific command handler that can be used to recover a Safe. It provides a good example of how to write a custom command handler for a different account implementation. In contrast to the `EmailRecoveryCommandHandler`, the Safe command requires additional info in order to complete the recovery request.

The acceptance command remains the same as the acceptance command is already quite generic. This will be a common scenario where only the recovery command-related functions will need changing. A scenario in which you would definitely need to update both is if you wanted to provide email recovery functionality to users who didn't speak English. In which case you could translate the required commands into the chosen language.

The acceptance command template is:
`Accept guardian request for {ethAddr}`

The recovery command template is:
`Recover account {ethAddr} from old owner {ethAddr} to new owner {ethAddr}`

### AccountHidingRecoveryCommandHandler.sol

`AccountHidingRecoveryCommandHandler` is a specific command handler that can be used to recover a Safe. This command handler hashes the account address so that it is not revealed in recovery emails to guardians. This is important if an account does not want to easily reveal it's financial history to guardians. This handler is similar to the generic command handler except the account address is replaced by a hash.

The acceptance command template is:
`Accept guardian request for {string}`

The recovery command template is:
`Recover account {string} using recovery hash {string}`

## How you can write a custom command template

When you know what recovery specific information you need, you can create a new handler contract. The following functions must be implemented:

- `acceptanceCommandTemplates()`
- `extractRecoveredAccountFromAcceptanceCommand(bytes[],uint256)`
- `validateAcceptanceCommand(uint256,bytes[])`

- `recoveryCommandTemplates()`
- `extractRecoveredAccountFromRecoveryCommand(bytes[],uint256)`
- `validateRecoveryCommand(uint256,bytes[])`

- `parseRecoveryDataHash(uint256,bytes[])`

### How a command is interpreted

With an email command of:

```bash
Recover account 0x50Bc6f1F08ff752F7F5d687F35a0fA25Ab20EF52 to new owner 0x7240b687730BE024bcfD084621f794C2e4F8408f
```

Where the first address in the command is the account address recovery is being executed for, and the second is the new owner address. This command would lead to the the following command params

The command params would be:

```ts
bytes[] memory commandParamsForRecovery = new bytes[](2);
commandParamsForRecovery[0] = abi.encode(accountAddress);
commandParamsForRecovery[1] = abi.encode(newOwner);
```

### What can I add to a command template?

A command template defines the expected format of the message in the command for each recovery implementation. The underlying ZK Email contracts are generic for any command, negating some type and size constraints, so developers can write application-specific messages without writing new zk circuits. The use of different command templates in this case allows for a flexible and extensible mechanism to define recovery messages, making it adaptable to different modular account implemtations. For recovery commands using these contracts, the email commands can be completely generic, but they **must** return the account address for which recovery is for.

The command template is an array of strings, each of which has some fixed strings without space and the following variable parts. Command variables must meet the following type constraints:

- `"{string}"`: a string. Its Solidity type is `string`. The command string type can be used to add the solidity `bytes` type to commands.
- `"{uint}"`: a decimal string of the unsigned integer. Its Solidity type is `uint256`.
- `"{int}"`: a decimal string of the signed integer. Its Solidity type is `int256`.
- `"{decimals}"`: a decimal string of the decimals. Its Solidity type is `uint256`. Its decimal size is fixed to 18. E.g., “2.7” ⇒ `abi.encode(2.7 * (10**18))`.
- `"{ethAddr}"`: a hex string of the Ethereum address. Its Solidity type is `address`. Its value MUST satisfy the checksum of the Ethereum address.

If you are recovering an account that needs to rotate a public key which is of type `bytes` in solidity, you can use the string type for that for the command template. To read more about the underlying ZK Email contracts that this repo uses, take a look at the [ether-email-auth](https://github.com/zkemail/ether-email-auth) repo.

### EmailRecoveryModule.sol

A recovery module that recovers a specific validator.

The target validator and target selector are passed into the module when it is deployed. This means that the module is less generic, but the module is simpler and provides less room for error when confiuring recovery. This is because the module does not have to handle permissioning multiple validators and there is less room for configuration error when installing the module, as the target validator and selector are passed in at deployment instead.

The `recover()` function on the module is the key entry point where recovery is executed. This function is called from the recovery manager once a recovery attempt has been processed. The function that calls `recover()` from `EmailRecoveryManager.sol` is `completeRecovery()` which can be called by anyone, but normally the relayer. It is the final function that is called once a recovery request becomes valid.

`completeRecovery()` calls `recover()` which calls executeFromExecutor to execute the account specific recovery logic. The call from the executor retains the context of the account so the `msg.sender` of the next call is the account itself. This simplifies access control in the validator being recovered as it can just do a `msg.sender` check.

When writing a custom command handler, an account developer would likely chose to deploy a `EmailRecoveryModule` instance rather than a `UniversalEmailRecoveryModule` instance. This is because a custom command handler would likely be specific to an validator implementation, so using the recovery module for specific validators is more appropriate than the generic recovery module.

**Note:** This module is an executor and does not abide by the 4337 validation rules. The `onInstall` function breaks the validation rules and it is possible for it to be called during account deployment in the first userOp. So you cannot install this module during account deployment as onInstall will be called as part of the validation phase. Supporting executor initialization during account deployment is not mandated by ERC7579 - if required, install this module after the account has been setup.

### UniversalEmailRecoveryModule.sol

A recovery module that recovers any validator.

The target validator and target selector are passed into the module when it is installed. This means that the module is generic and can be used to recover any 7579 validator. The module is slightly more complex as it has to handle permissioning multiple validators. Additionally there is a slightly higher chance of configuration error when installing the module as the target validator and selector are passed in at this stage instead of when the module is deployed.

The `recover()` function on the module is the key entry point where recovery is executed. This function is called from the recovery manager. The function that calls `recover()` from `EmailRecoveryManager.sol` is `completeRecovery()` which can be called by anyone, but normally the relayer. It is the final function that is called once a recovery request becomes valid.

`completeRecovery()` calls `recover()` which calls executeFromExecutor to execute the account specific recovery logic. The call from the executor retains the context of the account so the `msg.sender` of the next call is the account itself. This simplifies access control in the validator being recovered as it can just do a `msg.sender` check.

**Note:** This module is an executor and does not abide by the 4337 validation rules. The `onInstall` function breaks the validation rules and it is possible for it to be called during account deployment in the first userOp. So you cannot install this module during account deployment as `onInstall` will be called as part of the validation phase. Supporting executor initialization during account deployment is not mandated by ERC7579 - if required, install this module after the account has been setup.

### SafeEmailRecoveryModule.sol

A recovery module that specifically recovers a Safe.

The target selector is hardcoded as a constant variable, as the recovery function is stable. As with the other two modules, the `recover()` function on the module is the key entry point where recovery is executed, it is called in the same way as the other two modules from the manager.

`completeRecovery()` calls `recover()` which calls `execTransactionFromModule` to execute the recovery attempt. `execTransactionFromModule` can only be called from an installed Safe module.

### EmailRecoveryFactory.sol

The factory for deploying new instances of `EmailRecoveryModule.sol` and associated command handlers. The factory ensures there is a tight coupling between a deployed module and a command handler.

The deployment function for this factory deploys an `EmailRecoveryModule`, which takes a target validator and function selector. The other values passed into the deployment function are the same as the `EmailRecoveryUniversalFactory`, which include deployment salts, command handler bytecode, and a dkim registry.

When deploying a new recovery module for a specific validator with a more human readable command, modular account developers can write their own command handler and pass the deployment bytecode of that handler into the factory. The security of each module deployment and associated contracts can then be attested to via an ERC7484 registry.

### EmailRecoveryUniversalFactory.sol

The factory for deploying new instances of `UniversalEmailRecoveryModule.sol` and associated command handlers.

The deployment function for this factory deploys an `UniversalEmailRecoveryModule`, which takes deployment salts, command handler bytecode, and a dkim registry as arguments. The target validator and target function selector are set when the universal module is installed.

While the command handler for `EmailRecoveryUniversalFactory` will be more stable in comparison to a command handlers used for `EmailRecoveryModule`, developers may want to write a generic command handler in a slightly different way, or even in a non-english lanaguage, so the bytecode is still passed in here directly. The security of each module deployment and associated contracts can then be attested to via an ERC7484 registry.

## How to deploy to a new network

To deploy a recovery module and associated contracts to a new network you'll need to run either one or two deployment scripts. First, check out the [deployed contracts page](https://docs.zk.email/account-recovery/deployed-contracts) on our website. If the `UserOverrideableDKIMRegistry`, `Groth16Verifier`, `Verifier` and `EmailAuth` have already been deployed on your chosen network, you only need to run the deployment script in this repo.

### Contracts

### Deploying all contracts - `email-tx-builder` and `email-recovery`

If the `UserOverrideableDKIMRegistry`, `Groth16Verifier`, `Verifier` and `EmailAuth` have not been deployed on your chosen network, you'll need to run two scripts. You'll need to clone [email-tx-builder/email-recovery](https://github.com/zkemail/email-tx-builder/tree/email-recovery), and then this repo [email-recovery](https://github.com/zkemail/email-recovery). `email-tx-builder` includes the deployment scripts to deploy the DKIM regsitry, the Verifer and the generic ZK Email contracts that the recovery module uses. This repo `email-recovery` holds the recovery-specific contracts.

1. Run the [DeployRecoveryController.s.sol](https://github.com/zkemail/email-tx-builder/blob/email-recovery/packages/contracts/script/DeployRecoveryController.s.sol) script in `email-tx-builder/email-recovery`. The key values you want here are the `UseroverrideableDKIMRegistry`, `Verifier` (not `Groth16Verifier`), and the`EmailAuth` implementation address - save these and add them to your `.env` in this repo - `email-recovery`
2. Once you have those 3 addresses, you need to run the following script in [email-recovery](https://github.com/zkemail/email-recovery/blob/main/script/DeployUniversalEmailRecoveryModule.s.sol).
3. Then you will have a new instance of the `UniversalEmailRecoveryModule` deployed and you are ready to test it. To see a working example of how you can add the module to a 7579 account and execute recovery, you can check out the permissionless scripts [here](https://github.com/zkemail/email-recovery-example-scripts), which has an [accompanying guide](https://docs.zk.email/account-recovery/permissionless-guide).

### Deploying email-recovery contracts

If the `UserOverrideableDKIMRegistry`, `Groth16Verifier`, `Verifier` and `EmailAuth` have not been deployed on your chosen network, you can run everything from one script in this repo.

1. Set the required environment variables in your `.env` file. Run the following script in [email-recovery](https://github.com/zkemail/email-recovery/blob/main/script/DeployUniversalEmailRecoveryModule.s.sol).
2. Once everything is deployed, you will have a new instance of the `UniversalEmailRecoveryModule` along with the accomanying ZK Email contracts. To see a working example of how you can add the module to a 7579 account and execute recovery, you can check out the permissionless scripts [here](https://github.com/zkemail/email-recovery-example-scripts), which has an [accompanying guide](https://docs.zk.email/account-recovery/permissionless-guide).

### Relayer

If a relayer is not running on the new network, you'll need to run that also. For the relayer, here are the instructions https://github.com/zkemail/email-tx-builder/blob/email-recovery/packages/relayer/README.md.

## Threat model

Importantly this contract offers the functonality to recover an account via email in a scenario where a private key has been lost. This contract does NOT provide an adequate mechanism to protect an account from a stolen private key by a malicious actor. This attack vector requires a holistic approach to security that takes specific implementation details of an account into consideration. For example, adding additional access control when cancelling recovery to prevent a malicious actor stopping recovery attempts, and adding spending limits to prevent account draining. Additionally, the current 7579 spec allows accounts to forcefully uninstall modules in the case of a malicious module, this means an attacker could forcefully uninstall a recovery module anyway. This is expected to be addressed in the future. This contract is designed to recover modular accounts in the case of a lost device/authentication method (private key), but does not provide adequate security for a scenario in which a malicious actor has control of the lost device/authentication method (private key).

## How to Debug Errors

If you get a revert error message, we recommend the following steps to debug it:

1. Get the first 4 bytes (0x + 8 hex characters) from the error message, denoting a signature of the custom error.
2. Search those bytes in [test/unit/assertErrorSelectors.t.sol](https://github.com/zkemail/email-recovery/blob/feat/body-parsing/test/unit/assertErrorSelectors.t.sol).
3. Check the following points according to the custom error type within the line that hit.

- `IEmailRecoveryManager.InvalidGuardianStatus.selector` (`0x5689b51a`): If you get this error when calling the `handleAcceptance` function, you might forget to call the `configureRecovery` function beforehand.

### If You Get Only '0x' as a Return Value

This usually means you're trying to call a contract or function that doesn't exist. Check if:

1. The contract address is correct and deployed
2. The function you're calling is defined correctly

You can verify contracts on block explorers or use cast commands to test contract calls. See these links for help:

https://book.getfoundry.sh/reference/cast/cast-call
https://book.getfoundry.sh/reference/cast/cast-send

For ZKSync, deploy libraries first and add their addresses to your Foundry or Hardhat settings. Make sure these addresses are correct.

### If You Get an Error Message as Bytes

The first 4 bytes are the function selector. The rest is the encoded error message.

Check this test file for a list of function selectors:
test/unit/assertErrorSelectors.t.sol

### Command Template Mismatch

We have three different command handlers. Each has its own expected commands for accept and recovery actions. If you get a command-related error, check which command handler you're using. You can do this with block explorers or cast commands.

## Support and Contact

We prioritize the security and user experience of ZK Email. If you encounter any issues or have questions, please contact us at:

- **Support Email**: [support@zk.email](mailto:support@zk.email)
- **Telegram groups**: [t.me/zkemail](https://t.me/zkemail)

Our team will respond quickly to help resolve any problems.
