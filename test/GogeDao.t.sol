// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import { Utility } from "./Utility.sol";
import { GogeDAO } from "../src/GogeDao.sol";
import { DogeGaySonFlat } from "../src/DeployedV2Token.sol";

import { IUniswapV2Router01, IUniswapV2Router02, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";
import { IGogeERC20 } from "../src/extensions/IGogeERC20.sol";

contract DaoTest is Utility {
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
        uint256 TOKEN_DEPOSIT = 5_000_000_000 ether;

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
        assertEq(gogeDao.governanceToken(), address(gogeToken));
        assertEq(gogeDao.pollNum(), 0);
        assertEq(gogeDao.minPeriod(), 1 days);
        assertEq(gogeDao.maxPeriod(), 60 days);
        assertEq(gogeDao.minAuthorBal(), 10_000_000 ether);
        assertEq(gogeDao.maxPollsPerAuthor(), 1);
        assertEq(gogeDao.quorum(), 50);
        assertEq(gogeDao.marketingBalance(), 0);
        assertEq(gogeDao.teamBalance(), 0);
        assertEq(gogeDao.gatekeeping(), true);
        assertEq(gogeDao.createPollEnabled(), true);
        assertEq(gogeDao.owner(), address(this));
        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);

        assertEq(gogeToken.gogeDao(), address(gogeDao));
        assertEq(gogeToken.isExcludedFromFees(address(gogeDao)), true);
        assertEq(gogeToken.tradingIsEnabled(), true);
        assertEq(gogeToken.owner(), address(this));
        assertEq(gogeToken.balanceOf(address(this)), 95_000_000_000 ether);
    }

    
    // ~~ Utility Functions ~~

    /// @notice Creates a mock poll
    function create_mock_poll() public {
        uint256 _pollNum = gogeDao.pollNum();

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "This is a mock poll, for testing";
        proposal.endTime = block.timestamp + 5 days;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), _pollNum + 1);
        assertEq(gogeDao.getProposal(gogeDao.pollNum()).description, "This is a mock poll, for testing");
        assertEq(gogeDao.getProposal(gogeDao.pollNum()).endTime, block.timestamp + 5 days);
        assertEq(gogeDao.pollAuthor(gogeDao.pollNum()), address(this));
        assert(gogeDao.pollTypes(gogeDao.pollNum()) == GogeDAO.PollType.other);
    }

    /// @notice Perform a buy to generate fees
    function buy(uint256 _amount, address _receiver) public {

        // Approve
        IERC20(WBNB).approve(address(UNIV2_ROUTER), _amount);

        // Create path
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(gogeToken);

        // Execute purchase
        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount,
            0,
            path,
            _receiver,
            block.timestamp + 10
        );
    }


    // ~~ Unit Tests ~~

    /// @notice Verify the ability for holders of gogeToken to create polls on gogeDao
    function test_gogeDao_createPoll() public {

        // Pre-state check
        uint256 _preBal = gogeToken.balanceOf(address(this));
        uint256 _pollNum = gogeDao.pollNum();

        assertEq(gogeToken.balanceOf(address(gogeDao)), 0);

        address[] memory voters = gogeDao.getVoterLibrary(gogeDao.pollNum());
        assertEq(voters.length, 0);

        uint256[] memory advocateFor = gogeDao.getAdvocateFor(address(this));
        assertEq(advocateFor.length, 0);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to add Joe to the naughty list";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(joe);
        proposal.boolVar = true;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.modifyBlacklist, proposal);

        // Post-state check
        assertEq(gogeDao.pollNum(), _pollNum + 1);
        assertEq(gogeDao.pollAuthor(gogeDao.pollNum()), address(this));
        assert(gogeDao.pollTypes(gogeDao.pollNum()) == GogeDAO.PollType.modifyBlacklist);

        assertEq(gogeDao.getProposal(gogeDao.pollNum()).description, "I want to add Joe to the naughty list");
        assertEq(gogeDao.getProposal(gogeDao.pollNum()).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(gogeDao.pollNum()).addr1, address(joe));
        assertEq(gogeDao.getProposal(gogeDao.pollNum()).boolVar, true);

        assertEq(gogeDao.polls(gogeDao.pollNum(), address(this)), gogeDao.minAuthorBal());
        assertEq(gogeDao.pollVotes(gogeDao.pollNum()), gogeDao.minAuthorBal());
        assertEq(gogeToken.balanceOf(address(gogeDao)), gogeDao.minAuthorBal());
        assertEq(gogeToken.balanceOf(address(this)), _preBal - gogeDao.minAuthorBal());

        voters = gogeDao.getVoterLibrary(gogeDao.pollNum());
        assertEq(voters.length, 1);
        assertEq(voters[0], address(this));

        advocateFor = gogeDao.getAdvocateFor(address(this));
        assertEq(advocateFor.length, 1);
        assertEq(advocateFor[0], gogeDao.pollNum());

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], gogeDao.pollNum());
    }

    /// @notice Verify restricted edge cases when creating a poll
    function test_gogeDao_createPoll_restrictions() public {
        gogeDao.toggleCreatePollEnabled();
        gogeDao.transferOwnership(address(dev));

        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose xyz";
        proposal.endTime = block.timestamp;

        // try to create poll while createPollEnabled is false
        vm.expectRevert("GogeDao.sol::createPoll() Ability to create poll is disabled");
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);

        // toggle createPollEnabled
        vm.prank(address(dev));
        gogeDao.toggleCreatePollEnabled();

        // try to create poll while endTime is below minPeriod
        vm.expectRevert("GogeDao.sol::createPoll() End time must be later than start time");
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);

        // endTime is less than minPeriod
        proposal.endTime = block.timestamp + 1 seconds;

        // try to create poll while endTime is below minPeriod
        vm.expectRevert("GogeDao.sol::createPoll() Polling period must be greater than minPeriod");
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);

        // endTime is greater than maxPeriod
        proposal.endTime = block.timestamp + 61 days;

        // try to create poll while endTime to exceed maxPeriod
        vm.expectRevert("GogeDao.sol::createPoll() Polling period must be less than maxPeriod");
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);

        // update to proper end time
        proposal.endTime = block.timestamp + 60 days;

        vm.prank(address(jon));
        vm.expectRevert("GogeDao.sol::createPoll() Insufficient balance of tokens");
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);

        // try to create poll while endTime does not exceed maxPeriod, but author has not increased allowance
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);

        // approve transferFrom and createPoll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);
        assertEq(gogeDao.pollNum(), 1);

        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        vm.expectRevert("GogeDao.sol::createPoll() Exceeds maxPollsPerAuthor");
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);

    }

    /// @notice Verify the ability for participants to add votes to a poll via addVote
    function test_gogeDao_addVote_state_change() public {
        create_mock_poll();
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
        assertEq(gogeDao.pollVotes(1), joe_votes + gogeDao.minAuthorBal());

        // TODO: Add voterLibrary and advocateFor state changes

        // Verify quorum
        uint256 num = gogeDao.getProportion(1); // => 10%
        assertEq(num, 10);
    }

    /// @notice Verify accessibility and edge cases of addVote
    function test_gogeDao_addVote_restrictions() public {
        create_mock_poll();

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), 1_000_000_000 ether);
        assertEq(gogeToken.balanceOf(address(joe)), 1_000_000_000 ether);

        // Verify Joe cannot vote before approving.
        vm.prank(address(joe));
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        gogeDao.addVote(1, 1_000_000_000 ether);

        // Approve tokens for vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), 1_000_000_000 ether));

        // Verify Joe cannot make more votes than the balance in his wallet.
        vm.prank(address(joe));
        vm.expectRevert("GogeDao.sol::addVote() Exceeds Balance");
        gogeDao.addVote(1, 1_000_000_000 ether + 1);

        // Verify Joe cannot make a vote on a poll that doesnt exist.
        vm.prank(address(joe));
        vm.expectRevert("GogeDao.sol::addVote() Poll Closed");
        gogeDao.addVote(2, 1_000_000_000 ether);

        // Verify Joe cannot make a vote on a poll after purchasing tokens
        deal(WBNB, address(joe), 1 ether);
        vm.startPrank(address(joe));
        buy(1 ether, address(joe));
        vm.expectRevert("GogeDao.sol::addVote() Must wait 5 minutes after purchasing tokens to place any votes.");
        gogeDao.addVote(1, 1_000_000_000 ether);
        vm.stopPrank();

        // Warp 1 day ahead of start time. +1 day.
        vm.warp(block.timestamp + 1 days);

        // Verify Joe can make a vote on a poll that has not been closed.
        assert(joe.try_addVote(address(gogeDao), 1, 500_000_000 ether));

        // Verify tokens were sent from Joe to Dao
        assertGt(gogeToken.balanceOf(address(joe)), 500_000_000 ether);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 500_000_000 ether + gogeDao.minAuthorBal());

        // Warp to end time of poll 1. +4 days.
        vm.warp(block.timestamp + 4 days);

        // Verify Joe cannot make a vote on a poll that has been closed.
        vm.prank(address(joe));
        vm.expectRevert("GogeDao.sol::addVote() Poll Closed");
        gogeDao.addVote(1, 500_000_000 ether);
    }

    /// @notice Verify correct state changes and logic for addVote using fuzzing
    function test_gogeDao_addVote_fuzzing(uint256 joe_votes) public {
        create_mock_poll();

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
        assertEq(gogeDao.pollVotes(1), joe_votes + gogeDao.minAuthorBal());

        // Verify quorum
        uint256 num = gogeDao.getProportion(1); // => 10%
        emit log_uint(num);
    }

    /// @notice Verify the execution of a poll when a poll reaches the quorum
    function test_gogeDao_addVote_quorum() public {
        create_mock_poll();
        uint256 joe_votes = 50_000_000_000 ether;
        gogeDao.setGateKeeping(false);

        // Pre-state check.
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
        assertEq(gogeDao.pollVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());
    }

    /// @notice Verifies state changes of an advocate in a 2 stage process. Votes a portion of quorum, then meets quorum.
    function test_gogeDao_addVote_quorum_twoStage() public {
        create_mock_poll();
        gogeDao.setGateKeeping(false);

        uint256 joe_votes_1 = 40_000_000_000 ether;
        uint256 joe_votes_2 = 10_000_000_000 ether;
        uint256 total_votes = joe_votes_1 + joe_votes_2;

        // NOTE: Pre state

        // Pre-state check.
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
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 5 days);
        assertEq(gogeDao.polls(1, address(joe)), joe_votes_1);
        assertEq(gogeDao.pollVotes(1),           joe_votes_1 + gogeDao.minAuthorBal());
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

        // NOTE: Second addVote -> pass poll

        // Approve the transfer of tokens and execute second addVote -> should pass poll.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes_2));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes_2));

        // Verify token balance post second addVote.
        assertEq(gogeToken.balanceOf(address(joe)), total_votes);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 0);

        // Post-state check after second addVote.
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);
        assertEq(gogeDao.polls(1, address(joe)), total_votes);
        assertEq(gogeDao.pollVotes(1),           total_votes + gogeDao.minAuthorBal());
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
    }

    /// @notice passes a funding poll but ensures the tokens are refunded to all voters.
    function test_gogeDao_refundVotersPostChange() public {

        create_mock_poll();
        gogeDao.setGateKeeping(false);
        
        uint256 tim_votes = 24_000_000_000 ether;
        uint256 jon_votes = 20_000_000_000 ether;
        uint256 joe_votes = 6_000_000_000 ether;

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 5 days);

        address[] memory voters = gogeDao.getVoterLibrary(1);
        assertEq(voters.length, 1);
        assertEq(voters[0], address(this));
        uint256[] memory advocateFor = gogeDao.getAdvocateFor(address(this));
        assertEq(advocateFor.length, 1);
        assertEq(advocateFor[0], 1);
        advocateFor = gogeDao.getAdvocateFor(address(tim));
        assertEq(advocateFor.length, 0);
        advocateFor = gogeDao.getAdvocateFor(address(jon));
        assertEq(advocateFor.length, 0);
        advocateFor = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateFor.length, 0);

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
        assertEq(gogeDao.pollVotes(1), tim_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), false);
        
        voters = gogeDao.getVoterLibrary(1);
        assertEq(voters.length, 2);
        assertEq(voters[0], address(this));
        assertEq(voters[1], address(tim));
        advocateFor = gogeDao.getAdvocateFor(address(this));
        assertEq(advocateFor.length, 1);
        assertEq(advocateFor[0], 1);
        advocateFor = gogeDao.getAdvocateFor(address(tim));
        assertEq(advocateFor.length, 1);
        assertEq(advocateFor[0], 1);
        advocateFor = gogeDao.getAdvocateFor(address(jon));
        assertEq(advocateFor.length, 0);
        advocateFor = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateFor.length, 0);

        /// NOTE addVotes -> Jon

        // Approve the transfer of tokens and add vote for jon.
        assert(jon.try_approveToken(address(gogeToken), address(gogeDao), jon_votes));
        assert(jon.try_addVote(address(gogeDao), 1, jon_votes));

        // Verify tokens were sent from Jon to Dao
        assertEq(gogeToken.balanceOf(address(jon)), 0);
        assertEq(gogeToken.balanceOf(address(gogeDao)), tim_votes + jon_votes + gogeDao.minAuthorBal());

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(jon)), jon_votes);
        assertEq(gogeDao.pollVotes(1), tim_votes + jon_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), false);

        voters = gogeDao.getVoterLibrary(1);
        assertEq(voters.length, 3);
        assertEq(voters[0], address(this));
        assertEq(voters[1], address(tim));
        assertEq(voters[2], address(jon));
        advocateFor = gogeDao.getAdvocateFor(address(this));
        assertEq(advocateFor.length, 1);
        assertEq(advocateFor[0], 1);
        advocateFor = gogeDao.getAdvocateFor(address(tim));
        assertEq(advocateFor.length, 1);
        assertEq(advocateFor[0], 1);
        advocateFor = gogeDao.getAdvocateFor(address(jon));
        assertEq(advocateFor.length, 1);
        assertEq(advocateFor[0], 1);
        advocateFor = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateFor.length, 0);

        /// NOTE addVotes -> Joe -> overcomes quorum therefore passes poll

        // Approve the transfer of tokens and add vote for Joe.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Verify tokens were sent from Joe to Dao
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 0);

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.pollVotes(1), tim_votes + jon_votes + joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        voters = gogeDao.getVoterLibrary(1);
        assertEq(voters.length, 4);
        assertEq(voters[0], address(this));
        assertEq(voters[1], address(tim));
        assertEq(voters[2], address(jon));
        assertEq(voters[3], address(joe));
        advocateFor = gogeDao.getAdvocateFor(address(this));
        assertEq(advocateFor.length, 0);
        advocateFor = gogeDao.getAdvocateFor(address(tim));
        assertEq(advocateFor.length, 0);
        advocateFor = gogeDao.getAdvocateFor(address(jon));
        assertEq(advocateFor.length, 0);
        advocateFor = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateFor.length, 0);

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
        create_mock_poll();
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
        create_mock_poll();
        vm.warp(block.timestamp + 1 days);
        create_mock_poll();
        create_mock_poll();
        gogeDao.setGateKeeping(false);

        // transfer tokens to Joe for votes
        gogeToken.transfer(address(joe), 10_000_000_000 ether);

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 4 days);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 3);
        assertEq(activePolls[0], 1);
        assertEq(activePolls[1], 2);
        assertEq(activePolls[2], 3);

        assertEq(gogeToken.balanceOf(address(joe)), 10_000_000_000 ether);
        assertEq(gogeToken.balanceOf(address(gogeDao)), gogeDao.minAuthorBal() * 3);

        // Joe places votes on poll 1
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), 10_000_000_000 ether));
        assert(joe.try_addVote(address(gogeDao), 1, 10_000_000_000 ether));

        //Warp to end time
        vm.warp(block.timestamp + 4 days);

        // Call queryEndTime()
        gogeDao.queryEndTime();

        // Post-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 2);
        assertEq(activePolls[0], 3);
        assertEq(activePolls[1], 2);

        assertEq(gogeToken.balanceOf(address(joe)), 10_000_000_000 ether);
        assertEq(gogeToken.balanceOf(address(gogeDao)), gogeDao.minAuthorBal() * 2);
    }

    /// @notice Verify execution of poll when an admin calls passPoll
    function test_gogeDao_passPoll() public {
        create_mock_poll();
        gogeDao.setGateKeeping(false);
        gogeDao.transferOwnership(address(dev));

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.isActivePoll(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 5 days);

        // passPoll
        assert(dev.try_passPoll(address(gogeDao), 1));

        // Post-state check.
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.isActivePoll(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        // dev tries to call passPoll -> fails
        vm.prank(address(dev));
        vm.expectRevert("GogeDao.sol::passPoll() Poll Closed");
        gogeDao.passPoll(1);
    }

    /// @notice Verify execution of poll and voters refunded when passPoll is called.
    function test_gogeDao_passPoll_withVotes() public {
        create_mock_poll();
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
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 5 days);

        // passPoll
        assert(dev.try_passPoll(address(gogeDao), 1));

        // Post-state check.
        assertEq(gogeDao.passed(1), true);

        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 0);

        advocateArr = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateArr.length, 0);

        assertEq(gogeDao.isActivePoll(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        // dev tries to call passPoll -> fails
        vm.prank(address(dev));
        vm.expectRevert("GogeDao.sol::passPoll() Poll Closed");
        gogeDao.passPoll(1);
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
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 5 days);

        // endPoll
        assert(dev.try_endPoll(address(gogeDao), 1));

        // Post-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.isActivePoll(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        // dev tries to call endPoll -> fails
        vm.prank(address(dev));
        vm.expectRevert("GogeDao.sol::endPoll() Poll Closed");
        gogeDao.endPoll(1);

        // NOTE: Author ends poll
        create_mock_poll();

        // Pre-state check.
        assertEq(gogeDao.passed(2), false);
        assertEq(gogeDao.isActivePoll(2), true);
        assertEq(gogeDao.getProposal(2).endTime, block.timestamp + 5 days);

        // endPoll
        gogeDao.endPoll(2);

        // Post-state check.
        assertEq(gogeDao.passed(2), false);
        assertEq(gogeDao.isActivePoll(2), false);
        assertEq(gogeDao.getProposal(2).endTime, block.timestamp);
    }

    /// @notice Verify that when endPoll is called, existing voters are refunded.
    function test_gogeDao_endPoll_withVotes() public {
        create_mock_poll();

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
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 5 days);

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
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        // dev tries to call endPoll -> fails
        vm.prank(address(dev));
        vm.expectRevert("GogeDao.sol::endPoll() Poll Closed");
        gogeDao.endPoll(1);
    }

    /// @notice Verify gateKeeping enabled will need extra gatekeeper votes to pass a poll that's met quorum
    function test_gogeDao_gatekeeping() public {
        create_mock_poll();
        uint256 joe_votes = 50_000_000_000 ether;

        // Verify blacklist state and poll has not been passed
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
        assertEq(gogeDao.pollVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 5 days);

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum()); // quorum met

        // Verify poll has not been executed thus Joe is not blacklisted, yet.

        // Create gate keeper
        gogeDao.updateGateKeeper(address(dev), true);

        // gatekeeper adds vote to poll -> should pass poll
        assert(dev.try_passPollAsGatekeeper(address(gogeDao), 1));

        // Verify state change post poll being passed.
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 0);
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.polls(1, address(this)), gogeDao.minAuthorBal());
        assertEq(gogeDao.pollVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);
    }

    /// @notice Verify when payTeam is called the addresses held in teamMembers are paid out
    function test_gogeDao_payTeam() public {
        emit log_named_uint("BNB Balance", address(this).balance); // 79228162214.264337593543950335

        // add team members
        gogeDao.setTeamMember(address(jon), true);
        gogeDao.setTeamMember(address(tim), true);

        // update team balance on dao
        payable(address(gogeDao)).transfer(1 ether);

        vm.prank(address(gogeToken));
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

        _amount = bound(_amount, 3, address(this).balance);

        // add team members
        gogeDao.setTeamMember(address(jon), true);
        gogeDao.setTeamMember(address(tim), true);
        gogeDao.setTeamMember(address(joe), true);

        // update team balance on dao
        payable(address(gogeDao)).transfer(_amount);

        vm.prank(address(gogeToken));
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
        //assertEq(address(gogeDao).balance, 0 ether);
        assertEq(address(gogeDao).balance, gogeDao.teamBalance());
        assertEq(address(jon).balance, _amount / 3);
        assertEq(address(tim).balance, _amount / 3);
        assertEq(address(joe).balance, _amount / 3);

        assertEq(gogeDao.teamBalance(), _amount % 3);
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
        assertEq(gogeDao.pollVotes(1), 1_000 ether + gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(2, address(joe)), 1_000 ether);
        assertEq(gogeDao.pollVotes(2), 1_000 ether + gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(3, address(joe)), 1_000 ether);
        assertEq(gogeDao.pollVotes(3), 1_000 ether + gogeDao.minAuthorBal());

        // Joe removes all votes
        assert(joe.try_removeAllVotes(address(gogeDao)));

        // Verify state
        assertEq(gogeToken.balanceOf(address(joe)), 3_000 ether);
        assertEq(gogeToken.balanceOf(address(gogeDao)), gogeDao.minAuthorBal() * 3);

        assertEq(gogeDao.polls(1, address(joe)), 0);
        assertEq(gogeDao.pollVotes(1), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(2, address(joe)), 0);
        assertEq(gogeDao.pollVotes(2), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(3, address(joe)), 0);
        assertEq(gogeDao.pollVotes(3), gogeDao.minAuthorBal());
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
        assertEq(gogeDao.pollVotes(1), 1_000 ether + gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(2, address(joe)), 1_000 ether);
        assertEq(gogeDao.pollVotes(2), 1_000 ether + gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(3, address(joe)), 1_000 ether);
        assertEq(gogeDao.pollVotes(3), 1_000 ether + gogeDao.minAuthorBal());

        // Joe removes votes from poll 2
        assert(joe.try_removeVotesFromPoll(address(gogeDao), 2));

        // Verify state
        assertEq(gogeToken.balanceOf(address(joe)), 1_000 ether);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 2_000 ether + (gogeDao.minAuthorBal() * 3));
        assertEq(gogeDao.polls(1, address(joe)), 1_000 ether);
        assertEq(gogeDao.pollVotes(1), 1_000 ether + gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(2, address(joe)), 0);
        assertEq(gogeDao.pollVotes(2), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(3, address(joe)), 1_000 ether);
        assertEq(gogeDao.pollVotes(3), 1_000 ether + gogeDao.minAuthorBal());

        // Joe removes votes from poll 1
        assert(joe.try_removeVotesFromPoll(address(gogeDao), 1));

        // Verify state
        assertEq(gogeToken.balanceOf(address(joe)), 2_000 ether);
        assertEq(gogeToken.balanceOf(address(gogeDao)), 1_000 ether + (gogeDao.minAuthorBal() * 3));
        assertEq(gogeDao.polls(1, address(joe)), 0);
        assertEq(gogeDao.pollVotes(1), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(2, address(joe)), 0);
        assertEq(gogeDao.pollVotes(2), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(3, address(joe)), 1_000 ether);
        assertEq(gogeDao.pollVotes(3), 1_000 ether + gogeDao.minAuthorBal());

        // Joe removes votes from poll 3
        assert(joe.try_removeVotesFromPoll(address(gogeDao), 3));

        // Verify state
        assertEq(gogeToken.balanceOf(address(joe)), 3_000 ether);
        assertEq(gogeToken.balanceOf(address(gogeDao)), gogeDao.minAuthorBal() * 3);
        assertEq(gogeDao.polls(1, address(joe)), 0);
        assertEq(gogeDao.pollVotes(1), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(2, address(joe)), 0);
        assertEq(gogeDao.pollVotes(2), gogeDao.minAuthorBal());
        assertEq(gogeDao.polls(3, address(joe)), 0);
        assertEq(gogeDao.pollVotes(3), gogeDao.minAuthorBal());

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

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "This is a mock poll, for testing";
        proposal.endTime = block.timestamp + 5 days;

        // start prank
        vm.prank(address(joe));

        // expect next call to revert
        vm.expectRevert("GogeDao.sol::createPoll() Insufficient balance of tokens");

        // Joe attempts to call createPoll
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);

        // transfer tokens to Joe
        gogeToken.transfer(address(joe), gogeDao.minAuthorBal());
        assertEq(IERC20(address(gogeToken)).balanceOf(address(joe)), gogeDao.minAuthorBal());

        // start prank
        vm.prank(address(joe));

        // approve transfer of minAuthorBal
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());

        // Joe calls createPoll
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);

        // stop prank
        vm.stopPrank();

        // Post-state check.
        assertEq(gogeDao.pollNum(), 1);
        assertEq(gogeDao.getProposal(gogeDao.pollNum()).description, "This is a mock poll, for testing");
    }

    /// @notice Verifies maxPollsPerAuthor implementation -> Creators can only have x amount of activePolls at the same time ( x == maxPollsPerAuthor ).
    function test_gogeDao_maxPollsPerAuthor() public {

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "This is a mock poll, for testing";
        proposal.endTime = block.timestamp + 5 days;

        // transfer tokens to Joe
        gogeToken.transfer(address(joe), gogeDao.minAuthorBal());
        assertEq(IERC20(address(gogeToken)).balanceOf(address(joe)), gogeDao.minAuthorBal());

        // start prank
        vm.startPrank(address(joe));

        // Joe calls createPoll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);

        // stop prank
        vm.stopPrank();

        // Verify poll has been created
        assertEq(gogeDao.pollNum(), 1);
        assertEq(gogeDao.getProposal(gogeDao.pollNum()).description, "This is a mock poll, for testing");
        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);

        // start prank
        vm.startPrank(address(joe));

        // approve tokens for createPoll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());

        // expect next call to revert
        vm.expectRevert("GogeDao.sol::createPoll() Exceeds maxPollsPerAuthor");

        // Joe calls createPoll
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);

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
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);

        // stop prank
        vm.stopPrank();

        // Verify there's still only 1 poll live
        assertEq(gogeDao.pollNum(), 2);
        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
    }

    /// @notice Verify withdraw() function
    function test_gogeDao_withdraw() public {
        gogeDao.transferOwnership(address(dev));

        assertEq(address(gogeDao).balance, 0);
        assertEq(address(dev).balance, 0);

        // Deal bnb to dao contract
        uint256 _amount = 1_000 ether;
        vm.deal(address(gogeDao), _amount);
        assertEq(address(gogeDao).balance, _amount);

        // Withdraw balance
        vm.prank(address(dev));
        gogeDao.withdraw();

        assertEq(address(gogeDao).balance, 0);
        assertEq(address(dev).balance, _amount);

        // new owner -> clear balance
        vm.prank(address(dev));
        gogeDao.transferOwnership(address(joe));
        assertEq(address(joe).balance, 0);

        // send assets to dao and thi
        _amount = 1_000 ether;
        vm.deal(address(gogeDao), _amount);
        assertEq(address(gogeDao).balance, _amount);

        // update team bal and marketing bal
        vm.startPrank(address(gogeToken));
        gogeDao.updateTeamBalance(100 ether);
        gogeDao.updateMarketingBalance(200 ether);
        vm.stopPrank();

        // withdraw again
        vm.prank(address(joe));
        gogeDao.withdraw();

        assertEq(address(gogeDao).balance, 300 ether);
        assertEq(address(joe).balance, _amount - 300 ether);

        // withdraw AGAIN but this time expect insufficient reversion
        vm.prank(address(joe));
        vm.expectRevert("GogeDao.sol::withdraw() Insufficient BNB balance");
        gogeDao.withdraw();
    }

    /// @notice Test that ERC20 token amounts are withdrawn from the contract to the owner address.
    function test_gogeDao_withdrawERC20() public {
        uint256 _amount = 1_000_000 ether;

        // Use BUSD as an example ERC20 token
        IERC20 token = IERC20(BUSD);
        assertEq(token.balanceOf(address(gogeDao)), 0);
        assertEq(token.balanceOf(address(this)), 0);

        // Deal tokens to contract
        deal(address(BUSD), address(gogeDao), _amount);
        assertEq(token.balanceOf(address(gogeDao)), _amount);

        // Owner can withdraw ERC20 tokens
        gogeDao.withdrawERC20(BUSD);
        assertEq(token.balanceOf(address(gogeDao)), 0);
        assertEq(token.balanceOf(address(this)), _amount);

        // Owner cannot withdraw from token balance when the balance is zero
        vm.expectRevert("GogeDao.sol::withdrawERC20() Insufficient token balance");
        gogeDao.withdrawERC20(BUSD);

        // Owner cannot withdraw from the governance token address
        vm.expectRevert("GogeDao.sol::withdrawERC20() Address cannot be governance token");
        gogeDao.withdrawERC20(address(gogeToken));
    }

    /// @notice Verify that when toggleCreatePollEnabled is called, createPollEnabled is updated
    function test_gogeDao_toggleCreatePollEnabled() public {
        gogeToken.excludeFromFees(address(gogeDao), false);
        assertEq(gogeDao.createPollEnabled(), true);

        // toggle when dao is not excluded from fees
        vm.expectRevert("GogeDao.sol::toggleCreatePollEnabled() !isExcludedFromFees(address(this))");
        gogeDao.toggleCreatePollEnabled();

        // exclude dao from fees
        gogeToken.excludeFromFees(address(gogeDao), true);

        // execute toggle again
        gogeDao.toggleCreatePollEnabled();

        // post-state check
        assertEq(gogeDao.createPollEnabled(), false);
    }

}
