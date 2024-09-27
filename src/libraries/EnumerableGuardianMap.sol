// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * A struct representing the values required for a guardian
 */
struct GuardianStorage {
    GuardianStatus status;
    uint256 weight;
}

/**
 * An enum representing the possible status of a guardian
 * The default status is NONE status. It should be REQUESTED
 * when adding a guardian before the guardian has accepted.
 * Once the guardian has accepted, the status should be ACCEPTED.
 */
enum GuardianStatus {
    NONE,
    REQUESTED,
    ACCEPTED
}

/**
 * @title EnumerableGuardianMap
 * @notice Enumerable Map library based on Open Zeppelin's EnumerableMap library.
 * Modified to map from an address to a custom struct: GuardianStorage
 *
 * All functions have been modified to support mapping to the GuardianStorage
 * struct. Any additional modifications are documented in the natspec for
 * each function
 */
library EnumerableGuardianMap {
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * Maximum number of guardians that can be added
     */
    uint256 public constant MAX_NUMBER_OF_GUARDIANS = 32;

    error MaxNumberOfGuardiansReached();
    error TooManyValuesToRemove();

    struct AddressToGuardianMap {
        // Storage of keys
        EnumerableSet.AddressSet _keys;
        mapping(address key => GuardianStorage) _values;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     *
     * @custom:modification Modifed from the OpenZeppelin implementation to support a max number of
     * guardians.
     * This prevents the library having unbounded costs when clearing up state
     */
    function set(
        AddressToGuardianMap storage map,
        address key,
        GuardianStorage memory value
    )
        internal
        returns (bool)
    {
        map._values[key] = value;
        bool success = map._keys.add(key);

        uint256 length = map._keys.length();
        if (success && length > MAX_NUMBER_OF_GUARDIANS) {
            revert MaxNumberOfGuardiansReached();
        }
        return success;
    }

    /**
     * @dev Removes a key-value pair from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(AddressToGuardianMap storage map, address key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @dev Removes all key-value pairs from a map. O(n) where n <= 32
     *
     * @custom:modification This is a new function that did not exist on the
     * original Open Zeppelin library.
     */
    function removeAll(AddressToGuardianMap storage map, address[] memory guardianKeys) internal {
        if (guardianKeys.length > MAX_NUMBER_OF_GUARDIANS) {
            revert TooManyValuesToRemove();
        }
        for (uint256 i = 0; i < guardianKeys.length; i++) {
            delete map._values[guardianKeys[i]];
            map._keys.remove(guardianKeys[i]);
        }
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map
     *
     * @custom:modification The original
     * Open Zeppelin implementation threw an error if the value
     * could not be found. This implementation behaves as if you
     * were retrieving a value from an actual mapping i.e. returns
     * default solidity values
     */
    function get(
        AddressToGuardianMap storage map,
        address key
    )
        internal
        view
        returns (GuardianStorage memory)
    {
        return map._values[key];
    }

    /**
     * @dev Return an array containing all the keys. O(n) where n <= 32
     *
     * WARNING: This operation will copy the entire storage to memory, which could
     * be quite expensive.
     */
    function keys(AddressToGuardianMap storage map) internal view returns (address[] memory) {
        return map._keys.values();
    }

    // TODO: test
    // TODO: natspec
    function length(AddressToGuardianMap storage map) internal view returns (uint256) {
        return map._keys.length();
    }
}
