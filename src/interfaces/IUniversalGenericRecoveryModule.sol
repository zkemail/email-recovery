// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IUniversalGenericRecoveryModule {
    function canStartRecoveryRequest(
        address account,
        address validator
    )
        external
        view
        returns (bool);
    /**
     * Returns validators in reverse order that they were added
     */
    function getAllowedValidators(address account) external view returns (address[] memory);
    /**
     * Returns selectors in reverse order that they were added
     */
    function getAllowedSelectors(address account) external view returns (bytes4[] memory);
}
