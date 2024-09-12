// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailRecoveryManager } from "./EmailRecoveryManager.sol";

/**
 * @title EmailRecoveryManagerZkSync
 * @notice Provides a mechanism for account recovery using email guardians on ZKSync networks.
 * @dev The underlying EmailAccountRecoveryZkSync contract provides some base logic for deploying
 * guardian contracts and handling email verification.
 */
abstract contract EmailRecoveryManagerZkSync is EmailRecoveryManager { }
