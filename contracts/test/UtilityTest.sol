// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/Utility.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title UtilityTest
  @author Cline AI Assistant
  @custom:terry "Test me, oh Lord, and try me; examine my heart and mind."

  Comprehensive tests for the Utility library functions.

  @custom:date January 11th, 2026.
*/
contract UtilityTest is Test {

    /**
      Test addressToString with a normal address.
    */
    function testAddressToString() public {
        address testAddr = 0x742d35cC6634c0532925A3b8d8d3D4e35c4a2F82;
        string memory result = Utility.addressToString(testAddr);
        assertEq(result, "742d35cc6634c0532925a3b8d8d3d4e35c4a2f82");
    }

    /**
      Test addressToString with zero address.
    */
    function testAddressToStringZeroAddress() public {
        address zeroAddr = address(0);
        string memory result = Utility.addressToString(zeroAddr);
        assertEq(result, "0000000000000000000000000000000000000000");
    }

    /**
      Test addressToString with max address.
    */
    function testAddressToStringMaxAddress() public {
        address maxAddr = address(type(uint160).max);
        string memory result = Utility.addressToString(maxAddr);
        assertEq(result, "ffffffffffffffffffffffffffffffffffffffff");
    }

    /**
      Test splitString with comma delimiter.
    */
    function testSplitString() public {
        string memory input = "hello,world,test";
        string[] memory result = Utility.splitString(input, bytes1(","));
        assertEq(result.length, 3);
        assertEq(result[0], "hello");
        assertEq(result[1], "world");
        assertEq(result[2], "test");
    }

    /**
      Test splitString with empty string.
    */
    function testSplitStringEmpty() public {
        string memory input = "";
        string[] memory result = Utility.splitString(input, bytes1(","));
        assertEq(result.length, 0);
    }

    /**
      Test splitString with no delimiters.
    */
    function testSplitStringNoDelimiters() public {
        string memory input = "nodividers";
        string[] memory result = Utility.splitString(input, bytes1(","));
        assertEq(result.length, 1);
        assertEq(result[0], "nodividers");
    }

    /**
      Test splitString with delimiters at start and end.
    */
    function testSplitStringDelimitersAtEnds() public {
        string memory input = ",middle,";
        string[] memory result = Utility.splitString(input, bytes1(","));
        assertEq(result.length, 3);
        assertEq(result[0], "");
        assertEq(result[1], "middle");
        assertEq(result[2], "");
    }

    /**
      Test splitString with consecutive delimiters.
    */
    function testSplitStringConsecutiveDelimiters() public {
        string memory input = "a,,b";
        string[] memory result = Utility.splitString(input, bytes1(","));
        assertEq(result.length, 3);
        assertEq(result[0], "a");
        assertEq(result[1], "");
        assertEq(result[2], "b");
    }

    /**
      Test splitString with single character.
    */
    function testSplitStringSingleCharacter() public {
        string memory input = "x";
        string[] memory result = Utility.splitString(input, bytes1(","));
        assertEq(result.length, 1);
        assertEq(result[0], "x");
    }

    /**
      Test splitString with only delimiter.
    */
    function testSplitStringOnlyDelimiter() public {
        string memory input = ",";
        string[] memory result = Utility.splitString(input, bytes1(","));
        assertEq(result.length, 2);
        assertEq(result[0], "");
        assertEq(result[1], "");
    }

    /**
      Test splitString with different delimiter (semicolon).
    */
    function testSplitStringDifferentDelimiter() public {
        string memory input = "one;two;three";
        string[] memory result = Utility.splitString(input, bytes1(";"));
        assertEq(result.length, 3);
        assertEq(result[0], "one");
        assertEq(result[1], "two");
        assertEq(result[2], "three");
    }

    /**
      Fuzz test addressToString with random addresses.
    */
    function testFuzzAddressToString(address _addr) public {
        string memory result = Utility.addressToString(_addr);
        // Result should always be 40 characters (20 bytes * 2 hex chars per byte)
        assertEq(bytes(result).length, 40);
        
        // Convert back to address to verify correctness
        // This is a simple way to verify the hex encoding is correct
        uint160 converted = 0;
        bytes memory resultBytes = bytes(result);
        
        for (uint256 i = 0; i < 40; i++) {
            converted *= 16;
            bytes1 char = resultBytes[i];
            if (char >= bytes1("0") && char <= bytes1("9")) {
                converted += uint160(uint8(char) - uint8(bytes1("0")));
            } else if (char >= bytes1("a") && char <= bytes1("f")) {
                converted += uint160(uint8(char) - uint8(bytes1("a")) + 10);
            }
        }
        
        assertEq(address(converted), _addr);
    }

    /**
      Fuzz test splitString with random single-character delimiters.
    */
    function testFuzzSplitString(string memory _input, uint8 _delimiterCode) public {
        // Skip null bytes and control characters
        vm.assume(_delimiterCode >= 32 && _delimiterCode <= 126);
        
        bytes1 delimiter = bytes1(_delimiterCode);
        string[] memory result = Utility.splitString(_input, delimiter);
        
        // Result should always have at least 1 element (even for empty string it returns empty array)
        if (bytes(_input).length == 0) {
            assertEq(result.length, 0);
        } else {
            assertTrue(result.length >= 1);
        }
    }
}