// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import { Utility } from "./Utility.sol";
import { GogeDAO } from "../src/GogeDao.sol";
import { DogeGaySonFlat } from "../src/DeployedV2Token.sol";

import { IUniswapV2Router01, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";
import { IGogeERC20 } from "../src/extensions/IGogeERC20.sol";

contract DaoTestProposals is Utility {
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
        assertEq(address(gogeToken), gogeDao.governanceToken());
        assertEq(gogeDao.pollNum(), 0);
    }


    // ~~ All poll type tests ~~

    /// @notice initiates a taxChange poll and verifies correct state change when poll is passed.
    function test_gogeDao_proposal_taxChange() public {

        /// NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose a tax change";
        proposal.endTime = block.timestamp + 2 days;
        proposal.fee1 = 8;  // cakeDividendRewardsFee
        proposal.fee2 = 3;  // marketingFee
        proposal.fee3 = 4;  // buyBackFee
        proposal.fee4 = 5;  // teamFee

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.taxChange, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.taxChange);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose a tax change");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).fee1, 8);
        assertEq(gogeDao.getProposal(1).fee2, 3);
        assertEq(gogeDao.getProposal(1).fee3, 4);
        assertEq(gogeDao.getProposal(1).fee4, 5);

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
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.pollVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

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
    function test_gogeDao_proposal_funding() public {
        gogeDao.setGateKeeping(false);

        payable(address(gogeDao)).transfer(1_000 ether);

        vm.prank(address(gogeToken));
        gogeDao.updateMarketingBalance(1_000 ether);
        vm.stopPrank();

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose a funding";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(joe);
        proposal.amount = 1_000 ether;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.funding, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.funding);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose a funding");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(joe));
        assertEq(gogeDao.getProposal(1).amount, 1_000 ether);

        assertEq(address(joe).balance, 0);
        assertEq(address(gogeDao).balance, 1_000 ether);
        assertEq(gogeDao.marketingBalance(), 1_000 ether);

        // NOTE pass poll
        
        uint256 joe_votes = 50_000_000_000 ether;

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.pollVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        assertEq(address(joe).balance, 1_000 ether);
        assertEq(address(gogeDao).balance, 0);
        assertEq(gogeDao.marketingBalance(), 0);

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());        
    }

    /// @notice initiates a setGogeDao poll and verifies correct state change when poll is passed.
    function test_gogeDao_proposal_setGogeDao() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose setGogeDao";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(222);

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setGogeDao, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setGogeDao);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose setGogeDao");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(222));

        // NOTE pass poll
        
        uint256 joe_votes = 50_000_000_000 ether;
        gogeDao.setGateKeeping(false);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeToken.gogeDao(), address(gogeDao));

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.pollVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        assertEq(gogeToken.gogeDao(), address(222));

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());        
    }

    /// @notice initiates a setCex poll and verifies correct state change when poll is passed.
    function test_gogeDao_proposal_setCex() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose setCex";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(222);

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setCex, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setCex);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose setCex");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(222));

        // NOTE pass poll
        
        uint256 joe_votes = 50_000_000_000 ether;
        gogeDao.setGateKeeping(false);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeToken.isExcludedFromFees(address(222)), false);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.pollVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        assertEq(gogeToken.isExcludedFromFees(address(222)), true);

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());        
    }

    /// @notice initiates a setDex poll and verifies correct state change when poll is passed.
    function test_gogeDao_proposal_setDex() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose setDex";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(222);
        proposal.boolVar = true;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setDex, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setDex);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose setDex");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(222));
        assertEq(gogeDao.getProposal(1).boolVar, true);

        // NOTE pass poll
        
        uint256 joe_votes = 50_000_000_000 ether;
        gogeDao.setGateKeeping(false);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeToken.automatedMarketMakerPairs(address(222)), false);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.pollVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        assertEq(gogeToken.automatedMarketMakerPairs(address(222)), true);

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());        
    }

    /// @notice initiates a excludeFromCirculatingSupply poll and verifies correct state change when poll is passed.
    function test_gogeDao_proposal_excludeFromCirculatingSupply() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose excludeFromCirculatingSupply";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(222);
        proposal.boolVar = true;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.excludeFromCirculatingSupply, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.excludeFromCirculatingSupply);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose excludeFromCirculatingSupply");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(222));
        assertEq(gogeDao.getProposal(1).boolVar, true);

        // NOTE pass poll
        
        uint256 joe_votes = 50_000_000_000 ether;
        gogeDao.setGateKeeping(false);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken.transfer(address(joe), joe_votes);
        assertEq(gogeToken.balanceOf(address(joe)), joe_votes);

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        (bool excludedPre,) = gogeToken.isExcludedFromCirculatingSupply(address(222));
        assertEq(excludedPre, false);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.pollVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        (bool excludedPost,) = gogeToken.isExcludedFromCirculatingSupply(address(222));
        assertEq(excludedPost, true);

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());
    }

    /// @notice Verifies correct state changes when a poll of pollType updateDividendToken is created and executed.
    function test_gogeDao_proposal_updateDividendToken() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the dividend token to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = BUNY;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateDividendToken, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateDividendToken);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we update the dividend token to this address");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, BUNY);

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
    function test_gogeDao_proposal_updateMarketingWallet() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the marketing wallet to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(this);

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateMarketingWallet, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateMarketingWallet);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we update the marketing wallet to this address");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(this));

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
    function test_gogeDao_proposal_updateTeamWallet() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the team wallet to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(this);

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateTeamWallet, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateTeamWallet);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we update the team wallet to this address");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(this));

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
    function test_gogeDao_proposal_updateTeamMember() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we add an address as a team member";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(sal);
        proposal.boolVar = true;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateTeamMember, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateTeamMember);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we add an address as a team member");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(sal));
        assertEq(gogeDao.getProposal(1).boolVar, true);

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

    /// @notice Verifies correct state changes when a poll of pollType updateGatekeeper is created and executed.
    function test_gogeDao_proposal_updateGatekeeper() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we add an address as a gate keeper";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(sal);
        proposal.boolVar = true;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateGatekeeper, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateGatekeeper);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we add an address as a gate keeper");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(sal));
        assertEq(gogeDao.getProposal(1).boolVar, true);

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.gatekeeper(address(sal)), false);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.gatekeeper(address(sal)), true);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType setGatekeeping is created and executed.
    function test_gogeDao_proposal_setGatekeeping() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we enable gate keeping";
        proposal.endTime = block.timestamp + 2 days;
        proposal.boolVar = false;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setGatekeeping, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setGatekeeping);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we enable gate keeping");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).boolVar, false);

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.gatekeeping(), true);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.gatekeeping(), false);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType setBuyBackEnabled is created and executed.
    function test_gogeDao_proposal_setBuyBackEnabled() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we disable buy back fees";
        proposal.endTime = block.timestamp + 2 days;
        proposal.boolVar = false;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setBuyBackEnabled, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setBuyBackEnabled);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we disable buy back fees");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).boolVar, false);

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.buyBackEnabled(), true);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.buyBackEnabled(), false);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType setCakeDividendEnabled is created and executed.
    function test_gogeDao_proposal_setCakeDividendEnabled() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we disable cake dividends";
        proposal.endTime = block.timestamp + 2 days;
        proposal.boolVar = false;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setCakeDividendEnabled, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setCakeDividendEnabled);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we disable cake dividends");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).boolVar, false);

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.cakeDividendEnabled(), true);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.cakeDividendEnabled(), false);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType setMarketingEnabled is created and executed.
    function test_gogeDao_proposal_setMarketingEnabled() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we disable marketing fees";
        proposal.endTime = block.timestamp + 2 days;
        proposal.boolVar = false;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setMarketingEnabled, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setMarketingEnabled);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we disable marketing fees");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).boolVar, false);

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.marketingEnabled(), true);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.marketingEnabled(), false);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType setTeamEnabled is created and executed.
    function test_gogeDao_proposal_setTeamEnabled() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we disable team fees";
        proposal.endTime = block.timestamp + 2 days;
        proposal.boolVar = false;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setTeamEnabled, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setTeamEnabled);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we disable team fees");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).boolVar, false);

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.teamEnabled(), true);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.teamEnabled(), false);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType excludeFromFees is created and executed.
    function test_gogeDao_proposal_excludeFromFees() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we exclude this address from fees";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(sal);
        proposal.boolVar = true;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.excludeFromFees, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.excludeFromFees);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we exclude this address from fees");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(sal));
        assertEq(gogeDao.getProposal(1).boolVar, true);

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.isExcludedFromFees(address(sal)), false);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.isExcludedFromFees(address(sal)), true);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType modifyBlacklist is created and executed.
    function test_gogeDao_proposal_modifyBlacklist() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we blacklist this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(sal);
        proposal.boolVar = true;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.modifyBlacklist, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.modifyBlacklist);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we blacklist this address");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(sal));
        assertEq(gogeDao.getProposal(1).boolVar, true);

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.isBlacklisted(address(sal)), false);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.isBlacklisted(address(sal)), true);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType transferOwnership is created and executed.
    function test_gogeDao_proposal_transferOwnership() public {
        gogeToken.transferOwnership(address(gogeDao));

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we transfer ownership to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(sal);

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.transferOwnership, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.transferOwnership);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we transfer ownership to this address");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(sal));

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.owner(), address(gogeDao));

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.owner(), address(sal));

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType setQuorum is created and executed.
    function test_gogeDao_proposal_setQuorum() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we transfer ownership to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.amount = 30;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setQuorum, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setQuorum);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we transfer ownership to this address");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).amount, 30);

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.quorum(), 50);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.quorum(), 30);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType updateGovernanceToken is created and executed.
    function test_gogeDao_proposal_updateGovernanceToken() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the governance token to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(this);

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateGovernanceToken, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateGovernanceToken);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we update the governance token to this address");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(this));

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.governanceToken(), address(gogeToken));

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.governanceToken(), address(this));

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }
}
