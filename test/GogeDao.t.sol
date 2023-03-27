// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import { GogeDAO } from "../src/GogeDao.sol";
import { DogeGaySonFlat } from "../src/DeployedV2Token.sol";

import { IUniswapV2Router02, IUniswapV2Router01, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";
import { IGogeERC20 } from "../src/extensions/IGogeERC20.sol";

contract DaoTest is Utility, Test {
    GogeDAO gogeDao;
    DogeGaySonFlat gogeToken;

    address UNIV2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    function setUp() public {
        createActors();
        setUpTokens();

        // Deploy gogeToken
        gogeToken = new DogeGaySonFlat(
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

        // Create mock LP
        IUniswapV2Router01(UNIV2_ROUTER).addLiquidityETH{value: 100 ether}(
            address(gogeToken),
            TOKEN_DEPOSIT,
            5_000_000_000 ether,
            100 ether,
            address(this),
            block.timestamp + 300
        );

        // Deploy gogeDao
        gogeDao = new GogeDAO(address(gogeToken));

        // enable trading on the v2 token and set dao address
        gogeToken.enableTrading();
        gogeToken.setGogeDao(address(gogeDao));

        // Allow for polls to be created on gogeDao
        gogeDao.toggleCreatePollEnabled();
    }


    // ~~ Init state test ~~

    /// @notice Verify initial state pf gpgeDao and gogeToken
    function test_gogeDao_init_state() public {
        assertEq(address(gogeToken), gogeDao.governanceTokenAddr());
        assertEq(gogeDao.pollNum(), 0);
    }

    
    // ~~ Utility Functions ~~

    /// @notice Creates a mock poll
    function create_mock_poll() public {
        uint256 _pollNum = gogeDao.pollNum();

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "This is a mock poll, for testing";
        metadata.endTime = block.timestamp + 5 days;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.other, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), _pollNum + 1);
        assertEq(gogeDao.getMetadata(gogeDao.pollNum()).description, "This is a mock poll, for testing");
    }


    // ~~ Unit Tests ~~

    /// @notice Verify the ability for holders of gogeToken to create polls on gogeDao
    function test_gogeDao_createPoll() public {
        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to add Joe to the naughty list";
        metadata.endTime = block.timestamp + 2 days;
        metadata.addr1 = address(joe);
        metadata.boolVar = true;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.modifyBlacklist, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assertEq(gogeDao.pollAuthor(1), address(this));
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.modifyBlacklist);

        assertEq(gogeDao.getMetadata(1).description, "I want to add Joe to the naughty list");
        assertEq(gogeDao.getMetadata(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).addr1, address(joe));
        assertEq(gogeDao.getMetadata(1).boolVar, true);

        assertEq(gogeDao.polls(1, address(this)), gogeDao.minAuthorBal());
        assertEq(gogeDao.totalVotes(1), gogeDao.minAuthorBal());
        assertEq(gogeToken.balanceOf(address(gogeDao)), gogeDao.minAuthorBal());

        address[] memory voters = gogeDao.getVoterLibrary(1);
        assertEq(voters.length, 1);
        assertEq(voters[0], address(this));

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);
    }

    /// @notice Verify the ability for participants to add votes to a poll via addVote
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
        assertEq(gogeToken.balanceOf(address(gogeDao)), joe_votes + gogeDao.minAuthorBal());

        // Post-state check.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), joe_votes + gogeDao.minAuthorBal());

        // TODO: Add voterLibrary and advocateFor state changes

        // Verify quorum
        uint256 num = gogeDao.getProportion(1); // => 10%
        assertEq(num, 10);
    }

    /// @notice Verify accessibility and edge cases of addVote
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
        assertEq(gogeToken.balanceOf(address(gogeDao)), 500_000_000 ether + gogeDao.minAuthorBal());

        // Warp to end time of poll 1. +2 days.
        vm.warp(block.timestamp + 1 days);

        // Verify Joe cannot make a vote on a poll that has been closed.
        assert(!joe.try_addVote(address(gogeDao), 1, 500_000_000 ether));
    }

    /// @notice Verify correct state changes and logic for addVote using fuzzing
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
        assertEq(gogeToken.balanceOf(address(gogeDao)), joe_votes + gogeDao.minAuthorBal());

        // Post-state check.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), joe_votes + gogeDao.minAuthorBal());

        // Verify quorum
        uint256 num = gogeDao.getProportion(1); // => 10%
        emit log_uint(num);
    }

    /// @notice Verify the execution of a poll when a poll reaches the quorum
    function test_gogeDao_addVote_quorum() public {
        test_gogeDao_createPoll();
        uint256 joe_votes = 50_000_000_000 ether;
        gogeDao.setGateKeeping(false);

        // Pre-state check.
        assertEq(gogeToken.isBlacklisted(address(joe)), false);
        assertEq(gogeDao.passed(1), false);

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
        assertEq(gogeDao.totalVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());

        // Post-state check => gogeToken.
        assertEq(gogeToken.isBlacklisted(address(joe)), true);
    }

    /// @notice Verifies state changes of an advocate in a 2 stage process. Votes a portion of quorum, then meets quorum.
    function test_gogeDao_addVote_quorum_twoStage() public {
        test_gogeDao_createPoll();
        gogeDao.setGateKeeping(false);

        uint256 joe_votes_1 = 40_000_000_000 ether;
        uint256 joe_votes_2 = 10_000_000_000 ether;
        uint256 total_votes = joe_votes_1 + joe_votes_2;

        // NOTE: Pre state

        // Pre-state check.
        assertEq(gogeToken.isBlacklisted(address(joe)), false);
        assertEq(gogeDao.passed(1), false);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), total_votes);
        assertEq(gogeToken.balanceOf(address(joe)), total_votes);

        // NOTE: First addVote

        // Approve the transfer of tokens and execute first addVote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes_1));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes_1));

        // Verify token balance post first addVote.
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes_2);
        assertEq(gogeToken.balanceOf(address(gogeDao)), joe_votes_1 + gogeDao.minAuthorBal());

        // Post-state check after first addVote.
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 2 days);
        assertEq(gogeDao.polls(1, address(joe)), joe_votes_1);
        assertEq(gogeDao.totalVotes(1),          joe_votes_1 + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1),              false);

        address[] memory voters = gogeDao.getVoterLibrary(1);
        assertEq(voters.length, 2);
        assertEq(voters[0], address(this));
        assertEq(voters[1], address(joe));

        uint256[] memory advocateArr = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateArr.length, 1);
        assertEq(advocateArr[0], 1);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        assertEq(gogeToken.isBlacklisted(address(joe)), false);

        // NOTE: Second addVote -> pass poll

        // Approve the transfer of tokens and execute second addVote -> should pass poll.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes_2));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes_2));

        // Verify token balance post second addVote.
        assertEq(gogeToken.balanceOf(address(joe)), total_votes);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 0);

        // Post-state check after second addVote.
        assertEq(gogeDao.pollEndTime(1), block.timestamp);
        assertEq(gogeDao.polls(1, address(joe)), total_votes);
        assertEq(gogeDao.totalVotes(1),          total_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1),              true);

        voters = gogeDao.getVoterLibrary(1);
        assertEq(voters.length, 2);
        assertEq(voters[0], address(this));
        assertEq(voters[1], address(joe));

        advocateArr = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateArr.length, 0);

        // NOTE: Final state check

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());

        // Verify poll is no longer in activePolls
        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);

        // Post-state check => gogeToken.
        assertEq(gogeToken.isBlacklisted(address(joe)), true);
    }

    /// @notice passes a funding poll but ensures the tokens are refunded to all voters.
    function test_gogeDao_refundVotersPostChange() public {

        create_mock_poll();
        gogeDao.setGateKeeping(false);

        // ~~ pass poll ~~
        
        uint256 tim_votes = 24_000_000_000 ether;
        uint256 jon_votes = 20_000_000_000 ether;
        uint256 joe_votes = 6_000_000_000 ether;

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 5 days);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(tim), tim_votes);
        gogeToken.transfer(address(jon), jon_votes);
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(tim)), tim_votes);
        assertEq(gogeToken.balanceOf(address(jon)), jon_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Get AuthorBal
        uint256 authorBal = gogeToken.balanceOf(address(this));

        /// NOTE addVotes -> Tim

        // Approve the transfer of tokens and add vote for tim.
        assert(tim.try_approveToken(address(gogeToken), address(gogeDao), tim_votes));
        assert(tim.try_addVote(address(gogeDao), 1, tim_votes));

        // Verify tokens were sent from Tim to Dao
        assertEq(gogeToken.balanceOf(address(tim)), 0);
        assertEq(gogeToken.balanceOf(address(gogeDao)), tim_votes + gogeDao.minAuthorBal());

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(tim)), tim_votes);
        assertEq(gogeDao.totalVotes(1), tim_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), false);

        /// NOTE addVotes -> Jon

        // Approve the transfer of tokens and add vote for jon.
        assert(jon.try_approveToken(address(gogeToken), address(gogeDao), jon_votes));
        assert(jon.try_addVote(address(gogeDao), 1, jon_votes));

        // Verify tokens were sent from Jon to Dao
        assertEq(gogeToken.balanceOf(address(jon)), 0);
        assertEq(gogeToken.balanceOf(address(gogeDao)), tim_votes + jon_votes + gogeDao.minAuthorBal());

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(jon)), jon_votes);
        assertEq(gogeDao.totalVotes(1), tim_votes + jon_votes + gogeDao.minAuthorBal());
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
        assertEq(gogeDao.totalVotes(1), tim_votes + jon_votes + joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        // Verify all voters were refunded
        assertEq(gogeToken.balanceOf(address(tim)), tim_votes);
        assertEq(gogeToken.balanceOf(address(jon)), jon_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);
        assertEq(gogeToken.balanceOf(address(this)), authorBal + gogeDao.minAuthorBal());

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());        
    }

    /// @notice verifies advocateFor for proper usage, state changes, and pop/push implementation.
    /// NOTE: A user must only be added to advocateFor if they addVotes to a poll
    ///       A user must only be REMOVED from advocateFor if:
    ///         - Poll is passed via addVote -> addVote()
    ///         - Poll is passed via admin/owner -> endPoll() or passPoll()
    ///         - User removes their votes manually -> removeVotesFromPoll() && removeAllVotes()
    function test_gogeDao_advocateFor() public {
        test_gogeDao_createPoll();
        gogeDao.setGateKeeping(false);

        uint256 joe_votes = 10_000_000_000 ether;

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // NOTE: removeVotesFromPoll

        // Pre-state check.
        uint256[] memory advocateArr = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateArr.length, 0);

        // Approve the transfer of tokens and execute addVote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Post-state check after addVote.
        advocateArr = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateArr.length, 1);
        assertEq(advocateArr[0], 1);

        // Joe calls removeVotesFromPoll
        assert(joe.try_removeVotesFromPoll(address(gogeDao), 1));

        // Post-state check after removeVotesFromPoll.
        advocateArr = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateArr.length, 0);

        // NOTE: endPoll

        // Approve and addVote again
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Post-state check after addVote.
        advocateArr = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateArr.length, 1);
        assertEq(advocateArr[0], 1);

        // Owner calls endPoll
        gogeDao.endPoll(1);

        // Post-state check after removeVotesFromPoll.
        advocateArr = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateArr.length, 0);
    }

    /// @notice verifies correctness of queryEndTime()
    /// NOTE: This function should be called on a regular interval by an external script.
    /// TODO: Expand
    function test_gogeDao_queryEndTime() public {
        test_gogeDao_createPoll();
        gogeDao.setGateKeeping(false);

        //Warp to end time
        vm.warp(block.timestamp + 2 days);

        // Pre-state check.
        assertEq(gogeDao.passed(1),                     false);
        assertEq(gogeToken.isBlacklisted(address(joe)), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Call queryEndTime() to 
        gogeDao.queryEndTime();

        // Post-state check.
        assertEq(gogeDao.passed(1),                     false);
        assertEq(gogeToken.isBlacklisted(address(joe)), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verify execution of poll when an admin calls passPoll
    function test_gogeDao_passPoll() public {
        test_gogeDao_createPoll();
        gogeDao.setGateKeeping(false);
        gogeDao.transferOwnership(address(dev));

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.isActivePoll(1), true);
        assertEq(gogeToken.isBlacklisted(address(joe)), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 2 days);

        // passPoll
        assert(dev.try_passPoll(address(gogeDao), 1));

        // Post-state check.
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.isActivePoll(1), false);
        assertEq(gogeToken.isBlacklisted(address(joe)), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        // dev tries to call passPoll -> fails
        assert(!dev.try_passPoll(address(gogeDao), 1));
    }

    /// @notice Verify execution of poll and voters refunded when passPoll is called.
    function test_gogeDao_passPoll_withVotes() public {
        test_gogeDao_createPoll();
        gogeDao.setGateKeeping(false);
        gogeDao.transferOwnership(address(dev));

        uint256 joe_votes = 10_000_000_000 ether;

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Approve the transfer of tokens and execute addVote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));        

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);

        assertEq(gogeToken.balanceOf(address(joe)), 0);
        assertEq(gogeToken.balanceOf(address(gogeDao)), joe_votes + gogeDao.minAuthorBal());

        uint256[] memory advocateArr = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateArr.length, 1);
        assertEq(advocateArr[0], 1);

        assertEq(gogeDao.isActivePoll(1), true);
        assertEq(gogeToken.isBlacklisted(address(joe)), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 2 days);

        // passPoll
        assert(dev.try_passPoll(address(gogeDao), 1));

        // Post-state check.
        assertEq(gogeDao.passed(1), true);

        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 0);

        advocateArr = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateArr.length, 0);

        assertEq(gogeDao.isActivePoll(1), false);
        assertEq(gogeToken.isBlacklisted(address(joe)), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        // dev tries to call passPoll -> fails
        assert(!dev.try_passPoll(address(gogeDao), 1));
    }

    /// @notice Verify an admin can call endPoll to remove poll from activePolls and does NOT result in poll execution.
    function test_gogeDao_endPoll() public {
        gogeDao.setGateKeeping(false);
        gogeDao.transferOwnership(address(dev));

        // NOTE: Owner ends poll
        create_mock_poll();

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.isActivePoll(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 5 days);

        // endPoll
        assert(dev.try_endPoll(address(gogeDao), 1));

        // Post-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.isActivePoll(1), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        // dev tries to call endPoll -> fails
        assert(!dev.try_endPoll(address(gogeDao), 1));

        // NOTE: Author ends poll
        create_mock_poll();

        // Pre-state check.
        assertEq(gogeDao.passed(2), false);
        assertEq(gogeDao.isActivePoll(2), true);
        assertEq(gogeDao.pollEndTime(2), block.timestamp + 5 days);

        // endPoll
        gogeDao.endPoll(2);

        // Post-state check.
        assertEq(gogeDao.passed(2), false);
        assertEq(gogeDao.isActivePoll(2), false);
        assertEq(gogeDao.pollEndTime(2), block.timestamp);
    }

    /// @notice Verify that when endPoll is called, existing voters are refunded.
    function test_gogeDao_endPoll_withVotes() public {
        test_gogeDao_createPoll();

        gogeDao.setGateKeeping(false);
        gogeDao.transferOwnership(address(dev));

        uint256 joe_votes = 10_000_000_000 ether;

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Approve the transfer of tokens and execute addVote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));        

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);

        assertEq(gogeToken.balanceOf(address(joe)), 0);
        assertEq(gogeToken.balanceOf(address(gogeDao)), joe_votes + gogeDao.minAuthorBal());

        uint256[] memory advocateArr = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateArr.length, 1);
        assertEq(advocateArr[0], 1);

        advocateArr = gogeDao.getAdvocateFor(address(this));
        assertEq(advocateArr.length, 1);
        assertEq(advocateArr[0], 1);

        assertEq(gogeDao.isActivePoll(1), true);
        assertEq(gogeToken.isBlacklisted(address(joe)), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 2 days);

        uint256 author_bal = gogeToken.balanceOf(address(this));

        // endPoll
        assert(dev.try_endPoll(address(gogeDao), 1));

        // Post-state check.
        assertEq(gogeDao.passed(1), false);

        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);
        assertEq(gogeToken.balanceOf(address(this)), author_bal + gogeDao.minAuthorBal());
        assertEq(gogeToken.balanceOf(address(gogeDao)), 0);

        advocateArr = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateArr.length, 0);

        advocateArr = gogeDao.getAdvocateFor(address(this));
        assertEq(advocateArr.length, 0);

        assertEq(gogeDao.isActivePoll(1), false);
        assertEq(gogeToken.isBlacklisted(address(joe)), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        // dev tries to call endPoll -> fails
        assert(!dev.try_endPoll(address(gogeDao), 1));
    }

    /// @notice Verify gateKeeping enabled will need extra gatekeeper votes to pass a poll that's met quorum
    function test_gogeDao_gateKeeping() public {
        test_gogeDao_createPoll();
        uint256 joe_votes = 50_000_000_000 ether;

        // Verify blacklist state and poll has not been passed
        assertEq(gogeToken.isBlacklisted(address(joe)), false);
        assertEq(gogeDao.passed(1), false);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Verify tokens Joe is holding the token balance since poll was passed.
        assertEq(gogeToken.balanceOf(address(joe)), 0);
        assertEq(gogeToken.balanceOf(address(gogeDao)), joe_votes + gogeDao.minAuthorBal());

        // Verify state. Poll should not be passed, though quorum has been met.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.totalVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.pollEndTime(1), block.timestamp + 2 days);

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum()); // quorum met

        // Verify poll has not been executed this Joe is not blacklisted, yet.
        assertEq(gogeToken.isBlacklisted(address(joe)), false);

        // Create gate keeper
        gogeDao.updateGateKeeper(address(dev), true);

        // Transfer tokens to gatekeeper
        gogeToken.transfer(address(dev), 1 ether);
        assertEq(gogeToken.balanceOf(address(dev)), 1 ether);

        // gatekeeper adds vote to poll -> should pass poll
        assert(dev.try_approveToken(address(gogeToken), address(gogeDao), 1 ether));
        assert(dev.try_addVote(address(gogeDao), 1, 1 ether));

        // Verify state change post poll being passed.
        assertEq(gogeToken.balanceOf(address(dev)), 1 ether);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 0);
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.polls(1, address(this)), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(1, address(dev)), 1 ether);
        assertEq(gogeDao.totalVotes(1), joe_votes + 1 ether + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        // Verify poll has not been executed this Joe is not blacklisted, yet.
        assertEq(gogeToken.isBlacklisted(address(joe)), true);
    }

    /// @notice Verify when payTeam is called the addresses held in teamMembers are paid out
    function test_gogeDao_payTeam() public {
        emit log_named_uint("BNB Balance", address(this).balance); // 79228162214.264337593543950335

        // update governanceTokenAddr to address(this)
        test_gogeDao_updateGovernanceToken();

        // add team members
        gogeDao.setTeamMember(address(jon), true);
        gogeDao.setTeamMember(address(tim), true);

        // update team balance on dao
        payable(address(gogeDao)).transfer(1 ether);
        gogeDao.updateTeamBalance(1 ether);

        // Pre-state check
        assertEq(address(gogeDao).balance, 1 ether);
        assertEq(address(gogeDao).balance, gogeDao.teamBalance());
        assertEq(address(jon).balance, 0 ether);
        assertEq(address(tim).balance, 0 ether);

        // pay team
        gogeDao.payTeam();

        // Post-state check
        assertEq(address(gogeDao).balance, 0 ether);
        assertEq(address(gogeDao).balance, gogeDao.teamBalance());
        assertEq(address(jon).balance, 0.5 ether);
        assertEq(address(tim).balance, 0.5 ether);

    }

    /// @notice Verify correct logic when payTeam is called with a range of amounts using fuzzing.
    function test_gogeDao_payTeam_fuzzing(uint256 _amount) public {
        emit log_named_uint("BNB Balance", address(this).balance);

        _amount = bound(_amount, 0, address(this).balance);

        // update governanceTokenAddr to address(this)
        test_gogeDao_updateGovernanceToken();

        // add team members
        gogeDao.setTeamMember(address(jon), true);
        gogeDao.setTeamMember(address(tim), true);
        gogeDao.setTeamMember(address(joe), true);

        // update team balance on dao
        payable(address(gogeDao)).transfer(_amount);
        gogeDao.updateTeamBalance(_amount);

        // Pre-state check
        assertEq(address(gogeDao).balance, _amount);
        assertEq(address(gogeDao).balance, gogeDao.teamBalance());
        assertEq(address(jon).balance, 0 ether);
        assertEq(address(tim).balance, 0 ether);
        assertEq(address(joe).balance, 0 ether);

        // pay team
        gogeDao.payTeam();

        // Post-state check
        assertEq(address(gogeDao).balance, 0 ether);
        assertEq(address(gogeDao).balance, gogeDao.teamBalance());
        assertEq(address(jon).balance, _amount / 3);
        assertEq(address(tim).balance, _amount / 3);
        withinDiff(address(joe).balance, _amount / 3, 2);
    }

    /// @notice Verify correct logic when removeAllVotes is called.
    function test_gogeDao_removeAllVotes() public {

        // Create 3 polls
        create_mock_poll();
        create_mock_poll();
        create_mock_poll();

        // Send Joe tokens
        gogeToken.transfer(address(joe), 3_000 ether);
        assertEq(gogeToken.balanceOf(address(joe)), 3_000 ether);

        // Joe adds votes to all 3 polls
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), 3_000 ether));
        assert(joe.try_addVote(address(gogeDao), 1, 1_000 ether));
        assert(joe.try_addVote(address(gogeDao), 2, 1_000 ether));
        assert(joe.try_addVote(address(gogeDao), 3, 1_000 ether));

        // Verify state
        assertEq(gogeToken.balanceOf(address(joe)), 0);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 3_000 ether + (gogeDao.minAuthorBal() * 3));

        assertEq(gogeDao.polls(1, address(joe)), 1_000 ether);
        assertEq(gogeDao.totalVotes(1), 1_000 ether + gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(2, address(joe)), 1_000 ether);
        assertEq(gogeDao.totalVotes(2), 1_000 ether + gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(3, address(joe)), 1_000 ether);
        assertEq(gogeDao.totalVotes(3), 1_000 ether + gogeDao.minAuthorBal());

        // Joe removes all votes
        assert(joe.try_removeAllVotes(address(gogeDao)));

        // Verify state
        assertEq(gogeToken.balanceOf(address(joe)), 3_000 ether);
        assertEq(gogeToken.balanceOf(address(gogeDao)), gogeDao.minAuthorBal() * 3);

        assertEq(gogeDao.polls(1, address(joe)), 0);
        assertEq(gogeDao.totalVotes(1), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(2, address(joe)), 0);
        assertEq(gogeDao.totalVotes(2), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(3, address(joe)), 0);
        assertEq(gogeDao.totalVotes(3), gogeDao.minAuthorBal());
    }

    /// @notice Verify correctness when removeVotesFromPoll is called.
    function test_gogeDao_removeVotesFromPoll() public {
        gogeDao.setGateKeeping(false);
        gogeDao.updateMaxPollsPerAuthor(3);
        gogeDao.transferOwnership(address(dev));

        // Create 3 polls
        create_mock_poll();
        create_mock_poll();
        create_mock_poll();

        // Send Joe tokens
        gogeToken.transfer(address(joe), 3_000 ether);
        assertEq(gogeToken.balanceOf(address(joe)), 3_000 ether);

        // Joe adds votes to all 3 polls
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), 3_000 ether));
        assert(joe.try_addVote(address(gogeDao), 1, 1_000 ether));
        assert(joe.try_addVote(address(gogeDao), 2, 1_000 ether));
        assert(joe.try_addVote(address(gogeDao), 3, 1_000 ether));

        // Verify state
        assertEq(gogeToken.balanceOf(address(joe)), 0);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 3_000 ether + (gogeDao.minAuthorBal() * 3));
        assertEq(gogeDao.polls(1, address(joe)), 1_000 ether);
        assertEq(gogeDao.totalVotes(1), 1_000 ether + gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(2, address(joe)), 1_000 ether);
        assertEq(gogeDao.totalVotes(2), 1_000 ether + gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(3, address(joe)), 1_000 ether);
        assertEq(gogeDao.totalVotes(3), 1_000 ether + gogeDao.minAuthorBal());

        // Joe removes votes from poll 2
        assert(joe.try_removeVotesFromPoll(address(gogeDao), 2));

        // Verify state
        assertEq(gogeToken.balanceOf(address(joe)), 1_000 ether);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 2_000 ether + (gogeDao.minAuthorBal() * 3));
        assertEq(gogeDao.polls(1, address(joe)), 1_000 ether);
        assertEq(gogeDao.totalVotes(1), 1_000 ether + gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(2, address(joe)), 0);
        assertEq(gogeDao.totalVotes(2), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(3, address(joe)), 1_000 ether);
        assertEq(gogeDao.totalVotes(3), 1_000 ether + gogeDao.minAuthorBal());

        // Joe removes votes from poll 1
        assert(joe.try_removeVotesFromPoll(address(gogeDao), 1));

        // Verify state
        assertEq(gogeToken.balanceOf(address(joe)), 2_000 ether);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 1_000 ether + (gogeDao.minAuthorBal() * 3));
        assertEq(gogeDao.polls(1, address(joe)), 0);
        assertEq(gogeDao.totalVotes(1), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(2, address(joe)), 0);
        assertEq(gogeDao.totalVotes(2), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(3, address(joe)), 1_000 ether);
        assertEq(gogeDao.totalVotes(3), 1_000 ether + gogeDao.minAuthorBal());

        // Joe removes votes from poll 3
        assert(joe.try_removeVotesFromPoll(address(gogeDao), 3));

        // Verify state
        assertEq(gogeToken.balanceOf(address(joe)), 3_000 ether);
        assertEq(gogeToken.balanceOf(address(gogeDao)), gogeDao.minAuthorBal() * 3);
        assertEq(gogeDao.polls(1, address(joe)), 0);
        assertEq(gogeDao.totalVotes(1), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(2, address(joe)), 0);
        assertEq(gogeDao.totalVotes(2), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(3, address(joe)), 0);
        assertEq(gogeDao.totalVotes(3), gogeDao.minAuthorBal());

        // dev ends all polls -> sanity check
        assert(dev.try_endPoll(address(gogeDao), 1));
        assertEq(gogeToken.balanceOf(address(gogeDao)), gogeDao.minAuthorBal() * 2);

        assert(dev.try_endPoll(address(gogeDao), 2));
        assertEq(gogeToken.balanceOf(address(gogeDao)), gogeDao.minAuthorBal());

        assert(dev.try_endPoll(address(gogeDao), 3));
        assertEq(gogeToken.balanceOf(address(gogeDao)), 0);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    // TODO:
    // - require poll author holds a min amount of tokens -> DONE!!
    // - require when a poll is created, creator stakes their tokens -> DONE!!
    // - require poll authors can only have 1 active poll at a time -> DONE!!
    // - allow poll authors to end their poll -> DONE, BUT NEEDS TESTING

    /// @notice Verifies state change when updateMinAuthorBal() is called
    function test_gogeDao_updateMinAuthorBal() public {
        // Pre-state check.
        assertEq(gogeDao.minAuthorBal(), 10_000_000 ether);

        // call updateMinAuthorBal.
        gogeDao.updateMinAuthorBal(5_000_000 ether);

        // Post-state check.
        assertEq(gogeDao.minAuthorBal(), 5_000_000 ether);
    }

    /// @notice Verifies minAuthorBal implementation -> poll creators MUST have a token balance greater than minAuthorBal
    function test_gogeDao_minAuthorBal() public {

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "This is a mock poll, for testing";
        metadata.endTime = block.timestamp + 5 days;

        // start prank
        vm.startPrank(address(joe));

        // expect next call to revert
        vm.expectRevert("GogeDao.sol::createPoll() Insufficient balance of tokens");

        // Joe attempts to call createPoll
        gogeDao.createPoll(GogeDAO.PollType.other, metadata);

        // stop prank
        vm.stopPrank();

        // transfer tokens to Joe
        gogeToken.transfer(address(joe), gogeDao.minAuthorBal());
        assertEq(IERC20(address(gogeToken)).balanceOf(address(joe)), gogeDao.minAuthorBal());

        // start prank
        vm.startPrank(address(joe));

        // approve transfer of minAuthorBal
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());

        // Joe calls createPoll
        gogeDao.createPoll(GogeDAO.PollType.other, metadata);

        // stop prank
        vm.stopPrank();

        // Post-state check.
        assertEq(gogeDao.pollNum(), 1);
        assertEq(gogeDao.getMetadata(gogeDao.pollNum()).description, "This is a mock poll, for testing");
    }

    /// @notice Verifies maxPollsPerAuthor implementation -> Creators can only have x amount of activePolls at the same time ( x == maxPollsPerAuthor ).
    function test_gogeDao_maxPollsPerAuthor() public {

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "This is a mock poll, for testing";
        metadata.endTime = block.timestamp + 5 days;

        // transfer tokens to Joe
        gogeToken.transfer(address(joe), gogeDao.minAuthorBal());
        assertEq(IERC20(address(gogeToken)).balanceOf(address(joe)), gogeDao.minAuthorBal());

        // start prank
        vm.startPrank(address(joe));

        // Joe calls createPoll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.other, metadata);

        // stop prank
        vm.stopPrank();

        // Verify poll has been created
        assertEq(gogeDao.pollNum(), 1);
        assertEq(gogeDao.getMetadata(gogeDao.pollNum()).description, "This is a mock poll, for testing");
        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);

        // start prank
        vm.startPrank(address(joe));

        // approve tokens for createPoll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());

        // expect next call to revert
        vm.expectRevert("GogeDao.sol::createPoll() Exceeds maxPollsPerAuthor");

        // Joe calls createPoll
        gogeDao.createPoll(GogeDAO.PollType.other, metadata);

        // stop prank
        vm.stopPrank();

        // Verify there's still only 1 poll live
        assertEq(gogeDao.pollNum(), 1);
        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);


        // NOTE: Sanity Check

        // End Poll 1
        gogeDao.endPoll(1);

        // Verify there's no activePoll
        assertEq(gogeDao.pollNum(), 1);
        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);

        // start prank
        vm.startPrank(address(joe));

        // Joe calls createPoll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.other, metadata);

        // stop prank
        vm.stopPrank();

        // Verify there's still only 1 poll live
        assertEq(gogeDao.pollNum(), 2);
        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
    }


    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////


    // ~~ All poll type tests ~~

    /// @notice initiates a taxChange poll and verifies correct state change when poll is passed.
    function test_gogeDao_taxChange() public {

        /// NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose a tax change";
        metadata.endTime = block.timestamp + 2 days;
        metadata.fee1 = 8;  // cakeDividendRewardsFee
        metadata.fee2 = 3;  // marketingFee
        metadata.fee3 = 4;  // buyBackFee
        metadata.fee4 = 5;  // teamFee

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.taxChange, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.taxChange);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose a tax change");
        assertEq(gogeDao.getMetadata(1).endTime, block.timestamp + 2 days);
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
        assertEq(gogeDao.totalVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
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
        gogeDao.setGateKeeping(false);

        payable(address(gogeDao)).transfer(1_000 ether);

        vm.prank(address(gogeToken));
        gogeDao.updateMarketingBalance(1_000 ether);
        vm.stopPrank();

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose a funding";
        metadata.endTime = block.timestamp + 2 days;
        metadata.addr1 = address(joe);
        metadata.amount = 1_000 ether;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.funding, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.funding);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose a funding");
        assertEq(gogeDao.getMetadata(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).addr1, address(joe));
        assertEq(gogeDao.getMetadata(1).amount, 1_000 ether);

        assertEq(address(joe).balance, 0);
        assertEq(address(gogeDao).balance, 1_000 ether);
        assertEq(gogeDao.marketingBalance(), 1_000 ether);

        // NOTE pass poll
        
        uint256 joe_votes = 50_000_000_000 ether;

        // Pre-state check.
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
        assertEq(gogeDao.totalVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        assertEq(address(joe).balance, 1_000 ether);
        assertEq(address(gogeDao).balance, 0);
        assertEq(gogeDao.marketingBalance(), 0);

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());        
    }

    /// @notice initiates a setGogeDao poll and verifies correct state change when poll is passed.
    function test_gogeDao_setGogeDao() public {

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose setGogeDao";
        metadata.endTime = block.timestamp + 2 days;
        metadata.addr1 = address(222);

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setGogeDao, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setGogeDao);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose setGogeDao");
        assertEq(gogeDao.getMetadata(1).endTime, block.timestamp + 2 days);
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
        assertEq(gogeDao.totalVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        assertEq(gogeToken.gogeDao(), address(222));

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());        
    }

    /// @notice initiates a setCex poll and verifies correct state change when poll is passed.
    function test_gogeDao_setCex() public {

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose setCex";
        metadata.endTime = block.timestamp + 2 days;
        metadata.addr1 = address(222);

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setCex, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setCex);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose setCex");
        assertEq(gogeDao.getMetadata(1).endTime, block.timestamp + 2 days);
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
        assertEq(gogeDao.totalVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        assertEq(gogeToken.isExcludedFromFees(address(222)), true);

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());        
    }

    /// @notice initiates a setDex poll and verifies correct state change when poll is passed.
    function test_gogeDao_setDex() public {

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose setDex";
        metadata.endTime = block.timestamp + 2 days;
        metadata.addr1 = address(222);
        metadata.boolVar = true;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setDex, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setDex);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose setDex");
        assertEq(gogeDao.getMetadata(1).endTime, block.timestamp + 2 days);
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
        assertEq(gogeDao.totalVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        assertEq(gogeToken.automatedMarketMakerPairs(address(222)), true);

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());        
    }

    /// @notice initiates a excludeFromCirculatingSupply poll and verifies correct state change when poll is passed.
    function test_gogeDao_excludeFromCirculatingSupply() public {

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose excludeFromCirculatingSupply";
        metadata.endTime = block.timestamp + 2 days;
        metadata.addr1 = address(222);
        metadata.boolVar = true;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.excludeFromCirculatingSupply, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.excludeFromCirculatingSupply);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose excludeFromCirculatingSupply");
        assertEq(gogeDao.getMetadata(1).endTime, block.timestamp + 2 days);
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
        assertEq(gogeDao.totalVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.pollEndTime(1), block.timestamp);

        (bool excludedPost,) = gogeToken.isExcludedFromCirculatingSupply(address(222));
        assertEq(excludedPost, true);

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());
    }

    /// @notice Verifies correct state changes when a poll of pollType updateDividendToken is created and executed.
    function test_gogeDao_updateDividendToken() public {

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose we update the dividend token to this address";
        metadata.endTime = block.timestamp + 2 days;
        metadata.addr1 = BUNY;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateDividendToken, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateDividendToken);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose we update the dividend token to this address");
        assertEq(gogeDao.getMetadata(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).addr1, BUNY);

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.cakeDividendToken(), CAKE);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.cakeDividendToken(), BUNY);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType updateMarketingWallet is created and executed.
    function test_gogeDao_updateMarketingWallet() public {

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose we update the marketing wallet to this address";
        metadata.endTime = block.timestamp + 2 days;
        metadata.addr1 = address(this);

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateMarketingWallet, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateMarketingWallet);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose we update the marketing wallet to this address");
        assertEq(gogeDao.getMetadata(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).addr1, address(this));

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.marketingWallet(), 0xFecf1D51E984856F11B7D0872D40fC2F05377738);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.marketingWallet(), address(this));

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType updateTeamWallet is created and executed.
    function test_gogeDao_updateTeamWallet() public {

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose we update the team wallet to this address";
        metadata.endTime = block.timestamp + 2 days;
        metadata.addr1 = address(this);

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateTeamWallet, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateTeamWallet);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose we update the team wallet to this address");
        assertEq(gogeDao.getMetadata(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).addr1, address(this));

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.teamWallet(), 0xC1Aa023A8fA820F4ed077f4dF4eBeD0a3351a324);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.teamWallet(), address(this));

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType updateTeamMember is created and executed.
    function test_gogeDao_updateTeamMember() public {

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose we add an address as a team member";
        metadata.endTime = block.timestamp + 2 days;
        metadata.addr1 = address(sal);

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateTeamMember, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateTeamMember);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose we add an address as a team member");
        assertEq(gogeDao.getMetadata(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).addr1, address(sal));

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        (bool _member,) = gogeDao.isTeamMember(address(sal));
        assertEq(_member, false);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        (_member,) = gogeDao.isTeamMember(address(sal));
        assertEq(_member, true);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType updateGovernanceToken is created and executed.
    function test_gogeDao_updateGovernanceToken() public {

        // NOTE create poll

        // create poll metadata
        GogeDAO.Metadata memory metadata;
        metadata.description = "I want to propose we update the governance token to this address";
        metadata.endTime = block.timestamp + 2 days;
        metadata.addr1 = address(this);

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateGovernanceToken, metadata);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateGovernanceToken);

        // Verify poll metadata
        assertEq(gogeDao.getMetadata(1).description, "I want to propose we update the governance token to this address");
        assertEq(gogeDao.getMetadata(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getMetadata(1).addr1, address(this));

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.governanceTokenAddr(), address(gogeToken));

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.governanceTokenAddr(), address(this));

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }
}
