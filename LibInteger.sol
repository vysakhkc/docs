// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.11;
/**
 * @title LibInteger 
 * @dev Integer related utility functions
 */
library LibInteger
{    
    /**
     * @dev Safely multiply, revert on overflow
     * @param a The first number
     * @param b The second number
     * @return uint256 The answer
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint)
    {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
     * @dev Safely divide, revert if divisor is zero
     * @param a The first number
     * @param b The second number
     * @return uint256 The answer
    */
    function div(uint256 a, uint256 b) internal pure returns (uint)
    {
        require(b > 0, "");
        uint256 c = a / b;

        return c;
    }

    /**
     * @dev Safely substract, revert if answer is negative
     * @param a The first number
     * @param b The second number
     * @return uint256 The answer
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint)
    {
        require(b <= a, "");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Safely add, revert if overflow
     * @param a The first number
     * @param b The second number
     * @return uint256 The answer
    */
    function add(uint256 a, uint256 b) internal pure returns (uint)
    {
        uint256 c = a + b;
        require(c >= a, "");

        return c;
    }

    /**
     * @dev Convert number to string
     * @param value The number to convert
     * @return string The string representation
    */
    function toString(uint256 value) internal pure returns (string memory)
    {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        uint256 index = digits - 1;
        
        temp = value;
        while (temp != 0) {
            buffer[index--] = bytes1(uint8(48 + temp % 10));
            temp /= 10;
        }
        
        return string(buffer);
    }   
}

library WithPeriod {
    function get(uint256 periodDuration, uint8 offset, bool offsetBackward)
        internal
        view
        returns (uint256)
    {
        require(offset <= 3000, "range check 0..3000");

        uint256 rest = block.timestamp % periodDuration;
        uint256 start = block.timestamp - rest;

        if (offsetBackward) return start - offset * periodDuration;
        else return start + offset * periodDuration;
    }
}
