// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {stdMath} from "forge-std/StdMath.sol";

library EchidnaUtils {
    // platform-agnostic input restriction to easily
    // port fuzz tests between different fuzzers
    // adapted from https://github.com/crytic/properties/blob/main/contracts/util/PropertiesHelper.sol#L240-L259
    /// @notice Clamps value to be between low and high, both inclusive
    function clampBetween(
        uint256 value,
        uint256 low,
        uint256 high
    ) internal pure returns (uint256) {
        if (value < low || value > high) {
            uint ans = low + (value % (high - low + 1));
            return ans;
        }
        return value;
    }

    /// @notice int256 version of clampBetween
    function clampBetween(
        int256 value,
        int256 low,
        int256 high
    ) internal pure returns (int256) {
        if (value < low || value > high) {
            int range = high - low + 1;
            int clamped = (value - low) % (range);
            if (clamped < 0) clamped += range;
            int ans = low + clamped;
            return ans;
        }
        return value;
    }

    function isApproxEqRel(
        uint256 a,
        uint256 b,
        uint256 maxDelta
    ) internal pure returns (bool) {
        uint256 delta = stdMath.percentDelta(a, b);
        return delta <= maxDelta;
    }

    function isGreaterThanOrApproxEqRel(
        uint256 a,
        uint256 b,
        uint256 maxDelta
    ) internal pure returns (bool) {
        if (a >= b) return true;

        uint256 delta = stdMath.delta(a, b);
        return delta <= maxDelta;
    }
}

