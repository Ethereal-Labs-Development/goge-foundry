// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import { Utility } from "./Utility.sol";
import { DogeGaySon } from "../src/GogeToken.sol";
import { DogeGaySon1 } from "../src/TokenV1.sol";
import { IUniswapV2Router01, IUniswapV2Router02, IUniswapV2Factory, IUniswapV2Pair, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";
import { IGogeERC20 } from "../src/interfaces/IGogeERC20.sol";

interface AggregatorInterface {
    function latestAnswer() external view returns (int256);
    function latestTimestamp() external view returns (uint256);
    function latestRound() external view returns (uint256);
    function getAnswer(uint256 roundId) external view returns (int256);
    function getTimestamp(uint256 roundId) external view returns (uint256);

    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);
    event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}

contract MigrationTesting is Utility {
    DogeGaySon1 gogeToken_v1;
    DogeGaySon  gogeToken_v2;
    address constant UNIV2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E; //bsc
    address constant BNB_PRICE_FEED_ORACLE = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;

    function setUp() public {
        createActors();
        
        // Deploy v1
        gogeToken_v1 = new DogeGaySon1();

        uint256 BNB_DEPOSIT = 300 ether;
        uint256 TOKEN_DEPOSIT = 22_345_616_917 ether;

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

        assertEq(gogeToken_v1.tradingIsEnabled(), true);
        assertEq(gogeToken_v2.tradingIsEnabled(), false);
    }


    // ~~ Utility Functions ~~

    /// @notice Returns the price of 1 token in USD
    function getPrice(address token) internal returns (uint256) {

        address[] memory path = new address[](3);

        path[0] = token;
        path[1] = WBNB;
        path[2] = BUSD;

        uint256[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(
            1 ether,
            path
        );

        return amounts[2];
    }


    // ~~ Unit Tests ~~

    /// @notice verifies the migration of v1 tokens to v2 tokens through single migrate() call.
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
        (v2_reserveBnb, v2_reserveTokens,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves();

        emit log_named_uint("v1 LP GOGE balance", v1_reserveTokens);
        emit log_named_uint("v1 LP BNB balance",  v1_reserveBnb);
        emit log_named_uint("v2 LP GOGE balance", v2_reserveTokens);
        emit log_named_uint("v2 LP BNB balance",  v2_reserveBnb);

        assertEq(gogeToken_v2.tradingIsEnabled(), false);
    }

    /// @notice verifies the ratio of v2 tokens received and liquidity added via migrate() with different amounts.
    function test_migration_ratio() public {

        // -------------------- PRE STATE -------------------

        // Warp in time
        vm.warp(block.timestamp + 30 days);

        //Initialize wallet amounts.
        uint256 amountJoe = 1_056_322_590 ether;
        uint256 amountSal = 610_217_752 ether;
        uint256 amountNik = 17_261_463 ether;
        uint256 amountJon = 3_984_357 ether;
        uint256 amountTim = 325_535 ether;

        // Transfer tokens to Joe so he can migrate.
        gogeToken_v1.transfer(address(joe), amountJoe); // 1,056,322,590
        gogeToken_v1.transfer(address(sal), amountSal); // 610,217,752
        gogeToken_v1.transfer(address(nik), amountNik); // 17,261,463
        gogeToken_v1.transfer(address(jon), amountJon); // 3,984,357
        gogeToken_v1.transfer(address(tim), amountTim); // 325,535
        
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
        assertEq(v1_reserveBnb, 22_345_616_917 ether);
        assertEq(v1_reserveTokens,    220 ether);

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
        (v2_reserveBnb, v2_reserveTokens,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves();

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
        (v2_reserveBnb, v2_reserveTokens,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves();

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
        (v2_reserveBnb, v2_reserveTokens,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves();

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
        (v2_reserveBnb, v2_reserveTokens,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves();

        emit log_named_uint("v1 LP GOGE balance", v1_reserveTokens);
        emit log_named_uint("v1 LP BNB balance",  v1_reserveBnb);
        emit log_named_uint("v2 LP GOGE balance", v2_reserveTokens);
        emit log_named_uint("v2 LP BNB balance",  v2_reserveBnb);

        // -------------------- MIGRATE TIM --------------------

        // Approve and migrate
        assert(tim.try_approveToken(address(gogeToken_v1), address(gogeToken_v2), amountTim));
        assert(tim.try_migrate(address(gogeToken_v2)));

        // Verify 0 v1 and amount v2 tokens.
        assertEq(gogeToken_v1.balanceOf(address(tim)), 0);
        assertEq(gogeToken_v2.balanceOf(address(tim)), amountTim);

        // Emit price of v2 LP
        price = getPrice(address(gogeToken_v2));
        emit log_named_uint("cost of 1 v2 token", price); // 0.000002595376689698

        // get LP reserves -> token amount and bnb balance of v1 and v2 LPs
        (v1_reserveTokens, v1_reserveBnb,) = IUniswapV2Pair(gogeToken_v1.uniswapV2Pair()).getReserves();
        (v2_reserveBnb, v2_reserveTokens,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves();

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

    /// @notice verifies with fuzzing random token amounts when calling migrate().
    function test_migration_fuzzing(uint256 amountTokens) public {
        amountTokens = bound(amountTokens, 500_000 ether, 18_000_000 ether);

        // -------------------- PRE STATE -------------------

        // Warp in time
        vm.warp(block.timestamp + 30 days);

        // Transfer tokens to Joe so he can migrate.
        gogeToken_v1.transfer(address(joe), amountTokens);
        
        // Verify amount v1 and 0 v2 tokens.
        assertEq(gogeToken_v1.balanceOf(address(joe)), amountTokens);
        assertEq(gogeToken_v2.balanceOf(address(joe)), 0);

        // get LP reserves -> token amount and bnb balance of v1 and v2 LPs
        //(uint112 preReserveTokens_v1, uint112 preReserveBnb_v1,) = IUniswapV2Pair(gogeToken_v1.uniswapV2Pair()).getReserves();
        //(uint112 preReserveTokens_v2, uint112 preReserveBnb_v2,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves(); // swapped for some reason

        uint256 preReserveTokens_v1 = gogeToken_v1.balanceOf(gogeToken_v1.uniswapV2Pair());
        uint256 preReserveBnb_v1    = wbnb.balanceOf(gogeToken_v1.uniswapV2Pair());
        uint256 preReserveTokens_v2 = gogeToken_v2.balanceOf(gogeToken_v2.uniswapV2Pair());
        uint256 preReserveBnb_v2    = wbnb.balanceOf(gogeToken_v2.uniswapV2Pair());
        
        emit log_named_uint("v1 LP GOGE balance", preReserveTokens_v1);
        emit log_named_uint("v1 LP BNB balance",  preReserveBnb_v1);
        emit log_named_uint("v2 LP GOGE balance", preReserveTokens_v2);
        emit log_named_uint("v2 LP BNB balance",  preReserveBnb_v2);

        // Verify reserves of v1 LP
        assertEq(preReserveTokens_v1, 22_345_616_917 ether);
        assertEq(preReserveBnb_v1,    220 ether);

        // Verify reserves of v2 LP
        assertEq(preReserveTokens_v2, 0);
        assertEq(preReserveBnb_v2,    0);

        // Disable trading on v1
        gogeToken_v1.setTradingIsEnabled(false, 0);
        assert(!joe.try_transferToken(address(gogeToken_v1), address(69), 10 ether));

        // Whitelist v2 token.
        gogeToken_v1.excludeFromFees(address(gogeToken_v2), true);

        // Retreive and emit price of 1 v1 token. Should be close to 0.000003179290557335831
        uint256 price = getPrice(address(gogeToken_v1));
        emit log_named_uint("cost of 1 v1 token", price); // 0.000002844106843617

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
        //(uint112 postReserveTokens_v1, uint112 postReserveBnb_v1,) = IUniswapV2Pair(gogeToken_v1.uniswapV2Pair()).getReserves();
        //(uint112 postReserveTokens_v2, uint112 postReserveBnb_v2,) = IUniswapV2Pair(gogeToken_v2.uniswapV2Pair()).getReserves(); // swapped for some reason

        uint256 postReserveTokens_v1 = gogeToken_v1.balanceOf(gogeToken_v1.uniswapV2Pair());
        uint256 postReserveBnb_v1    = wbnb.balanceOf(gogeToken_v1.uniswapV2Pair());
        uint256 postReserveTokens_v2 = gogeToken_v2.balanceOf(gogeToken_v2.uniswapV2Pair());
        uint256 postReserveBnb_v2    = wbnb.balanceOf(gogeToken_v2.uniswapV2Pair());

        emit log_named_uint("v1 LP GOGE balance", postReserveTokens_v1);
        emit log_named_uint("v1 LP BNB balance",  postReserveBnb_v1);
        emit log_named_uint("v2 LP GOGE balance", postReserveTokens_v2);
        emit log_named_uint("v2 LP BNB balance",  postReserveBnb_v2);

        // Verify amountTokens was taken from v1 LP and added to v2 LP
        assertEq(amountTokens, postReserveTokens_v2);

        assertGt(postReserveBnb_v2,    preReserveBnb_v2);     // Verify post migration, v2 LP has more BNB than pre migration
        assertGt(postReserveTokens_v2, preReserveTokens_v2);  // Verify post migration, v2 LP has more tokens than pre migration

        assertLt(postReserveBnb_v1,    preReserveBnb_v1);     // Verify post migration, v1 LP has less BNB than pre migration
        assertGt(postReserveTokens_v1, preReserveTokens_v1);  // verify post migration, v1 LP has more tokens than pre migration

        //assertEq(gogeToken_v2.amountBnbExcess(), 0);
    }

    /// @notice test case used to compare different methods of getting $goge token price.
    function test_migration_oracleTesting() public {
        uint256 amountTokens = 600_000 ether;
        address theRealGogeV1 = 0xa30D02C5CdB6a76e47EA0D65f369FD39618541Fe;
        address factory = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;

        // Get reserves of on-chain v1 (deployed v1)
        address v1Pair = IUniswapV2Factory(factory).getPair(theRealGogeV1, WBNB);
        (uint112 v1_reserveTokens, uint112 v1_reserveBnb,) = IUniswapV2Pair(v1Pair).getReserves();

        emit log_named_uint("v1 token balance", v1_reserveTokens);
        emit log_named_uint("v1 bnb balance", v1_reserveBnb);

        // Calculate price with oracle feed
        //uint256 pricePerToken = (uint256(v1_reserveBnb) * uint256(AggregatorInterface(BNB_PRICE_FEED_ORACLE).latestAnswer())) / v1_reserveTokens;
        //uint256 balanceValue = (pricePerToken * amountTokens) / 10**8;


        // NOTE: 3 ways to grab the price of token balance:

        // 1. Grab token reserves of LP and multiply by BNB price using chainlink oracle.
        (v1_reserveTokens, v1_reserveBnb,) = IUniswapV2Pair(v1Pair).getReserves();
        uint256 tokenPrice1 = (uint256(v1_reserveBnb) * uint256(AggregatorInterface(BNB_PRICE_FEED_ORACLE).latestAnswer())) / v1_reserveTokens;
        emit log_named_uint("price method 1", tokenPrice1);
        emit log_named_uint("balance USD value", tokenPrice1 * amountTokens / 10**8); // 1.380000000000000000 -> $1.38

        // 2. Grab bnb quote using getAmountsOut and multiply by BNB price from oracle
        address[] memory path = new address[](2);
        path[0] = theRealGogeV1;
        path[1] = WBNB;
        uint256[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(1 ether, path);
        uint256 tokenPrice2 = amounts[1] * uint256(AggregatorInterface(BNB_PRICE_FEED_ORACLE).latestAnswer());
        emit log_named_uint("price method 2", tokenPrice2);
        emit log_named_uint("balance USD value", tokenPrice2 * amountTokens / 10**26); // 1.382671927830074038 -> $1.38

        // 3. Grab BUSD quote using getAmountsOut
        path = new address[](3);
        path[0] = theRealGogeV1;
        path[1] = WBNB;
        path[2] = BUSD;
        amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(1 ether, path);
        uint256 tokenPrice3 = amounts[2];
        emit log_named_uint("price method 3", tokenPrice3);
        emit log_named_uint("balance USD value", tokenPrice3 * amountTokens / 10**18); // 1.384053790212000000 -> $1.38
    }

}