// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import "../src/GogeToken.sol";

import { IUniswapV2Router02, IUniswapV2Router01, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";

contract Royalties is Utility, Test {
    DogeGaySon gogeToken;

    address UNIV2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E; //bsc

    function setUp() public {
        createActors();
        setUpTokens();
        
        // Deploy Token
        gogeToken = new DogeGaySon(
            address(0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B), //0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B
            address(0xe142E9FCbd9E29C4A65C4979348d76147190a05a),
            100_000_000_000
        );

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
    //       can only distribute on sells
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

    function test_royaltyTesting_generateFees_fuzzing(uint256 amountBuy, uint256 amountSell) public {
        amountBuy = bound(amountBuy, 1, 30 ether);
        amountSell = bound(amountSell, 1 ether, 100_000_000 ether);
        // Remove address(this) from whitelist so we can yield a buy tax.
        gogeToken.excludeFromFees(address(this), false);

        // Check balance of address(gogeToken) to see how many tokens have been taxed. Should be 0
        assertEq(IERC20(address(gogeToken)).balanceOf(address(gogeToken)), 0);

        // Generate a buy - log amount of tokens accrued
        buy_generateFees(amountBuy);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken))); // 7_901_185

        buy_generateFees(amountBuy * 2);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken))); // 23_244_038

        //gogeToken.setCakeDividendEnabled(false);
        //gogeToken.setBuyBackEnabled(false);

        sell_generateFees(amountSell);
        emit log_uint(IERC20(address(gogeToken)).balanceOf(address(gogeToken))); // 3_411
    }

}
