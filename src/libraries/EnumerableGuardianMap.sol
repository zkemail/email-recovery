// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

struct GuardianStorage {
    GuardianStatus status;
    uint256 weight;
}

enum GuardianStatus {
    NONE,
    REQUESTED,
    ACCEPTED
}

/**
 * Enumerable Map library based on Open Zeppelin's EnumerableMap library.
 * Modified to map from an address to a custom struct: GuardianStorage
 */
library EnumerableGuardianMap {
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @dev Query for a nonexistent map key.
     */
    error EnumerableMapNonexistentKey(address key);

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
     */
    function set(
        AddressToGuardianMap storage map,
        address key,
        GuardianStorage memory value
    ) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @dev Removes a key-value pair from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(
        AddressToGuardianMap storage map,
        address key
    ) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(
        AddressToGuardianMap storage map,
        address key
    ) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @dev Returns the number of key-value pairs in the map. O(1).
     */
    function length(
        AddressToGuardianMap storage map
    ) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @dev Returns the key-value pair stored at position `index` in the map. O(1).
     *
     * Note that there are no guarantees on the ordering of entries inside the
     * array, and it may change when more entries are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(
        AddressToGuardianMap storage map,
        uint256 index
    ) internal view returns (address, GuardianStorage memory) {
        address key = map._keys.at(index);
        return (key, map._values[key]);
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function get(
        AddressToGuardianMap storage map,
        address key
    ) internal view returns (GuardianStorage memory) {
        return map._values[key];
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(
        AddressToGuardianMap storage map
    ) internal view returns (address[] memory) {
        return map._keys.values();
    }
}
