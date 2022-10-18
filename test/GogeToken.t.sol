// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import "../src/GogeToken.sol";

contract TokenTest is Utility, Test {
    DogeGaySon gogeToken;

    function setUp() public {
        createActors();
        setUpTokens();
        
        gogeToken = new DogeGaySon();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
