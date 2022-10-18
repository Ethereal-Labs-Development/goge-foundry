// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import { GogeDAO } from "../src/GogeDao.sol";
import { DogeGaySon } from "../src/GogeToken.sol";

contract DaoTest is Utility, Test {
    GogeDAO gogeDao;
    DogeGaySon gogeToken;

    function setUp() public {
        createActors();
        setUpTokens();
        
        gogeDao = new GogeDAO(
            address(gogeToken)
        );
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
