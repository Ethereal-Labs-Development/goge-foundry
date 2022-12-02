// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";

import {IUniswapV2Router02, IUniswapV2Pair, IUniswapV2Router01, IWETH, IERC20} from "../src/interfaces/Interfaces.sol";
import {ERC20} from "../src/extensions/ERC20.sol";

import {DogeGaySon} from "../src/GogeToken.sol";
import {DogeGaySon1} from "../src/TokenV1.sol";
import {GogeDAO} from "../src/GogeDao.sol";

contract MainDeploymentTesting is Utility, Test {
    DogeGaySon1 gogeToken_v1;
    DogeGaySon gogeToken_v2;

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
        IERC20(address(gogeToken_v1)).approve(
            address(UNIV2_ROUTER),
            TOKEN_DEPOSIT
        );

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

        // (1) Deploy v2 token
        gogeToken_v2 = new DogeGaySon(
            address(0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B),
            address(0xe142E9FCbd9E29C4A65C4979348d76147190a05a),
            100_000_000_000,
            address(gogeToken_v1)
        );

        // (2) Disable trading on v1
        gogeToken_v1.setTradingIsEnabled(false, 0);

        // (3) Exclude v2 on v1
        gogeToken_v1.excludeFromFees(address(gogeToken_v2), true);

        // (4) Perform migration
        migrateActor(joe);
        migrateActor(sal);
        migrateActor(nik);
        migrateActor(jon);
        migrateActor(tim);

        // Show price of v2
        price = getPrice(address(gogeToken_v2));
        emit log_named_uint("cost of 1 v2 token", price); // 0.000002119865796663
    }

    // ~~ Utility Functions ~~

    /// @notice Returns the price of 1 token in USD
    function getPrice(address token) internal returns (uint256) {
        address[] memory path = new address[](3);

        path[0] = token;
        path[1] = WBNB;
        path[2] = BUSD;

        uint256[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER)
            .getAmountsOut(1 ether, path);

        return amounts[2];
    }

    /// @notice Creates v1 token holders. The holder balances should total just under 22B tokens
    function createHolders() internal {
        //Initialize wallet amounts.
        uint256 amountJoe = 10_056_322_590 ether;
        uint256 amountSal = 8_610_217_752 ether;
        uint256 amountNik = 900_261_463 ether;
        uint256 amountJon = 200_984_357 ether;
        uint256 amountTim = 320_535 ether;

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

        // Approve and migrate
        assert(
            actor.try_approveToken(
                address(gogeToken_v1),
                address(gogeToken_v2),
                gogeToken_v1.balanceOf(address(actor))
            )
        );
        assert(actor.try_migrate(address(gogeToken_v2)));

        assertEq(gogeToken_v1.balanceOf(address(actor)), 0);
        assertEq(gogeToken_v2.balanceOf(address(actor)), bal);
    }

    // ~~ Unit Tests ~~

    /// @notice Initial state test.
    function test_mainDeployment_init_state() public {
        assertTrue(true);
    }
}
