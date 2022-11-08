// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";

import { IUniswapV2Router02, IUniswapV2Pair, IUniswapV2Router01, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";

import { DogeGaySon } from "../src/GogeToken.sol";
import { DogeGaySon1 } from "../src/TokenV1.sol";

contract MigrationTesting is Utility, Test {

    DogeGaySon  gogeToken_v2;
    DogeGaySon1 gogeToken_v1;

    address UNIV2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E; //bsc

    function setUp() public {
        createActors();
        setUpTokens();
        
        // Deploy v1
        gogeToken_v1 = new DogeGaySon1();

        uint BNB_DEPOSIT = 300 ether;
        uint TOKEN_DEPOSIT = 22_345_616_917 ether;

        IWETH(WBNB).deposit{value: BNB_DEPOSIT}();

        // Approve TaxToken for UniswapV2Router.
        IERC20(address(gogeToken_v1)).approve(
            address(UNIV2_ROUTER), TOKEN_DEPOSIT
        );

        // Create liquidity pool.
        // https://docs.uniswap.org/protocol/V2/reference/smart-contracts/router-02#addliquidityeth
        // NOTE: ETH_DEPOSIT = The amount of ETH to add as liquidity if the token/WETH price is <= amountTokenDesired/msg.value (WETH depreciates).
        IUniswapV2Router01(UNIV2_ROUTER).addLiquidityETH{value: 220 ether}(
            address(gogeToken_v1),      // A pool token.
            TOKEN_DEPOSIT,              // The amount of token to add as liquidity if the WETH/token price is <= msg.value/amountTokenDesired (token depreciates).
            TOKEN_DEPOSIT,              // Bounds the extent to which the WETH/token price can go up before the transaction reverts. Must be <= amountTokenDesired.
            220 ether,                  // Bounds the extent to which the token/WETH price can go up before the transaction reverts. Must be <= msg.value.
            address(this),              // Recipient of the liquidity tokens.
            block.timestamp + 300       // Unix timestamp after which the transaction will revert.
        );

        // enable trading for v1
        gogeToken_v1.afterPreSale();
        gogeToken_v1.setTradingIsEnabled(true, 0);

        // Deploy v2
        gogeToken_v2 = new DogeGaySon(
            address(0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B), //0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B
            address(0xe142E9FCbd9E29C4A65C4979348d76147190a05a),
            100_000_000_000,
            address(gogeToken_v1)
        );
    }

    // Initial state test.
    function test_migration_init_state() public {
        assertEq(gogeToken_v1.marketingWallet(), address(0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B));
        assertEq(gogeToken_v1.teamWallet(),      address(0xe142E9FCbd9E29C4A65C4979348d76147190a05a));
        assertEq(gogeToken_v1.totalSupply(),     100_000_000_000 ether);
        assertEq(gogeToken_v1.balanceOf(address(this)), gogeToken_v1.totalSupply() - gogeToken_v1.balanceOf(gogeToken_v1.uniswapV2Pair()));
        assertTrue(gogeToken_v1.tradingIsEnabled());
    }

    function test_migration_tryMigrate() public {
        // Warp in time
        vm.warp(block.timestamp + 30 days);

        // Transfer tokens to Joe so he can migrate.
        gogeToken_v1.transfer(address(joe), 10_000_000 ether);
        
        // Verify 10M v1 and 0 v2 tokens.
        assertEq(gogeToken_v1.balanceOf(address(joe)), 10_000_000 ether);
        assertEq(gogeToken_v2.balanceOf(address(joe)), 0);

        // get LP reserves -> token amount and bnb balance of v1 and v2 LPs
        (uint112 v1_reserveTokens, uint112 v1_reserveBnb,) = IUniswapV2Pair(gogeToken_v1.uniswapV2Pair()).getReserves();
        (uint112 v2_reserveTokens, uint112 v2_reserveBnb,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves();

        emit log_named_uint("v1 LP GOGE balance", v1_reserveTokens);
        emit log_named_uint("v1 LP BNB balance",  v1_reserveBnb);
        emit log_named_uint("v2 LP GOGE balance", v2_reserveTokens);
        emit log_named_uint("v2 LP BNB balance",  v2_reserveBnb);

        // Retreive and emit price of 1 v1 token. Should be close to $0.000003307050665171378
        address[] memory path = new address[](3);
        path[0] = address(gogeToken_v1);
        path[1] = WBNB;
        path[2] = BUSD;

        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut( 1 ether, path );

        emit log_named_uint("cost of 1 v1 token", amounts[2]); // 0.000003252687202432

        // Disable trading on v1
        gogeToken_v1.setTradingIsEnabled(false, 0);
        assert(!joe.try_transferToken(address(gogeToken_v1), address(69), 10 ether));

        // Whitelist v2 token.
        gogeToken_v1.excludeFromFees(address(gogeToken_v2), true);

        // Approve and migrate
        assert(joe.try_approveToken(address(gogeToken_v1), address(gogeToken_v2), gogeToken_v1.balanceOf(address(joe))));
        assert(joe.try_migrate(address(gogeToken_v2)));

        // Verify 0 v1 and 10M v2 tokens.
        assertEq(gogeToken_v1.balanceOf(address(joe)), 0);
        assertEq(gogeToken_v2.balanceOf(address(joe)), 10_000_000 ether);

        // get LP reserves -> token amount and bnb balance of v1 and v2 LPs
        (v1_reserveTokens, v1_reserveBnb,) = IUniswapV2Pair(gogeToken_v1.uniswapV2Pair()).getReserves();
        (v2_reserveTokens, v2_reserveBnb,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves();

        emit log_named_uint("v1 LP GOGE balance", v1_reserveTokens);
        emit log_named_uint("v1 LP BNB balance",  v1_reserveBnb);
        emit log_named_uint("v2 LP GOGE balance", v2_reserveTokens);
        emit log_named_uint("v2 LP BNB balance",  v2_reserveBnb);

        assertTrue(!gogeToken_v2.tradingIsEnabled());
    }

}
