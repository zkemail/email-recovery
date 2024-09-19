// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseTest } from "test/Base.t.sol";

abstract contract IntegrationBase is BaseTest {
    function setUp() public virtual override {
        super.setUp();
    }
}
