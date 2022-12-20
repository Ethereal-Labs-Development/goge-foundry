// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";

import { IUniswapV2Router02, IUniswapV2Pair, IUniswapV2Router01, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";
import { IGogeERC20 } from "../src/extensions/IGogeERC20.sol";

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
        assertTrue(!gogeToken_v2.tradingIsEnabled());
    }


    // ~~ Utility Functions ~~

    /// @notice Returns the price of 1 token in USD
    function getPrice(address token) internal returns (uint256) {

        address[] memory path = new address[](3);

        path[0] = token;
        path[1] = WBNB;
        path[2] = BUSD;

        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(
            1 ether,
            path
        );

        return amounts[2];
    }


    // ~~ Unit Tests ~~

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
        uint256 price = getPrice(address(gogeToken_v1));
        emit log_named_uint("cost of 1 v1 token", price); // 0.000003252687202432

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

    // TODO:
    //    - Look into addLiquidity
    //    - test ratio
    //    - create small LP to create same v1 price and start migration

    function test_migration_ratio() public {

        // -------------------- PRE STATE -------------------

        // Warp in time
        vm.warp(block.timestamp + 30 days);

        //Initialize wallet amounts.
        uint256 amountJoe = 1_056_322_590 ether;
        uint256 amountSal = 610_217_752 ether;
        uint256 amountNik = 17_261_463 ether;
        uint256 amountJon = 3_984_357 ether;
        uint256 amountTim = 314_535 ether - 1;

        // Transfer tokens to Joe so he can migrate.
        gogeToken_v1.transfer(address(joe), amountJoe); // 1,056,322,590
        gogeToken_v1.transfer(address(sal), amountSal); // 610,217,752
        gogeToken_v1.transfer(address(nik), amountNik); // 17,261,463
        gogeToken_v1.transfer(address(jon), amountJon); // 3,984,357
        gogeToken_v1.transfer(address(tim), amountTim); // 2,375,388
        
        // Verify amount v1 and 0 v2 tokens.
        assertEq(gogeToken_v1.balanceOf(address(joe)), amountJoe);
        assertEq(gogeToken_v2.balanceOf(address(joe)), 0);

        assertEq(gogeToken_v1.balanceOf(address(sal)), amountSal);
        assertEq(gogeToken_v2.balanceOf(address(sal)), 0);

        assertEq(gogeToken_v1.balanceOf(address(nik)), amountNik);
        assertEq(gogeToken_v2.balanceOf(address(nik)), 0);

        assertEq(gogeToken_v1.balanceOf(address(jon)), amountJon);
        assertEq(gogeToken_v2.balanceOf(address(jon)), 0);

        assertEq(gogeToken_v1.balanceOf(address(tim)), amountTim);
        assertEq(gogeToken_v2.balanceOf(address(tim)), 0);

        // get LP reserves -> token amount and bnb balance of v1 and v2 LPs
        (uint112 v1_reserveTokens, uint112 v1_reserveBnb,) = IUniswapV2Pair(gogeToken_v1.uniswapV2Pair()).getReserves();
        (uint112 v2_reserveTokens, uint112 v2_reserveBnb,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves();

        emit log_named_uint("v1 LP GOGE balance", v1_reserveTokens);
        emit log_named_uint("v1 LP BNB balance",  v1_reserveBnb);
        emit log_named_uint("v2 LP GOGE balance", v2_reserveTokens);
        emit log_named_uint("v2 LP BNB balance",  v2_reserveBnb);

        // Verify reserves of v1 LP
        assertEq(v1_reserveTokens, 22_345_616_917 ether);
        assertEq(v1_reserveBnb,    220 ether);

        // Verify reserves of v2 LP
        assertEq(v2_reserveTokens, 0);
        assertEq(v2_reserveBnb,    0);

        // Disable trading on v1
        gogeToken_v1.setTradingIsEnabled(false, 0);
        assert(!joe.try_transferToken(address(gogeToken_v1), address(69), 10 ether));

        // Whitelist v2 token.
        gogeToken_v1.excludeFromFees(address(gogeToken_v2), true);

        // Retreive and emit price of 1 v1 token. Should be close to 0.000003179290557335831
        uint256 price = getPrice(address(gogeToken_v1));
        emit log_named_uint("cost of 1 v1 token", price); // 0.000002776595149082

        // -------------------- MIGRATE JOE --------------------

        // Approve and migrate
        assert(joe.try_approveToken(address(gogeToken_v1), address(gogeToken_v2), amountJoe));
        assert(joe.try_migrate(address(gogeToken_v2)));

        // Verify 0 v1 and amount v2 tokens.
        assertEq(gogeToken_v1.balanceOf(address(joe)), 0);
        assertEq(gogeToken_v2.balanceOf(address(joe)), amountJoe);

        // Emit price of v2 LP
        price = getPrice(address(gogeToken_v2));
        emit log_named_uint("cost of 1 v2 token", price); // 0.000002668733643407

        // get LP reserves -> token amount and bnb balance of v1 and v2 LPs
        (v1_reserveTokens, v1_reserveBnb,) = IUniswapV2Pair(gogeToken_v1.uniswapV2Pair()).getReserves();
        (v2_reserveTokens, v2_reserveBnb,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves();

        emit log_named_uint("v1 LP GOGE balance", v1_reserveTokens);
        emit log_named_uint("v1 LP BNB balance",  v1_reserveBnb);
        emit log_named_uint("v2 LP GOGE balance", v2_reserveTokens);
        emit log_named_uint("v2 LP BNB balance",  v2_reserveBnb);

        // -------------------- MIGRATE SAL --------------------

        // Approve and migrate
        assert(sal.try_approveToken(address(gogeToken_v1), address(gogeToken_v2), amountSal));
        assert(sal.try_migrate(address(gogeToken_v2)));

        // Verify 0 v1 and amount v2 tokens.
        assertEq(gogeToken_v1.balanceOf(address(sal)), 0);
        assertEq(gogeToken_v2.balanceOf(address(sal)), amountSal);

        // Emit price of v2 LP
        price = getPrice(address(gogeToken_v2));
        emit log_named_uint("cost of 1 v2 token", price); // 0.000002645226543690

        // get LP reserves -> token amount and bnb balance of v1 and v2 LPs
        (v1_reserveTokens, v1_reserveBnb,) = IUniswapV2Pair(gogeToken_v1.uniswapV2Pair()).getReserves();
        (v2_reserveTokens, v2_reserveBnb,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves();

        emit log_named_uint("v1 LP GOGE balance", v1_reserveTokens);
        emit log_named_uint("v1 LP BNB balance",  v1_reserveBnb);
        emit log_named_uint("v2 LP GOGE balance", v2_reserveTokens);
        emit log_named_uint("v2 LP BNB balance",  v2_reserveBnb);

        // -------------------- MIGRATE NIK --------------------

        // Approve and migrate
        assert(nik.try_approveToken(address(gogeToken_v1), address(gogeToken_v2), amountNik));
        assert(nik.try_migrate(address(gogeToken_v2)));

        // Verify 0 v1 and amount v2 tokens.
        assertEq(gogeToken_v1.balanceOf(address(nik)), 0);
        assertEq(gogeToken_v2.balanceOf(address(nik)), amountNik);

        // Emit price of v2 LP
        price = getPrice(address(gogeToken_v2));
        emit log_named_uint("cost of 1 v2 token", price); // 0.000002604572642078

        // get LP reserves -> token amount and bnb balance of v1 and v2 LPs
        (v1_reserveTokens, v1_reserveBnb,) = IUniswapV2Pair(gogeToken_v1.uniswapV2Pair()).getReserves();
        (v2_reserveTokens, v2_reserveBnb,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves();

        emit log_named_uint("v1 LP GOGE balance", v1_reserveTokens);
        emit log_named_uint("v1 LP BNB balance",  v1_reserveBnb);
        emit log_named_uint("v2 LP GOGE balance", v2_reserveTokens);
        emit log_named_uint("v2 LP BNB balance",  v2_reserveBnb);

        // -------------------- MIGRATE JON --------------------

        // Approve and migrate
        assert(jon.try_approveToken(address(gogeToken_v1), address(gogeToken_v2), amountJon));
        assert(jon.try_migrate(address(gogeToken_v2)));

        // Verify 0 v1 and amount v2 tokens.
        assertEq(gogeToken_v1.balanceOf(address(jon)), 0);
        assertEq(gogeToken_v2.balanceOf(address(jon)), amountJon);

        // Emit price of v2 LP
        price = getPrice(address(gogeToken_v2));
        emit log_named_uint("cost of 1 v2 token", price); // 0.000002595376689698

        // get LP reserves -> token amount and bnb balance of v1 and v2 LPs
        (v1_reserveTokens, v1_reserveBnb,) = IUniswapV2Pair(gogeToken_v1.uniswapV2Pair()).getReserves();
        (v2_reserveTokens, v2_reserveBnb,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves();

        emit log_named_uint("v1 LP GOGE balance", v1_reserveTokens);
        emit log_named_uint("v1 LP BNB balance",  v1_reserveBnb);
        emit log_named_uint("v2 LP GOGE balance", v2_reserveTokens);
        emit log_named_uint("v2 LP BNB balance",  v2_reserveBnb);

        // -------------------- MIGRATE TIM --------------------

        // Approve and migrate
        assert(tim.try_approveToken(address(gogeToken_v1), address(gogeToken_v2), amountTim));
        assert(!tim.try_migrate(address(gogeToken_v2)));

        // Verify 0 v1 and amount v2 tokens.
        assertEq(gogeToken_v1.balanceOf(address(tim)), amountTim);
        assertEq(gogeToken_v2.balanceOf(address(tim)), 0);

        // Emit price of v2 LP
        price = getPrice(address(gogeToken_v2));
        emit log_named_uint("cost of 1 v2 token", price); // 0.000002595376689698

        // get LP reserves -> token amount and bnb balance of v1 and v2 LPs
        (v1_reserveTokens, v1_reserveBnb,) = IUniswapV2Pair(gogeToken_v1.uniswapV2Pair()).getReserves();
        (v2_reserveTokens, v2_reserveBnb,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves();

        emit log_named_uint("v1 LP GOGE balance", v1_reserveTokens);
        emit log_named_uint("v1 LP BNB balance",  v1_reserveBnb);
        emit log_named_uint("v2 LP GOGE balance", v2_reserveTokens);
        emit log_named_uint("v2 LP BNB balance",  v2_reserveBnb);

        emit log_named_uint("circulating supply minus reserve", IGogeERC20(address(gogeToken_v2)).getCirculatingMinusReserve());
        emit log_named_uint("total supply", IGogeERC20(address(gogeToken_v2)).totalSupply());
        emit log_named_uint("uniswap balance", IGogeERC20(address(gogeToken_v2)).balanceOf(gogeToken_v2.uniswapV2Pair()));
        emit log_named_uint("dead balance", IGogeERC20(address(gogeToken_v2)).balanceOf(address(0)));
        emit log_named_uint("dead balance", IGogeERC20(address(gogeToken_v2)).balanceOf(gogeToken_v2.DEAD_ADDRESS()));
    }

    function test_migration_fuzzing(uint256 amountTokens) public {
        amountTokens = bound(amountTokens, 314_535 ether + 1, 18_000_000 ether);

        // -------------------- PRE STATE -------------------

        // Warp in time
        vm.warp(block.timestamp + 30 days);

        // Transfer tokens to Joe so he can migrate.
        gogeToken_v1.transfer(address(joe), amountTokens);
        
        // Verify amount v1 and 0 v2 tokens.
        assertEq(gogeToken_v1.balanceOf(address(joe)), amountTokens);
        assertEq(gogeToken_v2.balanceOf(address(joe)), 0);

        // get LP reserves -> token amount and bnb balance of v1 and v2 LPs
        (uint112 preReserveTokens_v1, uint112 preReserveBnb_v1,) = IUniswapV2Pair(gogeToken_v1.uniswapV2Pair()).getReserves();
        (uint112 preReserveTokens_v2, uint112 preReserveBnb_v2,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves(); // swapped for some reason

        emit log_named_uint("v1 LP GOGE balance", preReserveTokens_v1);
        emit log_named_uint("v1 LP BNB balance",  preReserveBnb_v1);
        emit log_named_uint("v2 LP GOGE balance", preReserveTokens_v2);
        emit log_named_uint("v2 LP BNB balance",  preReserveBnb_v2);

        // Verify reserves of v1 LP
        assertEq(preReserveTokens_v1, 22_345_616_917 ether);
        assertEq(preReserveBnb_v1,    220 ether);

        // Verify reserves of v2 LP
        assertEq(preReserveBnb_v2,    0);
        assertEq(preReserveTokens_v2, 0);

        // Disable trading on v1
        gogeToken_v1.setTradingIsEnabled(false, 0);
        assert(!joe.try_transferToken(address(gogeToken_v1), address(69), 10 ether));

        // Whitelist v2 token.
        gogeToken_v1.excludeFromFees(address(gogeToken_v2), true);

        // Retreive and emit price of 1 v1 token. Should be close to 0.000003179290557335831
        uint256 price = getPrice(address(gogeToken_v1));
        emit log_named_uint("cost of 1 v1 token", price); // 0.000002844106843617

        // Get amount of BNB
        address[] memory path = new address[](2);

        path[0] = address(gogeToken_v1);
        path[1] = WBNB;

        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut( amountTokens, path );

        // -------------------- MIGRATE --------------------

        // Approve and migrate
        assert(joe.try_approveToken(address(gogeToken_v1), address(gogeToken_v2), amountTokens));
        assert(joe.try_migrate(address(gogeToken_v2)));

        // -------------------- POST STATE -------------------

        // Verify 0 v1 and amount v2 tokens.
        assertEq(gogeToken_v1.balanceOf(address(joe)), 0);
        assertEq(gogeToken_v2.balanceOf(address(joe)), amountTokens);

        // Emit price of v2 LP
        price = getPrice(address(gogeToken_v2));
        emit log_named_uint("cost of 1 v2 token", price); // 0.000002836947746805

        // get LP reserves -> token amount and bnb balance of v1 and v2 LPs
        (uint112 postReserveTokens_v1, uint112 postReserveBnb_v1,) = IUniswapV2Pair(gogeToken_v1.uniswapV2Pair()).getReserves();
        (uint112 postReserveTokens_v2, uint112 postReserveBnb_v2,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves(); // swapped for some reason

        emit log_named_uint("v1 LP GOGE balance", preReserveTokens_v1);
        emit log_named_uint("v1 LP BNB balance",  preReserveBnb_v1);
        emit log_named_uint("v2 LP GOGE balance", preReserveTokens_v2);
        emit log_named_uint("v2 LP BNB balance",  preReserveBnb_v2);

        // Verify amountTokens was taken from v1 LP and added to v2 LP
        assertEq(amounts[1], postReserveTokens_v2);

        assertGt(postReserveBnb_v2,    preReserveBnb_v2);     // Verify post migration, v2 LP has more BNB than pre migration
        assertGt(postReserveTokens_v2, preReserveTokens_v2);  // Verify post migration, v2 LP has more tokens than pre migration

        assertLt(postReserveBnb_v1,    preReserveBnb_v1);     // Verify post migration, v1 LP has less BNB than pre migration
        assertGt(postReserveTokens_v1, preReserveTokens_v1);  // verify post migration, v1 LP has more tokens than pre migration

        //assertEq(gogeToken_v2.amountBnbExcess(), 0);
    }

}
