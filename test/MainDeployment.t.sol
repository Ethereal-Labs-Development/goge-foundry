// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import { Utility } from "./Utility.sol";
import { Actor } from "../src/users/Actor.sol";

import { IUniswapV2Router02, IUniswapV2Pair, IUniswapV2Router01, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";
import { IGogeERC20 } from "../src/extensions/IGogeERC20.sol";

import { DogeGaySon, CakeDividendTracker } from "../src/GogeToken.sol";
import { DogeGaySonFlat } from "src/DeployedV2Token.sol";

import { DogeGaySon1 } from "../src/TokenV1.sol";
import { GogeDAO } from "../src/GogeDao.sol";

contract MainDeploymentTesting is Utility {
    DogeGaySon1 gogeToken_v1;
    DogeGaySonFlat gogeToken_v2;

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

        // TODO: (2) SetDao on Token contract

        // TODO: (3) exclude any locks from circulating supply

        // TODO: (4) enable createPoll

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

    // ~~ Unit Tests ~~

    /// @notice Initial state test.
    function test_mainDeployment_init_state() public {
        assertEq(gogeToken_v2.tradingIsEnabled(), true);
        assertEq(gogeToken_v2.migrationCounter(), 5);
    }

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

    // Verify correct royalties post dev fee (60 days).
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

    function test_mainDeployment_dao_updateTeamBalance() public {
        // TODO
    }

    function test_mainDeployment_dao_updateMarketingBalance() public {
        // TODO
    }
}
