## ZK Email Recovery 7579 Plugin

## Usage

### Install dependencies

```shell
pnpm install
```

### Build

```shell
forge build
```

### Test

```shell
forge test
```

### invalid subject error
If you experience certain tests failing with the error `revert: invalid subject`. This means that there has been an update to one of the files that has resulted in the subject changing for the tests. The tests use hardcoded subjects, and when an address changes in the subject, these hardcoded values need to be updated. This is normally the recovery module address that needs updating when you change a core file like `ZkEmailRecovery.sol`. There is a known issue with CI being investiagted where a number of tests are failing because of this issue but local test runs pass successfully. If your local tests fail, you need to go to the base test files and uncomment the relevant console logs:
- If the test failing is located in test/integration/OwnableValidatorRecovery, then go to test/integration/OwnableValidatorRecovery/OwnableValidatorBase.t.sol
- If the test failing is located in test/integration/SafeRecoveryModule, then go to test/integration/SafeRecovery/SafeIntegrationBase.t.sol
- If the test failing is located in test/unit/, then go to test/unit/UnitBase.t.sol

Uncomment lines such as `console2.log("recoveryModule: ", recoveryModule);`, and then compare the hardcoded subjects to values printed in the console. If you uncomment the recovery module console log and see the following:
```bash
accountAddress:  0x50Bc6f1F08ff752F7F5d687F35a0fA25Ab20EF52
newOwner:  0x7240b687730BE024bcfD084621f794C2e4F8408f
recoveryModule:  0xbF6064f750F31Dc9c9E7347E0C2236Be80B014B4
```

But the hardcoded subject is:
```bash
Recover account 0x50Bc6f1F08ff752F7F5d687F35a0fA25Ab20EF52 to new owner 0x7240b687730BE024bcfD084621f794C2e4F8408f using recovery module 0x0957519DC28b1d289F4721244416C3F00033747c
```

You can see that the account address and new owner address are the same in the console and the same in the hardcoded value. As it is the recovery module address that is different, you will need to update the final address in the subjecy to the new recovery module address printed in the console.

# ZK Email Recovery

## High level contracts diagram.
TODO:

## Core contracts
The core contracts contain the bulk of the recovery logic.

### ZkEmailRecovery.sol

`ZkEmailRecovery.sol` defines a default implementation for email-based recovery. It is designed to provide the core logic for email based account recovery that can be used across different account implementations. For the end user, the core `ZkEMailRecovery` contract aims to provide a robust and simple mechanism to recover accounts via email guardians.

It inherits from a zk email contract called `EmailAccountRecovery.sol` which defines some basic recovery logic that interacts with lower level zk email contracts. `EmailAccountRecovery.sol` holds the logic that interacts with the lower level zk email contracts EmailAuth.sol, verifier, dkim registry etc. More info on the underlying EmailAccountRecovery.sol contract: https://github.com/zkemail/ether-email-auth/tree/main/packages/contracts#emailaccountrecovery-contract. 

