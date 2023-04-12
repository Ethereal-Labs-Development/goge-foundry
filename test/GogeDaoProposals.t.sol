// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import { Utility } from "./Utility.sol";
import { GogeDAO } from "../src/GogeDao.sol";
import { DogeGaySonFlat } from "../src/DeployedV2Token.sol";
import { IUniswapV2Router01, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";
import { IGogeERC20 } from "../src/interfaces/IGogeERC20.sol";

contract DaoTestProposals is Utility {
    GogeDAO gogeDao;
    DogeGaySonFlat gogeToken;
    address constant UNIV2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    function setUp() public {
        createActors();

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
        assertEq(gogeDao.getActivePolls().length, 0);

        assertEq(gogeToken.gogeDao(), address(gogeDao));
        assertEq(gogeToken.isExcludedFromFees(address(gogeDao)), true);
        assertEq(gogeToken.tradingIsEnabled(), true);
        assertEq(gogeToken.owner(), address(this));
        assertEq(gogeToken.balanceOf(address(this)), 95_000_000_000 ether);
    }


    // ~~ All poll type tests ~~

    /// @notice initiates a taxChange poll and verifies correct state change when poll is passed.
    function test_gogeDao_proposal_taxChange() public {
        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose a tax change";
        proposal.endTime = block.timestamp + 2 days;
        proposal.fee1 = 8;  // cakeDividendRewardsFee
        proposal.fee2 = 3;  // marketingFee
        proposal.fee3 = 4;  // buyBackFee
        proposal.fee4 = 5;  // teamFee

        // Create poll
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

        /// NOTE Manually pass poll

        // Pre-state check.
        assertEq(gogeToken.cakeDividendRewardsFee(), 10);
        assertEq(gogeToken.marketingFee(), 2);
        assertEq(gogeToken.buyBackFee(), 2);
        assertEq(gogeToken.teamFee(), 2);
        assertEq(gogeToken.totalFees(), 16);
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check => gogeDao.
        assertEq(gogeDao.pollVotes(1), gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        // Post-state check => gogeToken.
        assertEq(gogeToken.cakeDividendRewardsFee(), 8);
        assertEq(gogeToken.marketingFee(), 3);
        assertEq(gogeToken.buyBackFee(), 4);
        assertEq(gogeToken.teamFee(), 5);
        assertEq(gogeToken.totalFees(), 20);        
    }

    /// @notice initiates a funding poll and verifies correct state change when poll is passed.
    function test_gogeDao_proposal_funding() public {
        gogeDao.setGatekeeping(false);
        gogeDao.updateQuorum(30);

        payable(gogeDao).transfer(1_000 ether);
        vm.prank(address(gogeToken));
        gogeDao.updateMarketingBalance(1_000 ether);

        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose a funding";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr = address(joe);
        proposal.amount = 1_000 ether;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.funding, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.funding);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose a funding");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr, address(joe));
        assertEq(gogeDao.getProposal(1).amount, 1_000 ether);

        assertEq(address(joe).balance, 0);
        assertEq(address(gogeDao).balance, 1_000 ether);
        assertEq(gogeDao.marketingBalance(), 1_000 ether);

        // NOTE Manually pass poll

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check => gogeDao.
        assertEq(gogeDao.pollVotes(1), gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        assertEq(address(joe).balance, 1_000 ether);
        assertEq(address(gogeDao).balance, 0);
        assertEq(gogeDao.marketingBalance(), 0);     
    }

    /// @notice initiates a setGogeDao poll and verifies correct state change when poll is passed.
    function test_gogeDao_proposal_setGogeDao() public {
        address newDAO = makeAddr("New DAO");

        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose setGogeDao";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr = newDAO;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setGogeDao, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setGogeDao);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose setGogeDao");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr, newDAO);

        // NOTE Manually pass poll

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeToken.gogeDao(), address(gogeDao));

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check => gogeDao.
        assertEq(gogeDao.pollVotes(1), gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);
        assertEq(gogeToken.gogeDao(), newDAO);       
    }

    /// @notice initiates a setCex poll and verifies correct state change when poll is passed.
    function test_gogeDao_proposal_setCex() public {
        address newCEX = makeAddr("New CEX");

        // NOTE Create poll with proposal

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose setCex";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr = newCEX;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setCex, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setCex);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose setCex");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr, newCEX);

        // NOTE Manually pass poll

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeToken.isExcludedFromFees(newCEX), false);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check => gogeDao.
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);
        assertEq(gogeToken.isExcludedFromFees(newCEX), true);      
    }

    /// @notice initiates a setDex poll and verifies correct state change when poll is passed.
    function test_gogeDao_proposal_setDex() public {
        address newDEX = makeAddr("New DEX");

        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose setDex";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr = newDEX;
        proposal.status = true;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setDex, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setDex);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose setDex");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr, newDEX);
        assertEq(gogeDao.getProposal(1).status, true);

        // NOTE Manually pass poll

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeToken.automatedMarketMakerPairs(newDEX), false);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check => gogeDao.
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);
        assertEq(gogeToken.automatedMarketMakerPairs(newDEX), true);        
    }

    /// @notice initiates a excludeFromCirculatingSupply poll and verifies correct state change when poll is passed.
    function test_gogeDao_proposal_excludeFromCirculatingSupply() public {
        address excluded = makeAddr("Excluded");

        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose excludeFromCirculatingSupply";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr = excluded;
        proposal.status = true;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.excludeFromCirculatingSupply, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.excludeFromCirculatingSupply);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose excludeFromCirculatingSupply");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr, excluded);
        assertEq(gogeDao.getProposal(1).status, true);

        // NOTE Manually pass poll

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        (bool excludedPre,) = gogeToken.isExcludedFromCirculatingSupply(excluded);
        assertEq(excludedPre, false);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check => gogeDao.
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);
        (bool excludedPost,) = gogeToken.isExcludedFromCirculatingSupply(excluded);
        assertEq(excludedPost, true);
    }

    /// @notice Verifies correct state changes when a poll of PollType updateDividendToken is created and executed.
    function test_gogeDao_proposal_updateDividendToken() public {
        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the dividend token to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr = BUNY;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateDividendToken, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateDividendToken);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we update the dividend token to this address");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr, BUNY);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.cakeDividendToken(), CAKE);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.cakeDividendToken(), BUNY);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType updateMarketingWallet is created and executed.
    function test_gogeDao_proposal_updateMarketingWallet() public {
        address newMarketing = makeAddr("New Marketing Wallet");

        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the marketing wallet to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr = newMarketing;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateMarketingWallet, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateMarketingWallet);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we update the marketing wallet to this address");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr, newMarketing);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.marketingWallet(), 0xFecf1D51E984856F11B7D0872D40fC2F05377738);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.marketingWallet(), newMarketing);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType updateTeamWallet is created and executed.
    function test_gogeDao_proposal_updateTeamWallet() public {
        address newTeam = makeAddr("New Team Wallet");

        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the team wallet to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr = newTeam;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateTeamWallet, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateTeamWallet);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we update the team wallet to this address");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr, newTeam);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.teamWallet(), 0xC1Aa023A8fA820F4ed077f4dF4eBeD0a3351a324);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.teamWallet(), newTeam);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType updateTeamMember is created and executed.
    function test_gogeDao_proposal_updateTeamMember() public {
        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we add an address as a team member";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr = address(sal);
        proposal.status = true;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateTeamMember, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateTeamMember);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we add an address as a team member");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr, address(sal));
        assertEq(gogeDao.getProposal(1).status, true);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        (bool _member,) = gogeDao.isTeamMember(address(sal));
        assertEq(_member, false);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        (_member,) = gogeDao.isTeamMember(address(sal));
        assertEq(_member, true);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType updateGatekeeper is created and executed.
    function test_gogeDao_proposal_updateGatekeeper() public {
        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we add an address as a gatekeeper";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr = address(sal);
        proposal.status = true;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateGatekeeper, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateGatekeeper);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we add an address as a gatekeeper");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr, address(sal));
        assertEq(gogeDao.getProposal(1).status, true);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.gatekeeper(address(sal)), false);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.gatekeeper(address(sal)), true);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType setGatekeeping is created and executed.
    function test_gogeDao_proposal_setGatekeeping() public {
        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we enable gatekeeping";
        proposal.endTime = block.timestamp + 2 days;
        proposal.status = false;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setGatekeeping, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setGatekeeping);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we enable gatekeeping");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).status, false);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.gatekeeping(), true);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.gatekeeping(), false);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType setBuyBackEnabled is created and executed.
    function test_gogeDao_proposal_setBuyBackEnabled() public {
        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we disable buy back fees";
        proposal.endTime = block.timestamp + 2 days;
        proposal.status = false;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setBuyBackEnabled, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setBuyBackEnabled);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we disable buy back fees");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).status, false);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.buyBackEnabled(), true);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.buyBackEnabled(), false);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType setCakeDividendEnabled is created and executed.
    function test_gogeDao_proposal_setCakeDividendEnabled() public {
        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we disable cake dividends";
        proposal.endTime = block.timestamp + 2 days;
        proposal.status = false;

        // create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setCakeDividendEnabled, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setCakeDividendEnabled);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we disable cake dividends");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).status, false);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.cakeDividendEnabled(), true);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.cakeDividendEnabled(), false);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType setMarketingEnabled is created and executed.
    function test_gogeDao_proposal_setMarketingEnabled() public {
        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we disable marketing fees";
        proposal.endTime = block.timestamp + 2 days;
        proposal.status = false;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setMarketingEnabled, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setMarketingEnabled);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we disable marketing fees");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).status, false);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.marketingEnabled(), true);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.marketingEnabled(), false);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType setTeamEnabled is created and executed.
    function test_gogeDao_proposal_setTeamEnabled() public {
        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we disable team fees";
        proposal.endTime = block.timestamp + 2 days;
        proposal.status = false;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setTeamEnabled, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setTeamEnabled);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we disable team fees");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).status, false);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.teamEnabled(), true);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.teamEnabled(), false);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType excludeFromFees is created and executed.
    function test_gogeDao_proposal_excludeFromFees() public {
        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we exclude this address from fees";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr = address(sal);
        proposal.status = true;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.excludeFromFees, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.excludeFromFees);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we exclude this address from fees");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr, address(sal));
        assertEq(gogeDao.getProposal(1).status, true);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.isExcludedFromFees(address(sal)), false);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.isExcludedFromFees(address(sal)), true);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType modifyBlacklist is created and executed.
    function test_gogeDao_proposal_modifyBlacklist() public {
        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we blacklist this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr = address(sal);
        proposal.status = true;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.modifyBlacklist, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.modifyBlacklist);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we blacklist this address");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr, address(sal));
        assertEq(gogeDao.getProposal(1).status, true);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.isBlacklisted(address(sal)), false);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.isBlacklisted(address(sal)), true);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType transferOwnership is created and executed.
    function test_gogeDao_proposal_transferOwnership() public {
        gogeToken.transferOwnership(address(gogeDao));

        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we transfer ownership to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr = address(sal);

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.transferOwnership, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.transferOwnership);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we transfer ownership to this address");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr, address(sal));

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeToken.owner(), address(gogeDao));

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken.owner(), address(sal));

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType setQuorum is created and executed.
    function test_gogeDao_proposal_setQuorum() public {
        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we change the quorum to this amount";
        proposal.endTime = block.timestamp + 2 days;
        proposal.amount = 30;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setQuorum, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setQuorum);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we change the quorum to this amount");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).amount, 30);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.quorum(), 50);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.quorum(), 30);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType updateGovernanceToken is created and executed.
    function test_gogeDao_proposal_updateGovernanceToken() public {
        address newGovToken = makeAddr("New Governance Token");

        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the governance token to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr = newGovToken;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateGovernanceToken, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateGovernanceToken);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we update the governance token to this address");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr, newGovToken);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.governanceToken(), address(gogeToken));

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.governanceToken(), newGovToken);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType updateMaxPeriod is created and executed.
    function test_gogeDao_proposal_updateMaxPeriod() public {
        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the max poll period to 90 days";
        proposal.endTime = block.timestamp + 2 days;
        proposal.amount = 90;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateMaxPeriod, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateMaxPeriod);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we update the max poll period to 90 days");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).amount, 90);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.maxPeriod(), 60 days);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.maxPeriod(), 90 days);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of PollType updateMinAuthorBal is created and executed.
    function test_gogeDao_proposal_updateMinAuthorBal() public {
        // NOTE Create poll with proposal

        // Create proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the minimum author balance to 420M tokens";
        proposal.endTime = block.timestamp + 2 days;
        proposal.amount = 420_000_000;

        // Create poll
        gogeToken.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateMinAuthorBal, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateMinAuthorBal);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we update the minimum author balance to 420M tokens");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).amount, 420_000_000);

        // NOTE Manually pass poll

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.minAuthorBal(), 10_000_000 ether);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.minAuthorBal(), 420_000_000 ether);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

}