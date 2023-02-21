// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import { GogeDAO } from "../src/GogeDao.sol";
import { DogeGaySon } from "../src/GogeToken.sol";

import { IUniswapV2Router02, IUniswapV2Router01, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";
import { IGogeERC20 } from "../src/extensions/IGogeERC20.sol";

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

        uint256 BNB_DEPOSIT = 200 ether;
        uint256 TOKEN_DEPOSIT = 5000000000 ether;

        IWETH(WBNB).deposit{value: BNB_DEPOSIT}();

        // Approve TaxToken for UniswapV2Router.
        IERC20(address(gogeToken)).approve(
            address(UNIV2_ROUTER),
            TOKEN_DEPOSIT
        );

        IUniswapV2Router01(UNIV2_ROUTER).addLiquidityETH{value: 100 ether}(
            address(gogeToken),
            TOKEN_DEPOSIT,
            5_000_000_000 ether,
            100 ether,
            address(this),
            block.timestamp + 300
        );

        gogeDao = new GogeDAO(address(gogeToken));

        gogeToken.enableTrading();
        gogeToken.setGogeDao(address(gogeDao));
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

        assertEq(
            gogeDao.getMetadata(1).description,
            "I want to add Joe to the naughty list"
        );
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
        assert(
            joe.try_approveToken(
                address(gogeToken),
                address(gogeDao),
                joe_votes
            )
        );
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Verify tokens were sent from Joe to Dao
        assertEq(gogeToken.balanceOf(address(joe)), 0);
        assertEq(gogeToken.balanceOf(address(gogeDao)), joe_votes);

        // Post-state check.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), joe_votes);
        assertEq(gogeDao.historicalTally(1), joe_votes);

        // Verify quorum
        uint256 num = (gogeDao.totalVotes(1) * 100) /
            gogeToken.getCirculatingMinusReserve(); // => 10%
        assertEq(num, 10);
    }

    function test_gogeDao_addVote_restrictions() public {
        test_gogeDao_createPoll();

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), 1_000_000_000 ether);
        assertEq(gogeToken.balanceOf(address(joe)), 1_000_000_000 ether);

        // Approve tokens for vote.
        assert(
            joe.try_approveToken(
                address(gogeToken),
                address(gogeDao),
                1_000_000_000 ether
            )
        );

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
        uint256 num = (gogeDao.totalVotes(1) * 100) /
            gogeToken.getCirculatingMinusReserve(); // => 10%
        emit log_uint(num);
    }

    function test_gogeDao_addVote_quorum() public {
        test_gogeDao_createPoll();
        uint256 joe_votes = 50_000_000_000 ether;
        gogeDao.setGateKeeping(false);

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

        // Verify tokens Joe is holding the token balance since poll was passed.
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 0);

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), joe_votes);
        assertEq(gogeDao.historicalTally(1), joe_votes);
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        // Verify quorum math.
        uint256 num = (gogeDao.totalVotes(1) * 100) / gogeToken.getCirculatingMinusReserve();
        assertTrue(num >= gogeDao.quorum());

        // Post-state check => gogeToken.
        assertEq(gogeToken.isBlacklisted(address(joe)), true);
    }

    /// @notice passes a funding poll but ensures the tokens are refunded to all voters.
    function test_gogeDao_refundVotersPostChange() public {

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose a funding";
        metadata.time2 = block.timestamp + 2 days;
        metadata.addr1 = address(joe);
        metadata.addr2 = BUSD;
        metadata.amount = 1_000 ether;

        // create poll
        gogeDao.createPoll(GogeDAO.PollType.funding, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.funding);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose a funding");
        assertEq(gogeDao.getMetadata(1).time1, block.timestamp);
        assertEq(gogeDao.getMetadata(1).time2, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).addr1, address(joe));
        assertEq(gogeDao.getMetadata(1).addr2, BUSD);
        assertEq(gogeDao.getMetadata(1).amount, 1_000 ether);

        // ~~ pass poll ~~
        
        uint256 tim_votes = 24_000_000_000 ether;
        uint256 jon_votes = 20_000_000_000 ether;
        uint256 joe_votes = 6_000_000_000 ether;
        gogeDao.setGateKeeping(false);

        mint("BUSD", address(gogeDao), 1_000 ether);

        // Pre-state check.
        assertEq(IERC20(BUSD).balanceOf(address(joe)), 0);
        assertEq(IERC20(BUSD).balanceOf(address(gogeDao)), 1_000 ether);
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 2 days);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(tim), tim_votes);
        gogeToken.transfer(address(jon), jon_votes);
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(tim)), tim_votes);
        assertEq(gogeToken.balanceOf(address(jon)), jon_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        /// NOTE addVotes -> Tim

        // Approve the transfer of tokens and add vote for tim.
        assert(tim.try_approveToken(address(gogeToken), address(gogeDao), tim_votes));
        assert(tim.try_addVote(address(gogeDao), 1, tim_votes));

        // Verify tokens were sent from Tim to Dao
        assertEq(gogeToken.balanceOf(address(tim)), 0);
        assertEq(gogeToken.balanceOf(address(gogeDao)), tim_votes);

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(tim)), tim_votes);
        assertEq(gogeDao.totalVotes(1),tim_votes);
        assertEq(gogeDao.historicalTally(1), tim_votes);
        assertEq(gogeDao.passed(1), false);

        /// NOTE addVotes -> Jon

        // Approve the transfer of tokens and add vote for jon.
        assert(jon.try_approveToken(address(gogeToken), address(gogeDao), jon_votes));
        assert(jon.try_addVote(address(gogeDao), 1, jon_votes));

        // Verify tokens were sent from Jon to Dao
        assertEq(gogeToken.balanceOf(address(jon)), 0);
        assertEq(gogeToken.balanceOf(address(gogeDao)), tim_votes + jon_votes);

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(jon)), jon_votes);
        assertEq(gogeDao.totalVotes(1), tim_votes + jon_votes);
        assertEq(gogeDao.historicalTally(1), tim_votes + jon_votes);
        assertEq(gogeDao.passed(1), false);

        /// NOTE addVotes -> Joe -> overcomes quorum therefore passes poll

        // Approve the transfer of tokens and add vote for jon.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Verify tokens were sent from Jon to Dao
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 0);

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), tim_votes + jon_votes + joe_votes);
        assertEq(gogeDao.historicalTally(1), tim_votes + jon_votes + joe_votes);
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        assertEq(IERC20(BUSD).balanceOf(address(joe)), 1_000 ether);
        assertEq(IERC20(BUSD).balanceOf(address(gogeDao)), 0);

        // Verify quorum math.
        uint256 num = (gogeDao.totalVotes(1) * 100) / gogeToken.getCirculatingMinusReserve();
        assertTrue(num >= gogeDao.quorum());        
    }

    // ~~ All poll type tests ~~

    /// @notice initiates a taxChange poll and verifies correct state change when poll is passed.
    function test_gogeDao_taxChange() public {

        /// NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose a tax change";
        metadata.time2 = block.timestamp + 2 days;
        metadata.fee1 = 8; // cakeDividendRewardsFee
        metadata.fee2 = 3;  // marketingFee
        metadata.fee3 = 4;  // buyBackFee
        metadata.fee4 = 5;  // teamFee

        // create poll
        gogeDao.createPoll(GogeDAO.PollType.taxChange, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.taxChange);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose a tax change");
        assertEq(gogeDao.getMetadata(1).time1, block.timestamp);
        assertEq(gogeDao.getMetadata(1).time2, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).fee1, 8);
        assertEq(gogeDao.getMetadata(1).fee2, 3);
        assertEq(gogeDao.getMetadata(1).fee3, 4);
        assertEq(gogeDao.getMetadata(1).fee4, 5);

        /// NOTE pass poll

        uint256 joe_votes = 50_000_000_000 ether;
        gogeDao.setGateKeeping(false);

        // Pre-state check.
        assertEq(gogeToken.cakeDividendRewardsFee(), 10);
        assertEq(gogeToken.marketingFee(), 2);
        assertEq(gogeToken.buyBackFee(), 2);
        assertEq(gogeToken.teamFee(), 2);
        assertEq(gogeToken.totalFees(), 16);
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 2 days);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), joe_votes);
        assertEq(gogeDao.historicalTally(1), joe_votes);
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        // Verify quorum math.
        uint256 num = (gogeDao.totalVotes(1) * 100) / gogeToken.getCirculatingMinusReserve();
        assertTrue(num >= gogeDao.quorum());

        // Post-state check => gogeToken.
        assertEq(gogeToken.cakeDividendRewardsFee(), 8);
        assertEq(gogeToken.marketingFee(), 3);
        assertEq(gogeToken.buyBackFee(), 4);
        assertEq(gogeToken.teamFee(), 5);
        assertEq(gogeToken.totalFees(), 20);        
    }

    /// @notice initiates a funding poll and verifies correct state change when poll is passed.
    function test_gogeDao_funding() public {

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose a funding";
        metadata.time2 = block.timestamp + 2 days;
        metadata.addr1 = address(joe);
        metadata.addr2 = BUSD;
        metadata.amount = 1_000 ether;

        // create poll
        gogeDao.createPoll(GogeDAO.PollType.funding, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.funding);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose a funding");
        assertEq(gogeDao.getMetadata(1).time1, block.timestamp);
        assertEq(gogeDao.getMetadata(1).time2, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).addr1, address(joe));
        assertEq(gogeDao.getMetadata(1).addr2, BUSD);
        assertEq(gogeDao.getMetadata(1).amount, 1_000 ether);

        // NOTE pass poll
        
        uint256 joe_votes = 50_000_000_000 ether;
        gogeDao.setGateKeeping(false);

        mint("BUSD", address(gogeDao), 1_000 ether);

        // Pre-state check.
        assertEq(IERC20(BUSD).balanceOf(address(joe)), 0);
        assertEq(IERC20(BUSD).balanceOf(address(gogeDao)), 1_000 ether);
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 2 days);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), joe_votes);
        assertEq(gogeDao.historicalTally(1), joe_votes);
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        assertEq(IERC20(BUSD).balanceOf(address(joe)), 1_000 ether);
        assertEq(IERC20(BUSD).balanceOf(address(gogeDao)), 0);

        // Verify quorum math.
        uint256 num = (gogeDao.totalVotes(1) * 100) / gogeToken.getCirculatingMinusReserve();
        assertTrue(num >= gogeDao.quorum());        
    }

    /// @notice initiates a setGogeDao poll and verifies correct state change when poll is passed.
    function test_gogeDao_setGogeDao() public {

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose setGogeDao";
        metadata.time2 = block.timestamp + 2 days;
        metadata.addr1 = address(222);

        // create poll
        gogeDao.createPoll(GogeDAO.PollType.setGogeDao, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setGogeDao);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose setGogeDao");
        assertEq(gogeDao.getMetadata(1).time1, block.timestamp);
        assertEq(gogeDao.getMetadata(1).time2, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).addr1, address(222));

        // NOTE pass poll
        
        uint256 joe_votes = 50_000_000_000 ether;
        gogeDao.setGateKeeping(false);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 2 days);
        assertEq(gogeToken.gogeDao(), address(gogeDao));

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), joe_votes);
        assertEq(gogeDao.historicalTally(1), joe_votes);
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        assertEq(gogeToken.gogeDao(), address(222));

        // Verify quorum math.
        uint256 num = (gogeDao.totalVotes(1) * 100) / gogeToken.getCirculatingMinusReserve();
        assertTrue(num >= gogeDao.quorum());        
    }

    /// @notice initiates a setCex poll and verifies correct state change when poll is passed.
    function test_gogeDao_setCex() public {

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose setCex";
        metadata.time2 = block.timestamp + 2 days;
        metadata.addr1 = address(222);

        // create poll
        gogeDao.createPoll(GogeDAO.PollType.setCex, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setCex);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose setCex");
        assertEq(gogeDao.getMetadata(1).time1, block.timestamp);
        assertEq(gogeDao.getMetadata(1).time2, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).addr1, address(222));

        // NOTE pass poll
        
        uint256 joe_votes = 50_000_000_000 ether;
        gogeDao.setGateKeeping(false);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 2 days);
        assertEq(gogeToken.isExcludedFromFees(address(222)), false);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), joe_votes);
        assertEq(gogeDao.historicalTally(1), joe_votes);
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        assertEq(gogeToken.isExcludedFromFees(address(222)), true);

        // Verify quorum math.
        uint256 num = (gogeDao.totalVotes(1) * 100) / gogeToken.getCirculatingMinusReserve();
        assertTrue(num >= gogeDao.quorum());        
    }

    /// @notice initiates a setDex poll and verifies correct state change when poll is passed.
    function test_gogeDao_setDex() public {

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose setDex";
        metadata.time2 = block.timestamp + 2 days;
        metadata.addr1 = address(222);
        metadata.boolVar = true;

        // create poll
        gogeDao.createPoll(GogeDAO.PollType.setDex, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setDex);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose setDex");
        assertEq(gogeDao.getMetadata(1).time1, block.timestamp);
        assertEq(gogeDao.getMetadata(1).time2, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).addr1, address(222));
        assertEq(gogeDao.getMetadata(1).boolVar, true);

        // NOTE pass poll
        
        uint256 joe_votes = 50_000_000_000 ether;
        gogeDao.setGateKeeping(false);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 2 days);
        assertEq(gogeToken.automatedMarketMakerPairs(address(222)), false);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), joe_votes);
        assertEq(gogeDao.historicalTally(1), joe_votes);
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        assertEq(gogeToken.automatedMarketMakerPairs(address(222)), true);

        // Verify quorum math.
        uint256 num = (gogeDao.totalVotes(1) * 100) / gogeToken.getCirculatingMinusReserve();
        assertTrue(num >= gogeDao.quorum());        
    }

    /// @notice initiates a excludeFromCirculatingSupply poll and verifies correct state change when poll is passed.
    function test_gogeDao_excludeFromCirculatingSupply() public {

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose excludeFromCirculatingSupply";
        metadata.time2 = block.timestamp + 2 days;
        metadata.addr1 = address(222);
        metadata.boolVar = true;

        // create poll
        gogeDao.createPoll(GogeDAO.PollType.excludeFromCirculatingSupply, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.excludeFromCirculatingSupply);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose excludeFromCirculatingSupply");
        assertEq(gogeDao.getMetadata(1).time1, block.timestamp);
        assertEq(gogeDao.getMetadata(1).time2, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).addr1, address(222));
        assertEq(gogeDao.getMetadata(1).boolVar, true);

        // NOTE pass poll
        
        uint256 joe_votes = 50_000_000_000 ether;
        gogeDao.setGateKeeping(false);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 2 days);
        (bool excludedPre,) = gogeToken.isExcludedFromCirculatingSupply(address(222));
        assertEq(excludedPre, false);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), joe_votes);
        assertEq(gogeDao.historicalTally(1), joe_votes);
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        (bool excludedPost,) = gogeToken.isExcludedFromCirculatingSupply(address(222));
        assertEq(excludedPost, true);

        // Verify quorum math.
        uint256 num = (gogeDao.totalVotes(1) * 100) / gogeToken.getCirculatingMinusReserve();
        assertTrue(num >= gogeDao.quorum());        
    }
}