The guardians are represented onchain by EmailAuth.sol instances. EmailAuth.sol is a lower level zk email contract, it is designed to be generic, and allows dapps to authorize anything described in an email. The guardians privacy is protected onchain, for more info on zk email privacy and EmailAuth - see the [zk email docs](https://zkemail.gitbook.io/zk-email).

ZkEmailRecovery relies on a dedicated recovery module to execute a recovery attempt. This (ZkEmailRecovery) contract defines "what a valid recovery attempt is for an account", and the recovery module defines “how that recovery attempt is executed on the account”. One motivation for having the 7579 recovery module and the core ZkEMailRecovery contract being seperated is to allow the core recovery logic to be used across different account implementations and module standards. The core `ZkEmailRecovery.sol` contract is designed to be account implementation agnostic and can be extended for a wide range of account implementations.

The core functions that must be called in the end-to-end flow for recovery are
1. configureRecovery (does not need to be called again for subsequent recovery attempts)
2. handleAcceptance - called for each guardian. Defined on EmailAccountRecovery.sol, calls acceptGuardian in this contract
3. handleRecovery - called for each guardian. Defined on EmailAccountRecovery.sol, calls processRecovery in this contract
4. completeRecovery

Importantly this contract offers the functonality to recover an account via email in a scenario where a private key has been lost. This contract does NOT provide an adequate mechanism to protect an account from a stolen private key by a malicious actor. This attack vector requires a holistic approach to security that takes specific implementation details of an account into consideration. For example, adding additional access control when cancelling recovery to prevent a malicious actor stopping recovery attempts, and adding spending limits to prevent account draining. This contract is designed to be extended to take these additional considerations into account, but does not provide them by default.

### EmailAccountRecoveryRouter.sol
`EmailAccountRecoveryRouter.sol` is a helper contract that routes relayer calls to the correct `EmailAccountRecovery` implementation. Originally, the abstract `EmailAccountRecovery.sol` contract was designed to be implemented on the acount contract itself (as opposed to a module), and so `completeRecovery()` did not have any context for which account to call, as it was assumed you were already calling the account - so no arguments needed. For account types such as a modular accounts that use modules/plugins that often share state among many accounts, you do need some context for which account you want to recover when calling completeRecovery. The rationale for the router is to provide a way to provide context for which account completeRecovery should target - **the key line of code that's used to do this is getAccountForRouter(msg.sender) in ZkEmailRecovery.sol**.

This represents a slight workaround as EmailAccountRecovery was already audited and the completeRecovery interface could not be changed - so the router could be removed in future iterations.

### SafeZkEmailRecovery.sol
`SafeZkEmailRecovery.sol` is an extension of `ZkEmailRecovery.sol` that implements recovery for Safe accounts. It provides a good example of how to extend `ZkEmailRecovery.sol` for different account implementations.


### How you can extend ZkEMailRecovery by adding a custom template

When you know what recovery specific information you need, you can create a new contract, inherit from `ZkEmailRecovery.sol` and extend the relevant functions - note you only have to extend ones that are relevant:
* `acceptanceSubjectTemplates()`
* `validateAcceptanceSubjectTemplates()`

* `recoverySubjectTemplates()`
* `validateRecoverySubjectTemplates()`

These functions, and the functions to validate the subject params are virtual so they can be overridden if a developer wants to change the subjects for a different implementation. A good example of this would be this code to add Safe compatibility (Safe recovery requires slightly different args in the subject). The account developer can choose any subject that they want if they override the default implementation. Here is some more info on subject params:

With an email subject of:
```bash
Recover account 0x50Bc6f1F08ff752F7F5d687F35a0fA25Ab20EF52 to new owner 0x7240b687730BE024bcfD084621f794C2e4F8408f using recovery module 0x344433E549E3F84B68D1aAC5b416Ac5cE2Be1063
```

Where the first address in the subject is accountAddress, second the oldOwner, third newOwner and forth the recoveryModule address

The subject params would be:

```ts
bytes[] memory subjectParamsForRecovery = new bytes[](3);
subjectParamsForRecovery[0] = abi.encode(accountAddress);
subjectParamsForRecovery[1] = abi.encode(oldOwner);
subjectParamsForRecovery[2] = abi.encode(newOwner);
subjectParamsForRecovery[3] = abi.encode(recoveryModule);
```

## 7579 Modules
The 7579 recovery modules are implementation specific and are the main contracts that define how a specific account is recovered. They are meant to make to be relatively simple for a module developer to build email recovery into an account.

The `recover()` function on the module holds the core logic for the module. It defines “how a recovery attempt is executed on the account”. This function must be called from the trusted recovery contract. The function that calls `recover()` from `ZkEmailRecovery.sol` is `completeRecovery()` which can be called by anyone, but normally the relayer. It is the final function that is called once a recovery attempt has been successful.

`completeRecovery()` calls into the account specific recovery module and can call executeFromExecutor to execute the account specific recovery logic. 

### OwnableValidatorRecoveryModule.sol
An example recovery module that recovers a 7579 OwnableValidator

### SafeRecoveryModule.sol
An example recovery module that recovers a Safe account