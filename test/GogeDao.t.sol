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

        gogeToken = new DogeGaySon(
            address(0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B), //0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B
            address(0xe142E9FCbd9E29C4A65C4979348d76147190a05a),
            100_000_000_000,
            address(0xa30D02C5CdB6a76e47EA0D65f369FD39618541Fe) // goge v1
        );
        
        gogeDao = new GogeDAO(
            address(gogeToken)
        );

    }

    function test_gogeDao_init_state() public {
        assertEq(address(gogeToken), gogeDao.governanceTokenAddr());
        assertEq(gogeDao.pollNum(), 0);
    }

    function test_gogeDao_createPoll() public {

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to add Joe to the naughty list";
        metadata.time1 = block.timestamp + 1 seconds;
        metadata.time2 = block.timestamp + 2 days;
        metadata.addr1 = address(joe);
        metadata.boolVar = true;

        gogeDao.createPoll(GogeDAO.PollType.modifyBlacklist, metadata);

        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.modifyBlacklist);

        emit log_string  (gogeDao.getMetadata(1).description);
        emit log_uint    (gogeDao.getMetadata(1).time1);
        emit log_uint    (gogeDao.getMetadata(1).time2);
        emit log_address (gogeDao.getMetadata(1).addr1);
        emit log_bool    (gogeDao.getMetadata(1).boolVar);
    }
}
