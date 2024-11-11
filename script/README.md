# ZK Email Recovery Deployment Scripts

This directory contains scripts for deploying various ZK Email recovery modules and related contracts. It is possible to combine different command handlers with different modules. Each deployment script directory has an account hiding script. The account hiding feature means that guardians cannot see what account they are recovering in emails. Guardians can still find the address onchain however.

### `BaseDeployScript.s.sol`

Base script with helper functions for deploying common contracts like Verifier and DKIM Registry.

### `ComputeSafeRecoveryCalldata.s.sol`

Utility script to compute calldata for Safe recovery. Used by 7579 safes and non-7579 Safes.

## `7579/`

Contains deployment scripts for 7579-compatible recovery modules. Find more information on 7579 on the [ERC7579 website](https://erc7579.com/)

## `EmailRecoveryModule/`

### `DeployEmailRecoveryModule.s.sol`

Deploys a validator specific recovery module. This module type is coupled to a specific validator address

### `DeployEmailRecoveryModuleWithAccountHiding.s.sol`

Deploys a validator specific recovery module with additional account address hiding features for enhanced privacy in emails

## `UniversalEmailRecoveryModule/`

### `DeployUniversalEmailRecoveryModule.s.sol`

Deploys a generic recovery module that can be used with any 7579 validator

### `DeployUniversalEmailRecoveryModuleWithAccountHiding.s.sol`

Deploys an generic recovery module with additional account address hiding features for enhanced privacy in emails

## `Safe/`

Contains deployment scripts for Safe-specific recovery modules that do not use ERC7579. This is useful for existing Safes that are not 4337 compatible (versions below `v1.4.1`), and also newer Safes that do not want a dependency on ERC7579.

### `DeploySafeRecovery.s.sol`

Deploys a [native safe module](https://docs.safe.global/advanced/smart-account-modules) for ZK Email recovery

### `DeploySafeRecoveryWithAccountHiding.s.sol`

Deploys a [native safe module](https://docs.safe.global/advanced/smart-account-modules) for ZK Email recovery with additional account address hiding features for enhanced privacy in emails

## `Safe7579/`

Contains deployment scripts for Safe 7579-compatible recovery modules using ZK Email. For more information on how Safe's interact with 7579, visit the [Safe7579 project](https://github.com/rhinestonewtf/safe7579).

### `DeploySafeRecovery.s.sol`

Deploys a 7579-compatible Safe recovery module

### `DeploySafeRecoveryWithAccountHiding.s.sol`

Deploys Safe recovery module with additional account address hiding features for enhanced privacy in emails
