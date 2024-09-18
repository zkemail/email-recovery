// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { AccountInstance } from "modulekit/ModuleKit.sol";
import { ECDSAOwnedDKIMRegistry } from
    "@zk-email/ether-email-auth-contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

import { BaseTest } from "test/Base.t.sol";
import { MockGroth16Verifier } from "src/test/MockGroth16Verifier.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

abstract contract IntegrationBase is BaseTest {
    function setUp() public virtual override {
        super.setUp();
    }
}
