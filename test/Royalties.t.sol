// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import "../src/GogeToken.sol";

import { IUniswapV2Router02, IUniswapV2Router01, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";

contract Royalties is Utility, Test {
    DogeGaySon gogeToken;
    CakeDividendTracker cakeTracker;

    address UNIV2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E; //bsc

    event log_bool(bool a);

    function setUp() public {
        createActors();
        setUpTokens();
        
        // Deploy Token
        gogeToken = new DogeGaySon(
            address(0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B), //0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B
            address(0xe142E9FCbd9E29C4A65C4979348d76147190a05a),
            100_000_000_000
        );

        cakeTracker = gogeToken.cakeDividendTracker();

        // Give tokens and ownership to dev.
        //gogeToken.transfer(address(dev), 100_000_000_000 ether);
        //gogeToken._transferOwnership(address(dev));

        uint BNB_DEPOSIT = 200 ether;
        uint TOKEN_DEPOSIT = 5000000000 ether;

        IWETH(WBNB).deposit{value: BNB_DEPOSIT}();

        // Approve TaxToken for UniswapV2Router.
        IERC20(address(gogeToken)).approve(
            address(UNIV2_ROUTER), TOKEN_DEPOSIT
        );

        // Create liquidity pool.
        // https://docs.uniswap.org/protocol/V2/reference/smart-contracts/router-02#addliquidityeth
        // NOTE: ETH_DEPOSIT = The amount of ETH to add as liquidity if the token/WETH price is <= amountTokenDesired/msg.value (WETH depreciates).
        IUniswapV2Router01(UNIV2_ROUTER).addLiquidityETH{value: 100 ether}(
            address(gogeToken),         // A pool token.
            TOKEN_DEPOSIT,              // The amount of token to add as liquidity if the WETH/token price is <= msg.value/amountTokenDesired (token depreciates).
            5_000_000_000 ether,        // Bounds the extent to which the WETH/token price can go up before the transaction reverts. Must be <= amountTokenDesired.
            100 ether,                  // Bounds the extent to which the token/WETH price can go up before the transaction reverts. Must be <= msg.value.
            address(this),              // Recipient of the liquidity tokens.
            block.timestamp + 300       // Unix timestamp after which the transaction will revert.
        );

        // enable trading.
        //assert(dev.try_enableTrading(address(gogeToken)));
        gogeToken.enableTrading();
    }

    // Initial state test.
    function test_royaltyTesting_init_state() public {
        assertEq(gogeToken.marketingWallet(), address(0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B));
        assertEq(gogeToken.teamWallet(),      address(0xe142E9FCbd9E29C4A65C4979348d76147190a05a));
        assertEq(gogeToken.totalSupply(),     100_000_000_000 ether);
        assertEq(gogeToken.balanceOf(address(this)), 95_000_000_000 ether);
        assertEq(gogeToken.marketingFee(), 2);
        assertEq(gogeToken.teamFee(), 2);
        assertEq(gogeToken.buyBackFee(), 2);

        assertTrue(gogeToken.tradingIsEnabled());
    }


    // ~~ Utility ~~

    // Perform a buy to generate fees
    function buy_generateFees(uint256 tradeAmt) public {

        IERC20(WBNB).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path = new address[](2);

        path[0] = WBNB;
        path[1] = address(gogeToken);

        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path,
            msg.sender,
            block.timestamp + 300
        );
    }

    // Perform a buy to generate fees
    function sell_generateFees(uint256 tradeAmt) public {

        IERC20(address(gogeToken)).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path = new address[](2);

        path[0] = address(gogeToken);
        path[1] = WBNB;

        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path,
            msg.sender,
            block.timestamp + 300
        );
    }


    // ~~ Unit Tests ~~

    // NOTE: swapTokensAtAmount distribution threshold = 20_000_000
    //       bnb = $290.11
    function test_royaltyTesting_generateFees() public {
        // Remove address(this) from whitelist so we can yield a buy tax.
        gogeToken.excludeFromFees(address(this), false);

        // Check balance of address(gogeToken) to see how many tokens have been taxed. Should be 0
        assertEq(IERC20(address(gogeToken)).balanceOf(address(gogeToken)), 0);

        // Generate a buy - log amount of tokens accrued
        buy_generateFees(1 ether);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken))); // 7_901_185

        buy_generateFees(2 ether);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken))); // 23_244_038

        sell_generateFees(10_000 ether);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken))); // 3_411
    }

    // NOTE: Error in this test.
    // FAILED CASES: [8492018911496110081, 88308617632452571546217600], [8227232056021843363, 1000000000000000000]
    // NOTE: passing when setting params.buyBackOrLiquidity < 50.
    function test_royaltyTesting_generateFees_specify() public {
        uint256 _amountToBuy  = 8492018911496110081;
        uint256 _amountToSell = 88308617632452571546217600;

        // Remove address(this) from whitelist so we can yield a buy tax.
        gogeToken.excludeFromFees(address(this), false);

        // Check balance of address(gogeToken) to see how many tokens have been taxed. Should be 0
        assertEq(IERC20(address(gogeToken)).balanceOf(address(gogeToken)), 0);

        // Generate a buy - log amount of tokens accrued
        buy_generateFees(_amountToBuy);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken)));

        buy_generateFees(_amountToBuy * 2);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken)));

        //gogeToken.setBuyBackEnabled(false); <-- ERROR HAPPENING HERE

        sell_generateFees(_amountToSell);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken)));
    }

    function test_royaltyTesting_generateFees_fuzzing(uint256 amountBuy, uint256 amountSell) public {
        amountBuy = bound(amountBuy, 1, 40 ether);                            // range of ( .000000000000000001 -> 80 BNB buys )
        amountSell = bound(amountSell, 1 * (10**17), 500_000_000 ether);      // range of ( .1 -> 500,000,000 tokens )

        // Remove address(this) from whitelist so we can yield a buy tax.
        gogeToken.excludeFromFees(address(this), false);

        // Check balance of address(gogeToken) to see how many tokens have been taxed. Should be 0
        assertEq(IERC20(address(gogeToken)).balanceOf(address(gogeToken)), 0);

        // Generate a buy - log amount of tokens accrued
        buy_generateFees(amountBuy);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken)));

        buy_generateFees(amountBuy * 2);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken)));

        //gogeToken.setCakeDividendEnabled(false);
        //gogeToken.setBuyBackEnabled(false);

        sell_generateFees(amountSell);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken)));
    }

    function test_royaltyTesting_generateFees_cake() public {
        // Verify Joe owns 0 tokens and 0 CAKE.
        assertEq(gogeToken.balanceOf(address(joe)), 0);
        assertEq(IERC20(CAKE).balanceOf(address(joe)), 0);
        assertEq(IERC20(CAKE).balanceOf(address(gogeToken)), 0);

        // transfer Joe 5M tokens.
        gogeToken.transfer(address(joe), 5_000_000 ether);

        // remove deployer contract from whitelist.
        gogeToken.excludeFromFees(address(this), false);

        // Verify Joe owns 5M tokens and 0 CAKE.
        assertEq(gogeToken.balanceOf(address(joe)), 5_000_000 ether);
        assertEq(IERC20(CAKE).balanceOf(address(joe)), 0);

        //Generate transactions to trigger dividend payout.
        buy_generateFees(4 ether);
        buy_generateFees(6 ether);
        sell_generateFees(1_000_000 ether);
        buy_generateFees(4 ether);
        buy_generateFees(6 ether);
        sell_generateFees(1_000_000 ether);

        // Verify Joe owns 5M tokens and more than 0 CAKE.
        assertEq(gogeToken.balanceOf(address(joe)), 5_000_000 ether);
        assertGt(IERC20(CAKE).balanceOf(address(joe)), 0);

        emit log_uint(cakeTracker.withdrawableDividendOf(address(joe)));       // <-- withdrawable divividends not paid out
        emit log_uint(cakeTracker.accumulativeDividendOf(address(joe)));       // <-- all dividends paid in total
        emit log_int (cakeTracker.magnifiedDividendCorrections(address(joe))); // <-- dont know
        emit log_bool(cakeTracker.excludedFromDividends(address(joe)));        // <-- should return false
        emit log_uint(cakeTracker.lastClaimTimes(address(joe)));               // <-- timestamp of last claim

        emit log_uint(cakeTracker.getMapValue(address(joe)));      // <-- balanceOf address stored in map
        emit log_uint(cakeTracker.getMapLength());                 // <-- should return 2 (only 2 holders atm)

        //emit log_uint(block.timestamp);
        //emit log_address(address(joe));
    }

    function test_royaltyTesting_fees() public {
        uint256 amountToSend = 1_000_000 ether;

        assertEq(gogeToken.balanceOf(address(joe)), 0);

        gogeToken.excludeFromFees(address(this), false);
        gogeToken.transfer(address(joe), amountToSend);

        assertEq(gogeToken.balanceOf(address(joe)), amountToSend - (amountToSend * 16/100)); // Tx is taxed 16%
    }

    function test_royaltyTesting_feeDistributions() public {
        // Royalty Recipients
        address marketingAddy = 0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B;
        address teamAddy      = 0xe142E9FCbd9E29C4A65C4979348d76147190a05a;
        address devAddy       = 0xa13bBda8bE05462232D7Fc4B0aF8f9B57fFf5D02;
        address deadAddy      = 0x000000000000000000000000000000000000dEaD;

        // Get pre balances of royalty recipients
        uint256 preBalMarketing = marketingAddy.balance;
        uint256 preBalTeam      = teamAddy.balance;
        uint256 preBalDev       = devAddy.balance;
        uint256 preBalDead      = gogeToken.balanceOf(deadAddy);

        // Remove address(this) from whitelist so we can yield a buy tax.
        gogeToken.excludeFromFees(address(this), false);

        // Check balance of address(gogeToken) to see how many tokens have been taxed. Should be 0
        assertEq(IERC20(address(gogeToken)).balanceOf(address(gogeToken)), 0);

        // Generate buy -> log amount of tokens accrued
        buy_generateFees(10 ether);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken))); // 72561945.896794726074107751
        emit log_uint(address(gogeToken).balance); // 0

        // Generate sell -> Distribute fees
        sell_generateFees(1_000 ether);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken))); // 1600.00000000000000000
        emit log_uint(address(gogeToken).balance); // 0

        // take post balanaces
        uint256 postBalMarketing = marketingAddy.balance;
        uint256 postBalTeam      = teamAddy.balance;
        uint256 postBalDev       = devAddy.balance;
        uint256 postBalDead      = gogeToken.balanceOf(deadAddy);

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
        assertEq(marketingReceived, gogeToken.royaltiesSent(1));
        assertEq(teamReceived,      gogeToken.royaltiesSent(3));
        assertEq(devReceived,       gogeToken.royaltiesSent(2));

        // log amount
        emit log_uint(gogeToken.royaltiesSent(1)); // marketing
        emit log_uint(gogeToken.royaltiesSent(2)); // dev
        emit log_uint(gogeToken.royaltiesSent(3)); // team
        emit log_uint(gogeToken.royaltiesSent(4)); // buyBack
        emit log_uint(gogeToken.royaltiesSent(5)); // cake

    }

    function test_royaltyTesting_feeDistributions_noDev() public {
        // Royalty Recipients
        address marketingAddy = 0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B;
        address teamAddy      = 0xe142E9FCbd9E29C4A65C4979348d76147190a05a;
        address devAddy       = 0xa13bBda8bE05462232D7Fc4B0aF8f9B57fFf5D02;
        address deadAddy      = 0x000000000000000000000000000000000000dEaD;

        // Get pre balances of royalty recipients
        uint256 preBalMarketing = marketingAddy.balance;
        uint256 preBalTeam      = teamAddy.balance;
        uint256 preBalDev       = devAddy.balance;
        uint256 preBalDead      = gogeToken.balanceOf(deadAddy);

        // Remove address(this) from whitelist so we can yield a buy tax.
        gogeToken.excludeFromFees(address(this), false);
        vm.warp(block.timestamp + 61 days);

        // Check balance of address(gogeToken) to see how many tokens have been taxed. Should be 0
        assertEq(IERC20(address(gogeToken)).balanceOf(address(gogeToken)), 0);

        // Generate buy -> log amount of tokens accrued
        buy_generateFees(10 ether);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken))); // 72561945.896794726074107751
        emit log_uint(address(gogeToken).balance); // 0

        // Generate sell -> Distribute fees
        sell_generateFees(1_000 ether);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken))); // 1600.00000000000000000
        emit log_uint(address(gogeToken).balance); // 0

        // take post balanaces
        uint256 postBalMarketing = marketingAddy.balance;
        uint256 postBalTeam      = teamAddy.balance;
        uint256 postBalDev       = devAddy.balance;
        uint256 postBalDead      = gogeToken.balanceOf(deadAddy);

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
        assertEq(marketingReceived, gogeToken.royaltiesSent(1));
        assertEq(teamReceived,      gogeToken.royaltiesSent(3));
        assertEq(devReceived,       gogeToken.royaltiesSent(2));
        assertEq(devReceived,       0);

        // log amount
        emit log_uint(gogeToken.royaltiesSent(1)); // marketing
        emit log_uint(gogeToken.royaltiesSent(2)); // dev
        emit log_uint(gogeToken.royaltiesSent(3)); // team
        emit log_uint(gogeToken.royaltiesSent(4)); // buyBack
        emit log_uint(gogeToken.royaltiesSent(5)); // cake

    }

}
