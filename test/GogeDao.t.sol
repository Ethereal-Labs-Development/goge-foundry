// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import { GogeDAO } from "../src/GogeDao.sol";
import { DogeGaySon } from "../src/GogeToken.sol";

import { IUniswapV2Router02, IUniswapV2Router01, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";
import { ERC20 } from "../src/extensions/ERC20.sol";


contract DaoTest is Utility, Test {
    GogeDAO gogeDao;
    DogeGaySon gogeToken;

    address UNIV2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    function setUp() public {
        createActors();
        setUpTokens();

        gogeToken = new DogeGaySon(
            address(0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B),
            address(0xe142E9FCbd9E29C4A65C4979348d76147190a05a),
            100_000_000_000,
            address(0xa30D02C5CdB6a76e47EA0D65f369FD39618541Fe) // goge v1
        );

        uint BNB_DEPOSIT = 200 ether;
        uint TOKEN_DEPOSIT = 5000000000 ether;

        IWETH(WBNB).deposit{value: BNB_DEPOSIT}();

        // Approve TaxToken for UniswapV2Router.
        IERC20(address(gogeToken)).approve(
            address(UNIV2_ROUTER), TOKEN_DEPOSIT
        );

        IUniswapV2Router01(UNIV2_ROUTER).addLiquidityETH{value: 100 ether}(
            address(gogeToken),
            TOKEN_DEPOSIT,
            5_000_000_000 ether,
            100 ether,
            address(this),
            block.timestamp + 300
        );
        
        gogeDao = new GogeDAO(
            address(gogeToken)
        );

        gogeToken.enableTrading();
        gogeToken.setDAO(address(gogeDao));
    }

    function test_gogeDao_init_state() public {
        assertEq(address(gogeToken), gogeDao.governanceTokenAddr());
        assertEq(gogeDao.pollNum(), 0);
    }

    function test_gogeDao_createPoll() public {

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to add Joe to the naughty list";
        metadata.time2 = block.timestamp + 2 days;
        metadata.addr1 = address(joe);
        metadata.boolVar = true;

        // create poll
        gogeDao.createPoll(GogeDAO.PollType.modifyBlacklist, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.modifyBlacklist);

        assertEq(gogeDao.getMetadata(1).description, "I want to add Joe to the naughty list");
        assertEq(gogeDao.getMetadata(1).time1, block.timestamp);
        assertEq(gogeDao.getMetadata(1).time2, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).addr1, address(joe));
        assertEq(gogeDao.getMetadata(1).boolVar, true);

        // Emit poll data
        // emit log_string  (gogeDao.getMetadata(1).description);
        // emit log_uint    (gogeDao.getMetadata(1).time1);
        // emit log_uint    (gogeDao.getMetadata(1).time2);
        // emit log_address (gogeDao.getMetadata(1).addr1);
        // emit log_bool    (gogeDao.getMetadata(1).boolVar);
    }

    function test_gogeDao_addVote_state_change() public {

        test_gogeDao_createPoll();
        uint256 joe_votes = 10_000_000_000 ether;
        
        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Verify tokens were sent from Joe to Dao
        assertEq(gogeToken.balanceOf(address(joe)), 0);
        assertEq(gogeToken.balanceOf(address(gogeDao)), joe_votes);

        // Post-state check.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), joe_votes);
        assertEq(gogeDao.historicalTally(1), joe_votes);

        // Verify quorum
        uint256 num = (gogeDao.totalVotes(1) * 100) / gogeToken.getCirculatingMinusReserve(); // => 10%
        assertEq(num, 10);
    }

    function test_gogeDao_addVote_restrictions() public {

        test_gogeDao_createPoll();
        
        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), 1_000_000_000 ether);
        assertEq(gogeToken.balanceOf(address(joe)), 1_000_000_000 ether);

        // Approve tokens for vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), 1_000_000_000 ether));

        // Verify Joe cannot make more votes than the balance in his wallet.
        assert(!joe.try_addVote(address(gogeDao), 1, 1_000_000_000 ether + 1));

        // Verify Joe cannot make a vote on a poll that doesnt exist.
        assert(!joe.try_addVote(address(gogeDao), 2, 1_000_000_000 ether));

        // Warp 1 day ahead of start time. +1 day.
        vm.warp(block.timestamp + 1 days);

        // Verify Joe can make a vote on a poll that has not been closed.
        assert(joe.try_addVote(address(gogeDao), 1, 500_000_000 ether));

        // Verify tokens were sent from Joe to Dao
        assertEq(gogeToken.balanceOf(address(joe)), 500_000_000 ether);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 500_000_000 ether);

        // Warp to end time of poll 1. +2 days.
        vm.warp(block.timestamp + 1 days);

        // Verify Joe cannot make a vote on a poll that has been closed.
        assert(!joe.try_addVote(address(gogeDao), 1, 500_000_000 ether));
    }

    function test_gogeDao_addVote_fuzzing(uint256 joe_votes) public {

        test_gogeDao_createPoll();
        
        joe_votes = bound(joe_votes, 1, 95_000_000_000 ether);
        
        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Verify tokens were sent from Joe to Dao
        assertEq(gogeToken.balanceOf(address(joe)), 0);
        assertEq(gogeToken.balanceOf(address(gogeDao)), joe_votes);

        // Post-state check.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), joe_votes);
        assertEq(gogeDao.historicalTally(1), joe_votes);

        // Verify quorum
        uint256 num = (gogeDao.totalVotes(1) * 100) / gogeToken.getCirculatingMinusReserve(); // => 10%
        emit log_uint (num);
    }

    function test_gogeDao_addVote_quorum() public {

        test_gogeDao_createPoll();
        uint256 joe_votes = 50_000_000_000 ether;
        gogeDao.updateVetoEnabled(false);

        // Pre-state check.
        assertEq(gogeToken.isBlacklisted(address(joe)), false);
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 2 days);
        
        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Verify tokens were sent from Joe to Dao
        assertEq(gogeToken.balanceOf(address(joe)), 0);
        assertEq(gogeToken.balanceOf(address(gogeDao)), joe_votes);

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), joe_votes);
        assertEq(gogeDao.historicalTally(1), joe_votes);
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        // Verify quorum math.
        uint256 num = (gogeDao.totalVotes(1) * 100) / gogeToken.getCirculatingMinusReserve(); // => 10%
        assertTrue(num >= 50);

        // Post-state check => gogeToken.
        assertEq(gogeToken.isBlacklisted(address(joe)), true);
    }
}
