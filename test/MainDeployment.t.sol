// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import "../src/GogeToken.sol";

contract MainDeployment is Utility, Test {
    DogeGaySon gogeToken;

    function setUp() public {
        createActors();
        setUpTokens();

        address UNIV2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E; //bsc
        //address UNIV2_PAIR = 0xf1d107ac566473968fC5A90c9EbEFe42eA3248a4;
        
        // (1) Deploy Token
        gogeToken = new DogeGaySon(
            address(1),
            address(2),
            100_000_000_000
        );

        // Give tokens and ownership to dev.
        gogeToken.transfer(address(dev), 100_000_000_000 ether);
        gogeToken._transferOwnership(address(dev));

        // enable trading.
        assert(dev.try_enableTrading(address(gogeToken)));

        uint ETH_DEPOSIT = 100 ether;
        uint TOKEN_DEPOSIT = 5000000000 ether;

        // (11) Approve TaxToken for UniswapV2Router.
        IERC20(address(gogeToken)).approve(
            address(UNIV2_ROUTER), TOKEN_DEPOSIT
        );

        // (12) Instantiate liquidity pool.
        // https://docs.uniswap.org/protocol/V2/reference/smart-contracts/router-02#addliquidityeth
        // NOTE: ETH_DEPOSIT = The amount of ETH to add as liquidity if the token/WETH price is <= amountTokenDesired/msg.value (WETH depreciates).
        IUniswapV2Router01(UNIV2_ROUTER).addLiquidityETH{value: ETH_DEPOSIT}(
            address(gogeToken),         // A pool token.
            TOKEN_DEPOSIT,              // The amount of token to add as liquidity if the WETH/token price is <= msg.value/amountTokenDesired (token depreciates).
            5000000000 ether,           // Bounds the extent to which the WETH/token price can go up before the transaction reverts. Must be <= amountTokenDesired.
            100 ether,                  // Bounds the extent to which the token/WETH price can go up before the transaction reverts. Must be <= msg.value.
            address(this),              // Recipient of the liquidity tokens.
            block.timestamp + 300       // Unix timestamp after which the transaction will revert.
        );
    }

    // Initial state test.
    function test_deployment_init_state() public {
        assertEq(gogeToken.marketingWallet(), address(1));
        assertEq(gogeToken.teamWallet(),      address(2));
        assertEq(gogeToken.totalSupply(),     100_000_000_000 ether);
        assertEq(gogeToken.balanceOf(address(dev)), 100_000_000_000 ether);

        assertTrue(gogeToken.tradingIsEnabled());
    }

    
}
