// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import { Utility } from "./Utility.sol";
import { Actor } from "../src/users/Actor.sol";

import { IUniswapV2Router01, IUniswapV2Router02, IUniswapV2Pair, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";
import { IGogeERC20 } from "../src/interfaces/IGogeERC20.sol";

import { DogeGaySon, CakeDividendTracker } from "../src/GogeToken.sol";
import { DogeGaySonFlat } from "src/DeployedV2Token.sol";

import { DogeGaySon1 } from "../src/TokenV1.sol";
import { GogeDAO } from "../src/GogeDao.sol";

contract MainDeploymentTesting is Utility {
    DogeGaySon1 gogeToken_v1;
    DogeGaySonFlat gogeToken_v2;
    GogeDAO gogeDao;

    address UNIV2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E; //bsc

    function setUp() public {
        createActors();
        setUpTokens();

        // Deploy v1 token
        gogeToken_v1 = new DogeGaySon1();

        uint256 BNB_DEPOSIT = 300 ether;
        uint256 TOKEN_DEPOSIT = 22_310_409_737 ether;

        IWETH(WBNB).deposit{value: BNB_DEPOSIT}();

        // Approve TaxToken for UniswapV2Router.
        IERC20(address(gogeToken_v1)).approve(address(UNIV2_ROUTER), TOKEN_DEPOSIT);

        // Create liquidity pool.
        IUniswapV2Router01(UNIV2_ROUTER).addLiquidityETH{value: 220 ether}(
            address(gogeToken_v1),
            TOKEN_DEPOSIT,
            TOKEN_DEPOSIT,
            220 ether,
            address(this),
            block.timestamp + 300
        );

        // enable trading for v1
        gogeToken_v1.afterPreSale();
        gogeToken_v1.setTradingIsEnabled(true, 0);

        // Show price
        uint256 price = getPrice(address(gogeToken_v1));
        emit log_named_uint("cost of 1 v1 token", price); // 0.000003073904665581

        // Create holders of v1 token
        createHolders();

        // TODO: (1) Check dev address and router before deploying
        //       router must be for BSC -> 0x10ED43C718714eb63d5aA57B78B54704E256024E
        //       VERIFY DEV WALLET
        // TODO: (2) Deploy v2 token
        // deployer -> 0x5f058D82Fc62f019Dd5F4b892571455F49651338
        // gogeToken_v2 = new DogeGaySon(
        //     address(0xFecf1D51E984856F11B7D0872D40fC2F05377738), // MARKETING wallet
        //     address(0xC1Aa023A8fA820F4ed077f4dF4eBeD0a3351a324), // TEAM wallet
        //     100_000_000_000,
        //     address(gogeToken_v1) // will be 0xa30d02c5cdb6a76e47ea0d65f369fd39618541fe
        // );
        gogeToken_v2 = new DogeGaySonFlat(
            address(gogeToken_v1)
        );

        // TODO: (2a) Whitelist wallets
        // 0x0dC5085dEbA25B55db3A13d1c320c08af1740549

        // TODO: (2b) exclude from dividends
        // 0x0dC5085dEbA25B55db3A13d1c320c08af1740549

        // TODO: (3) Disable trading on v1 -> set to false
        gogeToken_v1.setTradingIsEnabled(false, 0);

        // TODO: (4) Exclude v2 from fees on v1
        gogeToken_v1.excludeFromFees(address(gogeToken_v2), true);

        // TODO: (5) Perform migration
        migrateActor(tim);
        migrateActor(joe);
        migrateActor(sal);
        migrateActor(nik);
        migrateActor(jon);

        // Show price of v2
        price = getPrice(address(gogeToken_v2));
        emit log_named_uint("cost of 1 v2 token", price); // 0.000002119865796663

        // TODO: (6) Perform mass airdrop to private sale contributors
        // NOTE: IF USING BULKSENDER -> MAKE SURE TO WHITELIST BULKSENDER CONTRACT
        gogeToken_v2.transfer(address(567), 20_000_000_000 ether);

        // TODO: (7) enableTrading() on v2
        gogeToken_v2.enableTrading();


        ////////////////////////////////// PHASE 2 //////////////////////////////////////////


        // TODO: (1) launch DAO
        gogeDao = new GogeDAO(address(gogeToken_v2));

        // TODO: (2) SetDao on Token contract
        gogeToken_v2.setGogeDao(address(gogeDao));

        // TODO: (3) exclude any locks from circulating supply
            // - already excluded address(dead), pair, and pinkLock

        // TODO: (4) enable createPoll
        gogeDao.toggleCreatePollEnabled();

        // TODO: (5) setup automation for GogeDao.sol::queryEndTime
    }


    // ~~ Utility Functions ~~

    /// @notice Returns the price of 1 token in USD
    function getPrice(address token) internal returns (uint256) {
        address[] memory path = new address[](3);

        path[0] = token;
        path[1] = WBNB;
        path[2] = BUSD;

        uint256[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(1 ether, path);

        return amounts[2];
    }

    /// @notice Creates v1 token holders. The holder balances should total just under 22B tokens
    function createHolders() internal {
        //Initialize wallet amounts.
        uint256 amountJoe = 10_056_322_590 ether;
        uint256 amountSal = 8_610_217_752 ether;
        uint256 amountNik = 900_261_463 ether;
        uint256 amountJon = 200_984_357 ether;
        uint256 amountTim = 600_000 ether;

        // Transfer tokens to Joe so he can migrate.
        gogeToken_v1.transfer(address(joe), amountJoe);
        gogeToken_v1.transfer(address(sal), amountSal);
        gogeToken_v1.transfer(address(nik), amountNik);
        gogeToken_v1.transfer(address(jon), amountJon);
        gogeToken_v1.transfer(address(tim), amountTim);

        // Verify amount v1 and 0 v2 tokens.
        assertEq(gogeToken_v1.balanceOf(address(joe)), amountJoe);
        assertEq(gogeToken_v1.balanceOf(address(sal)), amountSal);
        assertEq(gogeToken_v1.balanceOf(address(nik)), amountNik);
        assertEq(gogeToken_v1.balanceOf(address(jon)), amountJon);
        assertEq(gogeToken_v1.balanceOf(address(tim)), amountTim);
    }

    /// @notice migrate tokens from v1 to v2
    function migrateActor(Actor actor) internal {
        uint256 bal = gogeToken_v1.balanceOf(address(actor));
        uint256 bal2 = gogeToken_v2.balanceOf(address(actor));
        uint256 LiquidityPreBal = IERC20(gogeToken_v2.uniswapV2Pair()).balanceOf(address(this));

        // Approve and migrate
        assert(actor.try_approveToken(address(gogeToken_v1), address(gogeToken_v2), gogeToken_v1.balanceOf(address(actor))));
        assert(actor.try_migrate(address(gogeToken_v2)));

        uint256 LiquidityPostBal = IERC20(gogeToken_v2.uniswapV2Pair()).balanceOf(address(this));

        assertGt(LiquidityPostBal - LiquidityPreBal, 0);

        assertEq(gogeToken_v1.balanceOf(address(actor)), 0);
        assertEq(gogeToken_v2.balanceOf(address(actor)), bal2 + bal);
    }

    /// @notice Perform a buy
    function buy_generateFees(uint256 tradeAmt) public {

        IERC20(WBNB).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path = new address[](2);

        path[0] = WBNB;
        path[1] = address(gogeToken_v2);

        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path,
            address(this),
            block.timestamp + 300
        );
    }

    /// @notice Perform a buy
    function sell_generateFees(uint256 tradeAmt) public {

        IERC20(address(gogeToken_v2)).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path = new address[](2);

        path[0] = address(gogeToken_v2);
        path[1] = WBNB;

        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path,
            address(this),
            block.timestamp + 300
        );
    }

    /// @notice Creates a mock poll
    function create_mock_poll() public {
        uint256 _pollNum = gogeDao.pollNum();

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "This is a mock poll, for testing";
        proposal.endTime = block.timestamp + 5 days;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.other, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), _pollNum + 1);
        assertEq(gogeDao.getProposal(gogeDao.pollNum()).description, "This is a mock poll, for testing");
        assertEq(gogeDao.getProposal(gogeDao.pollNum()).endTime, block.timestamp + 5 days);
        assertEq(gogeDao.pollAuthor(gogeDao.pollNum()), address(this));
        assert(gogeDao.pollTypes(gogeDao.pollNum()) == GogeDAO.PollType.other);
    }


    // ~~ Init State Test ~~

    /// @notice Initial state test.
    function test_mainDeployment_init_state() public {
        // TOKEN
        assertEq(gogeToken_v2.tradingIsEnabled(), true);
        assertEq(gogeToken_v2.migrationCounter(), 5);
        assertEq(gogeToken_v2.gogeDao(), address(gogeDao));
        assertEq(gogeToken_v2.isExcludedFromFees(address(gogeDao)), true);
        assertEq(gogeToken_v2.owner(), address(this));
        assertEq(gogeToken_v2.balanceOf(address(this)), 80_000_000_000 ether);
        assertEq(gogeToken_v2.getCirculatingMinusReserve(), gogeToken_v2.totalSupply() - gogeToken_v2.balanceOf(gogeToken_v2.uniswapV2Pair()));

        // DAO
        assertEq(gogeDao.governanceToken(), address(gogeToken_v2));
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
    }


    // ~~ Unit Tests (Token) ~~

    /// @notice Tests buy post trading being enabled.
    function test_mainDeployment_buy() public {
        gogeToken_v2.excludeFromFees(address(this), false);

        uint256 tradeAmt = 5 ether;

        // Verify address(this) is NOT excluded from fees and grab pre balance.
        assert(!gogeToken_v2.isExcludedFromFees(address(this)));
        uint256 preBal = gogeToken_v2.balanceOf(address(this));

        // Deposit 10 BNB
        uint BNB_DEPOSIT = 10 ether;
        IWETH(WBNB).deposit{value: BNB_DEPOSIT}();

        // Create path
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(gogeToken_v2);

        // Get Quoted amount
        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut( tradeAmt, path );

        // Execute purchase
        buy_generateFees(tradeAmt);

        // Grab post balanace and calc amount goge tokens received.
        uint256 postBal        = gogeToken_v2.balanceOf(address(this));
        uint256 amountReceived = (postBal - preBal);
        uint256 taxedAmount    = amounts[1] * gogeToken_v2.totalFees() / 100; //amounts[1] * 16%

        // Verify the quoted amount is the amount received and no royalties were generated.
        assertEq(amounts[1] - taxedAmount, amountReceived);
        assertEq(gogeToken_v2.balanceOf(address(gogeToken_v2)), taxedAmount);

        // Log
        emit log_uint(amounts[1]);
        emit log_uint(amountReceived);
        emit log_uint(gogeToken_v2.balanceOf(address(gogeToken_v2)));
    }

    /// @notice Tests sell post trading being enabled.
    function test_mainDeployment_sell() public {
        gogeToken_v2.excludeFromFees(address(this), false);

        // Verify address(this) is NOT excluded from fees and grab pre balance.
        assert(!gogeToken_v2.isExcludedFromFees(address(this)));
        uint256 preBal = IERC20(WBNB).balanceOf(address(this));

        uint256 tradeAmt = 1_000_000 ether;

        // approve sell
        IERC20(address(gogeToken_v2)).approve(address(UNIV2_ROUTER), tradeAmt);

        address[] memory path = new address[](2);
        path[0] = address(gogeToken_v2);
        path[1] = WBNB;

        // Get Quoted amount
        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut( tradeAmt, path );

        // Execute purchase
        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path,
            address(this),
            block.timestamp + 300
        );

        // Grab post balanace and calc amount goge tokens received.
        uint256 postBal        = IERC20(WBNB).balanceOf(address(this));
        uint256 amountReceived = (postBal - preBal);
        uint256 afterTaxAmount = amounts[1] * 84 / 100;

        // Verify the quoted amount is the amount received and no royalties were generated.
        withinDiff(afterTaxAmount, amountReceived, 10**12);
        assertEq(IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2)), amounts[0] * 16 / 100);

        // Log
        emit log_named_uint("amount bnb quoted", amounts[1]);
        emit log_named_uint("amount bnb received", amountReceived);
        emit log_named_uint("amount royalties", IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2)));
    }

    /// @notice Tests migrations post trading being enabled.
    function test_mainDeployment_migrationPostTradingEnabled() public {
        // Creating a new actor to migrate
        Actor jeff = new Actor();
        uint256 amountJeff = 1_000_000_000 ether;

        // Transfer v1 tokens to jeff
        gogeToken_v1.transfer(address(jeff), amountJeff);

        // Verify balance
        assertEq(gogeToken_v1.balanceOf(address(jeff)), amountJeff);

        // migrate
        migrateActor(jeff);
    }

    /// @notice Verify taxes are being sent to the right wallets.
    function test_mainDeployment_royalties() public {
        // Royalty Recipients
        address marketingAddy = 0xFecf1D51E984856F11B7D0872D40fC2F05377738;
        address teamAddy      = 0xC1Aa023A8fA820F4ed077f4dF4eBeD0a3351a324;
        address devAddy       = 0x5f058D82Fc62f019Dd5F4b892571455F49651338;
        address deadAddy      = 0x000000000000000000000000000000000000dEaD;

        // Get pre balances of royalty recipients
        uint256 preBalMarketing = marketingAddy.balance;
        uint256 preBalTeam      = teamAddy.balance;
        uint256 preBalDev       = devAddy.balance;
        uint256 preBalDead      = gogeToken_v2.balanceOf(deadAddy);

        // Remove address(this) from whitelist so we can yield a buy tax.
        gogeToken_v2.excludeFromFees(address(this), false);

        // Check balance of address(gogeToken_v2) to see how many tokens have been taxed. Should be 0
        assertEq(IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2)), 0);

        // Generate buy -> log amount of tokens accrued
        buy_generateFees(10 ether);
        emit log_uint(IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2))); // 72561945.896794726074107751
        emit log_uint(address(gogeToken_v2).balance); // 0

        // Generate sell -> Distribute fees
        sell_generateFees(1_000 ether);
        emit log_uint(IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2))); // 1600.00000000000000000
        emit log_uint(address(gogeToken_v2).balance); // 0

        // take post balanaces
        uint256 postBalMarketing = marketingAddy.balance;
        uint256 postBalTeam      = teamAddy.balance;
        uint256 postBalDev       = devAddy.balance;
        uint256 postBalDead      = gogeToken_v2.balanceOf(deadAddy);

        // verify that the royalty recipients have indeed recieved royalties
        assertGt(postBalMarketing, preBalMarketing);
        assertGt(postBalTeam,      preBalTeam);
        assertGt(postBalDev,       preBalDev);
        assertGt(postBalDead,      preBalDead);

        // very amount received
        uint256 marketingReceived = postBalMarketing - preBalMarketing;
        uint256 teamReceived      = postBalTeam - preBalTeam;
        uint256 devReceived       = postBalDev - preBalDev;
        uint256 deadReceived      = postBalDead - preBalDead;

        // Verify amount received is amount sent.
        assertEq(marketingReceived, gogeToken_v2.royaltiesSent(1));
        assertEq(teamReceived,      gogeToken_v2.royaltiesSent(3));
        assertEq(devReceived,       gogeToken_v2.royaltiesSent(2));

        // log amount
        emit log_named_uint("marketing", gogeToken_v2.royaltiesSent(1));
        emit log_named_uint("dev",       gogeToken_v2.royaltiesSent(2));
        emit log_named_uint("team",      gogeToken_v2.royaltiesSent(3));
        emit log_named_uint("buyback",   gogeToken_v2.royaltiesSent(4));
        emit log_named_uint("cake",      gogeToken_v2.royaltiesSent(5));
    }

    /// @notice Verify correct royalties post dev fee (60 days).
    function test_mainDeployment_royalties_noDev() public {
        // Royalty Recipients
        address marketingAddy = 0xFecf1D51E984856F11B7D0872D40fC2F05377738;
        address teamAddy      = 0xC1Aa023A8fA820F4ed077f4dF4eBeD0a3351a324;
        address devAddy       = 0x5f058D82Fc62f019Dd5F4b892571455F49651338;
        address deadAddy      = 0x000000000000000000000000000000000000dEaD;

        // Get pre balances of royalty recipients
        uint256 preBalMarketing = marketingAddy.balance;
        uint256 preBalTeam      = teamAddy.balance;
        uint256 preBalDev       = devAddy.balance;
        uint256 preBalDead      = gogeToken_v2.balanceOf(deadAddy);

        // Remove address(this) from whitelist so we can yield a buy tax.
        gogeToken_v2.excludeFromFees(address(this), false);
        vm.warp(block.timestamp + 61 days);

        // Check balance of address(gogeToken_v2) to see how many tokens have been taxed. Should be 0
        assertEq(IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2)), 0);

        // Generate buy -> log amount of tokens accrued
        buy_generateFees(10 ether);
        emit log_uint(IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2))); // 72561945.896794726074107751
        emit log_uint(address(gogeToken_v2).balance); // 0

        // Generate sell -> Distribute fees
        sell_generateFees(1_000 ether);
        emit log_uint(IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2))); // 1600.00000000000000000
        emit log_uint(address(gogeToken_v2).balance); // 0

        // take post balanaces
        uint256 postBalMarketing = marketingAddy.balance;
        uint256 postBalTeam      = teamAddy.balance;
        uint256 postBalDev       = devAddy.balance;
        uint256 postBalDead      = gogeToken_v2.balanceOf(deadAddy);

        // verify that the royalty recipients have indeed recieved royalties
        assertGt(postBalMarketing, preBalMarketing);
        assertGt(postBalTeam,      preBalTeam);
        assertEq(postBalDev,       preBalDev); // no change in dev balance
        assertGt(postBalDead,      preBalDead);

        // very amount received
        uint256 marketingReceived = postBalMarketing - preBalMarketing;
        uint256 teamReceived      = postBalTeam - preBalTeam;
        uint256 devReceived       = postBalDev - preBalDev;
        uint256 deadReceived      = postBalDead - preBalDead;

        // Verify amount received is amount sent.
        assertEq(marketingReceived, gogeToken_v2.royaltiesSent(1));
        assertEq(teamReceived,      gogeToken_v2.royaltiesSent(3));
        assertEq(devReceived,       gogeToken_v2.royaltiesSent(2));
        assertEq(devReceived,       0);

        // log amount
        emit log_named_uint("marketing", gogeToken_v2.royaltiesSent(1));
        emit log_named_uint("dev",       gogeToken_v2.royaltiesSent(2));
        emit log_named_uint("team",      gogeToken_v2.royaltiesSent(3));
        emit log_named_uint("buyback",   gogeToken_v2.royaltiesSent(4));
        emit log_named_uint("cake",      gogeToken_v2.royaltiesSent(5));
    }

    /// @notice Verifies that v1 holders can still migrate post tradingEnabled
    function test_mainDeployment_migratePostBuy() public {
        // create new temporary actor
        Actor simone = new Actor();

        // give actor v1 tokens and v2 tokens
        gogeToken_v1.transfer(address(simone), 10_000_000 ether);
        gogeToken_v2.transfer(address(simone), 1_000_000 ether);

        // assert balances
        assertEq(gogeToken_v1.balanceOf(address(simone)), 10_000_000 ether);
        assertEq(gogeToken_v2.balanceOf(address(simone)), 1_000_000 ether);

        // attempt migrate
        migrateActor(simone);
    }


    // ~~ Behavioral Tests (DAO) ~~

    /// NOTE: Functions

    /// @notice Verify the ability for holders of gogeToken to create polls on gogeDao
    function test_mainDeployment_dao_createPoll() public {

        // Pre-state check
        uint256 _preBal = gogeToken_v2.balanceOf(address(joe));
        uint256 _pollNum = gogeDao.pollNum();

        assertEq(gogeToken_v2.balanceOf(address(gogeDao)), 0);

        address[] memory voters = gogeDao.getVoterLibrary(gogeDao.pollNum());
        assertEq(voters.length, 0);
        uint256[] memory advocateFor = gogeDao.getAdvocateFor(address(joe));
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
        vm.startPrank(address(joe));
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.modifyBlacklist, proposal);
        vm.stopPrank();

        // Post-state check
        assertEq(gogeDao.pollNum(), _pollNum + 1);
        assertEq(gogeDao.pollAuthor(gogeDao.pollNum()), address(joe));
        assert(gogeDao.pollTypes(gogeDao.pollNum()) == GogeDAO.PollType.modifyBlacklist);

        assertEq(gogeDao.getProposal(gogeDao.pollNum()).description, "I want to add Joe to the naughty list");
        assertEq(gogeDao.getProposal(gogeDao.pollNum()).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(gogeDao.pollNum()).addr1, address(joe));
        assertEq(gogeDao.getProposal(gogeDao.pollNum()).boolVar, true);

        assertEq(gogeDao.polls(gogeDao.pollNum(), address(joe)), gogeDao.minAuthorBal());
        assertEq(gogeDao.pollVotes(gogeDao.pollNum()), gogeDao.minAuthorBal());
        assertEq(gogeToken_v2.balanceOf(address(gogeDao)), gogeDao.minAuthorBal());
        assertEq(gogeToken_v2.balanceOf(address(joe)), _preBal - gogeDao.minAuthorBal());

        voters = gogeDao.getVoterLibrary(gogeDao.pollNum());
        assertEq(voters.length, 1);
        assertEq(voters[0], address(joe));

        advocateFor = gogeDao.getAdvocateFor(address(joe));
        assertEq(advocateFor.length, 1);
        assertEq(advocateFor[0], gogeDao.pollNum());

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], gogeDao.pollNum());
    }

    /// @notice Verify correct state changes and logic for addVote using fuzzing
    function test_mainDeployment_dao_addVote_fuzzing(uint256 joe_votes) public {
        create_mock_poll();

        joe_votes = bound(joe_votes, 1, 50_000_000_000 ether);
        uint256 _preBal = gogeToken_v2.balanceOf(address(joe));

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken_v2.transfer(address(joe), joe_votes);
        assertEq(gogeToken_v2.balanceOf(address(joe)), joe_votes + _preBal);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken_v2), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Verify tokens were sent from Joe to Dao
        assertEq(gogeToken_v2.balanceOf(address(joe)), _preBal);
        assertEq(gogeToken_v2.balanceOf(address(gogeDao)), joe_votes + gogeDao.minAuthorBal());

        // Post-state check.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.pollVotes(1), joe_votes + gogeDao.minAuthorBal());
    }

    /// @notice Verify the execution of a poll when a poll reaches the quorum
    function test_mainDeployment_dao_addVote_quorum() public {
        create_mock_poll();
        uint256 joe_votes = 50_000_000_000 ether;
        uint256 _preBal = gogeToken_v2.balanceOf(address(joe));
        gogeDao.setGatekeeping(false);
        gogeDao.updateQuorum(30);

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);

        // Transfer Joe tokens so he can vote on a poll.
        gogeToken_v2.transfer(address(joe), joe_votes);
        assertEq(gogeToken_v2.balanceOf(address(joe)), joe_votes + _preBal);

        // Approve the transfer of tokens and add vote.
        assert(joe.try_approveToken(address(gogeToken_v2), address(gogeDao), joe_votes));
        assert(joe.try_addVote(address(gogeDao), 1, joe_votes));

        // Verify tokens Joe is holding the token balance since poll was passed.
        assertEq(gogeToken_v2.balanceOf(address(joe)), joe_votes + _preBal);
        assertEq(gogeToken_v2.balanceOf(address(gogeDao)), 0);

        // Post-state check => gogeDao.
        assertEq(gogeDao.polls(1, address(joe)), joe_votes);
        assertEq(gogeDao.pollVotes(1), joe_votes + gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        // Verify quorum math.
        uint256 num = gogeDao.getProportion(1);
        assertTrue(num >= gogeDao.quorum());
    }

    /// NOTE: Proposals

    /// @notice initiates a taxChange poll and verifies correct state change when poll is passed.
    function test_mainDeployment_dao_proposal_taxChange() public {

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
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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

        // Pre-state check.
        assertEq(gogeToken_v2.cakeDividendRewardsFee(), 10);
        assertEq(gogeToken_v2.marketingFee(), 2);
        assertEq(gogeToken_v2.buyBackFee(), 2);
        assertEq(gogeToken_v2.teamFee(), 2);
        assertEq(gogeToken_v2.totalFees(), 16);
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check => gogeDao.
        assertEq(gogeDao.pollVotes(1), gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);

        // Post-state check => gogeToken_v2.
        assertEq(gogeToken_v2.cakeDividendRewardsFee(), 8);
        assertEq(gogeToken_v2.marketingFee(), 3);
        assertEq(gogeToken_v2.buyBackFee(), 4);
        assertEq(gogeToken_v2.teamFee(), 5);
        assertEq(gogeToken_v2.totalFees(), 20);        
    }

    /// @notice initiates a funding poll and verifies correct state change when poll is passed.
    function test_mainDeployment_dao_proposal_funding() public {
        gogeDao.setGatekeeping(false);
        gogeDao.updateQuorum(30);

        payable(address(gogeDao)).transfer(1_000 ether);

        vm.prank(address(gogeToken_v2));
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
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
    function test_mainDeployment_dao_proposal_setGogeDao() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose setGogeDao";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(222);

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setGogeDao, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setGogeDao);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose setGogeDao");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(222));

        // NOTE pass poll

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeToken_v2.gogeDao(), address(gogeDao));

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check => gogeDao.
        assertEq(gogeDao.pollVotes(1), gogeDao.minAuthorBal());
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);
        assertEq(gogeToken_v2.gogeDao(), address(222));       
    }

    /// @notice initiates a setCex poll and verifies correct state change when poll is passed.
    function test_mainDeployment_dao_proposal_setCex() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose setCex";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(222);

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.setCex, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.setCex);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose setCex");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).addr1, address(222));

        // NOTE pass poll

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeToken_v2.isExcludedFromFees(address(222)), false);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check => gogeDao.
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);
        assertEq(gogeToken_v2.isExcludedFromFees(address(222)), true);      
    }

    /// @notice initiates a setDex poll and verifies correct state change when poll is passed.
    function test_mainDeployment_dao_proposal_setDex() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose setDex";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(222);
        proposal.boolVar = true;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeToken_v2.automatedMarketMakerPairs(address(222)), false);

        // Pass poll
        gogeDao.passPoll(1);

        // Post-state check => gogeDao.
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);
        assertEq(gogeToken_v2.automatedMarketMakerPairs(address(222)), true);        
    }

    /// @notice initiates a excludeFromCirculatingSupply poll and verifies correct state change when poll is passed.
    function test_mainDeployment_dao_proposal_excludeFromCirculatingSupply() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose excludeFromCirculatingSupply";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(222);
        proposal.boolVar = true;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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

        // Pre-state check.
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        (bool excludedPre,) = gogeToken_v2.isExcludedFromCirculatingSupply(address(222));
        assertEq(excludedPre, false);

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check => gogeDao.
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp);
        (bool excludedPost,) = gogeToken_v2.isExcludedFromCirculatingSupply(address(222));
        assertEq(excludedPost, true);
    }

    /// @notice Verifies correct state changes when a poll of pollType updateDividendToken is created and executed.
    function test_mainDeployment_dao_proposal_updateDividendToken() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the dividend token to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = BUNY;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
        assertEq(gogeToken_v2.cakeDividendToken(), CAKE);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken_v2.cakeDividendToken(), BUNY);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType updateMarketingWallet is created and executed.
    function test_mainDeployment_dao_proposal_updateMarketingWallet() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the marketing wallet to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(this);

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
        assertEq(gogeToken_v2.marketingWallet(), 0xFecf1D51E984856F11B7D0872D40fC2F05377738);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken_v2.marketingWallet(), address(this));

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType updateTeamWallet is created and executed.
    function test_mainDeployment_dao_proposal_updateTeamWallet() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the team wallet to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(this);

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
        assertEq(gogeToken_v2.teamWallet(), 0xC1Aa023A8fA820F4ed077f4dF4eBeD0a3351a324);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken_v2.teamWallet(), address(this));

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType updateTeamMember is created and executed.
    function test_mainDeployment_dao_proposal_updateTeamMember() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we add an address as a team member";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(sal);
        proposal.boolVar = true;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
    function test_mainDeployment_dao_proposal_updateGatekeeper() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we add an address as a gate keeper";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(sal);
        proposal.boolVar = true;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
    function test_mainDeployment_dao_proposal_setGatekeeping() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we enable gate keeping";
        proposal.endTime = block.timestamp + 2 days;
        proposal.boolVar = false;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
    function test_mainDeployment_dao_proposal_setBuyBackEnabled() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we disable buy back fees";
        proposal.endTime = block.timestamp + 2 days;
        proposal.boolVar = false;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
        assertEq(gogeToken_v2.buyBackEnabled(), true);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken_v2.buyBackEnabled(), false);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType setCakeDividendEnabled is created and executed.
    function test_mainDeployment_dao_proposal_setCakeDividendEnabled() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we disable cake dividends";
        proposal.endTime = block.timestamp + 2 days;
        proposal.boolVar = false;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
        assertEq(gogeToken_v2.cakeDividendEnabled(), true);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken_v2.cakeDividendEnabled(), false);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType setMarketingEnabled is created and executed.
    function test_mainDeployment_dao_proposal_setMarketingEnabled() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we disable marketing fees";
        proposal.endTime = block.timestamp + 2 days;
        proposal.boolVar = false;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
        assertEq(gogeToken_v2.marketingEnabled(), true);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken_v2.marketingEnabled(), false);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType setTeamEnabled is created and executed.
    function test_mainDeployment_dao_proposal_setTeamEnabled() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we disable team fees";
        proposal.endTime = block.timestamp + 2 days;
        proposal.boolVar = false;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
        assertEq(gogeToken_v2.teamEnabled(), true);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken_v2.teamEnabled(), false);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType excludeFromFees is created and executed.
    function test_mainDeployment_dao_proposal_excludeFromFees() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we exclude this address from fees";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(sal);
        proposal.boolVar = true;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
        assertEq(gogeToken_v2.isExcludedFromFees(address(sal)), false);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken_v2.isExcludedFromFees(address(sal)), true);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType modifyBlacklist is created and executed.
    function test_mainDeployment_dao_proposal_modifyBlacklist() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we blacklist this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(sal);
        proposal.boolVar = true;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
        assertEq(gogeToken_v2.isBlacklisted(address(sal)), false);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken_v2.isBlacklisted(address(sal)), true);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType transferOwnership is created and executed.
    function test_mainDeployment_dao_proposal_transferOwnership() public {
        gogeToken_v2.transferOwnership(address(gogeDao));

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we transfer ownership to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(sal);

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
        assertEq(gogeToken_v2.owner(), address(gogeDao));

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeToken_v2.owner(), address(sal));

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType setQuorum is created and executed.
    function test_mainDeployment_dao_proposal_setQuorum() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we transfer ownership to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.amount = 30;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
    function test_mainDeployment_dao_proposal_updateGovernanceToken() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the governance token to this address";
        proposal.endTime = block.timestamp + 2 days;
        proposal.addr1 = address(this);

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
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
        assertEq(gogeDao.governanceToken(), address(gogeToken_v2));

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

    /// @notice Verifies correct state changes when a poll of pollType updateMaxPeriod is created and executed.
    function test_mainDeployment_dao_proposal_updateMaxPeriod() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the max poll period to 90 days";
        proposal.endTime = block.timestamp + 2 days;
        proposal.amount = 90;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateMaxPeriod, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateMaxPeriod);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we update the max poll period to 90 days");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).amount, 90);

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.maxPeriod(), 60 days);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.maxPeriod(), 90 days);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }

    /// @notice Verifies correct state changes when a poll of pollType updateMinAuthorBal is created and executed.
    function test_mainDeployment_dao_proposal_updateMinAuthorBal() public {

        // NOTE create poll

        // create poll proposal
        GogeDAO.Proposal memory proposal;
        proposal.description = "I want to propose we update the minimum author balance to 420M tokens";
        proposal.endTime = block.timestamp + 2 days;
        proposal.amount = 420_000_000;

        // create poll
        gogeToken_v2.approve(address(gogeDao), gogeDao.minAuthorBal());
        gogeDao.createPoll(GogeDAO.PollType.updateMinAuthorBal, proposal);

        // Verify state change
        assertEq(gogeDao.pollNum(), 1);
        assert(gogeDao.pollTypes(1) == GogeDAO.PollType.updateMinAuthorBal);

        // Verify poll proposal
        assertEq(gogeDao.getProposal(1).description, "I want to propose we update the minimum author balance to 420M tokens");
        assertEq(gogeDao.getProposal(1).endTime, block.timestamp + 2 days);
        assertEq(gogeDao.getProposal(1).amount, 420_000_000);

        // Pre-state check
        assertEq(gogeDao.passed(1), false);
        assertEq(gogeDao.minAuthorBal(), 10_000_000 ether);

        uint256[] memory activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 1);
        assertEq(activePolls[0], 1);

        // NOTE pass poll

        // pass poll
        gogeDao.passPoll(1);

        // Post-state check
        assertEq(gogeDao.passed(1), true);
        assertEq(gogeDao.minAuthorBal(), 420_000_000 ether);

        activePolls = gogeDao.getActivePolls();
        assertEq(activePolls.length, 0);
    }
}
