// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import { DogeGaySon, CakeDividendTracker } from "../src/GogeToken.sol";

import { IUniswapV2Router02, IUniswapV2Pair, IUniswapV2Router01, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";
import { IGogeERC20 } from "../src/extensions/IGogeERC20.sol";

contract TokenTest is Utility, Test {
    DogeGaySon gogeToken;
    CakeDividendTracker cakeTracker;

    address UNIV2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    function setUp() public {
        createActors();
        setUpTokens();
        
        // deploy token.
        gogeToken = new DogeGaySon(
            address(1),
            address(2),
            100_000_000_000,
            address(0xa30D02C5CdB6a76e47EA0D65f369FD39618541Fe) // govev1
        );

        cakeTracker = gogeToken.cakeDividendTracker();

        // Give tokens and ownership to dev.
        gogeToken.transfer(address(dev), 100_000_000_000 ether);
        gogeToken._transferOwnership(address(dev));

        // enable trading.
        assert(dev.try_enableTrading(address(gogeToken)));
    }

    // Initial state test.
    function test_gogeToken_init_state() public {
        assertEq(gogeToken.marketingWallet(), address(1));
        assertEq(gogeToken.teamWallet(),      address(2));
        assertEq(gogeToken.totalSupply(),     100_000_000_000 ether);
        assertEq(gogeToken.balanceOf(address(dev)), 100_000_000_000 ether);
        assertEq(gogeToken.owner(), address(dev));
        assertEq(gogeToken.GogeV1(), 0xa30D02C5CdB6a76e47EA0D65f369FD39618541Fe);

        assertEq(cakeTracker.excludedFromDividends(address(cakeTracker)),                 true);
        assertEq(cakeTracker.excludedFromDividends(address(gogeToken)),                   true);
        assertEq(cakeTracker.excludedFromDividends(address(gogeToken.uniswapV2Router())), true);
        assertEq(cakeTracker.excludedFromDividends(gogeToken.DEAD_ADDRESS()),             true);
        assertEq(cakeTracker.excludedFromDividends(address(0)),                           true);
        assertEq(cakeTracker.excludedFromDividends(gogeToken.owner()),                    true);
        assertEq(cakeTracker.excludedFromDividends(gogeToken.devWallet()),                true);
        assertEq(cakeTracker.excludedFromDividends(gogeToken.marketingWallet()),          true);
        assertEq(cakeTracker.excludedFromDividends(gogeToken.teamWallet()),               true);

        assertEq(gogeToken.isExcludedFromFees(gogeToken.marketingWallet()), true);
        assertEq(gogeToken.isExcludedFromFees(gogeToken.teamWallet()),      true);
        assertEq(gogeToken.isExcludedFromFees(gogeToken.devWallet()),       true);
        assertEq(gogeToken.isExcludedFromFees(address(gogeToken)),          true);
        assertEq(gogeToken.isExcludedFromFees(gogeToken.owner()),           true);
        assertEq(gogeToken.isExcludedFromFees(gogeToken.DEAD_ADDRESS()),    true);
        assertEq(gogeToken.isExcludedFromFees(address(0)),                  true);

        assertEq(gogeToken.cakeDividendRewardsFee(), 10);
        assertEq(gogeToken.marketingFee(),           2);
        assertEq(gogeToken.buyBackFee(),             2);
        assertEq(gogeToken.teamFee(),                2);
        assertEq(gogeToken.marketingEnabled(),       true);
        assertEq(gogeToken.buyBackEnabled(),         true);
        assertEq(gogeToken.cakeDividendEnabled(),    true);
        assertEq(gogeToken.teamEnabled(),            true);
        assertEq(gogeToken.swapTokensAtAmount(),     20_000_000 ether);

        assertEq(gogeToken.tradingIsEnabled(), true);
        assertEq(gogeToken._firstBlock(), block.timestamp);
    }

    // ~ Transfer Testing ~

    // Whitelisted Transfer test -> no tax.
    function test_gogeToken_transfer_WL() public {
        assert(dev.try_transferToken(address(gogeToken), address(joe), 1_000_000 ether));
        assertEq(gogeToken.balanceOf(address(joe)), 1_000_000 ether);
    }

    // ~ Blacklist Testing ~

    // This tests blacklisting of the receiver.
    function test_gogeToken_blacklist_receiver() public {
        assert(dev.try_transferToken(address(gogeToken), address(joe), 100 ether));

        assert(joe.try_transferToken(address(gogeToken), address(32), 10 ether));
        assert(dev.try_modifyBlacklist(address(gogeToken), address(32), true));
        assert(!joe.try_transferToken(address(gogeToken), address(32), 10 ether));
    }

    // This tests blacklisting of the sender.
    function test_gogeToken_blacklist_sender() public {
        assert(dev.try_transferToken(address(gogeToken), address(joe), 100 ether));

        assert(joe.try_transferToken(address(gogeToken), address(32), 10 ether));
        assert(dev.try_modifyBlacklist(address(gogeToken), address(joe), true));
        assert(!joe.try_transferToken(address(gogeToken), address(32), 10 ether));
    }

    // This tests that a blacklisted sender can send tokens to a whitelisted receiver.
    function test_gogeToken_blacklist_to_whitelist() public {
        // This contract can successfully send assets to address(joe).
        assert(dev.try_transferToken(address(gogeToken), address(joe), 100 ether));

        // Blacklist joe.
        assert(dev.try_modifyBlacklist(address(gogeToken), address(joe), true));

        // Joe can no longer send tokens to address(32).
        assert(!joe.try_transferToken(address(gogeToken), address(32), 10 ether));

        // Whitelist address(32).
        assert(dev.try_excludeFromFees(address(gogeToken), address(32), true));

        // Joe can successfully send assets to whitelisted address(32).
        assert(joe.try_transferToken(address(gogeToken), address(32), 10 ether));
    }

    // This tests that a whitelisted sender can send tokens to a blacklisted receiver.
    function test_gogeToken_whitelist_to_blacklist() public {
        // This contract can successfully send assets to address(joe).
        assert(dev.try_transferToken(address(gogeToken), address(joe), 100 ether));

        // Blacklist address(32).
        assert(dev.try_modifyBlacklist(address(gogeToken), address(32), true));

        // Joe can no longer send tokens to address(32).
        assert(!joe.try_transferToken(address(gogeToken), address(32), 10 ether));

        // Whitelist Joe.
        assert(dev.try_excludeFromFees(address(gogeToken), address(joe), true));

        // Joe can successfully send assets to blacklisted address(32).
        assert(joe.try_transferToken(address(gogeToken), address(32), 10 ether));
    }

    // ~ Whitelist testing (excludedFromFees) ~

    // This test case verifies that a whitelisted sender is not taxed when transferring tokens.
    function test_gogeToken_whitelist() public {
        // This contract can successfully send assets to address(joe).
        assert(dev.try_transferToken(address(gogeToken), address(joe), 100 ether));

        // Joe sends tokens to address(32).
        assert(joe.try_transferToken(address(gogeToken), address(32), 10 ether));

        // Post-state check. Address(32) has been taxed 16% on transfer.
        assertEq(gogeToken.balanceOf(address(32)), (10 ether) - ((10 ether) * 16/100));

        // Whitelist joe.
        assert(dev.try_excludeFromFees(address(gogeToken), address(joe), true));

        // Joe is whitelisted thus sends non-taxed tokens to address(34).
        assert(joe.try_transferToken(address(gogeToken), address(34), 10 ether));

        // Post-state check. Address(34) has NOT been taxed.
        assertEq(gogeToken.balanceOf(address(34)), 10 ether);
    }

    // ~ setters ~

    // This tests the proper state change when calling setDAO().
    function test_gogeToken_setGogeDao() public {
        // Pre-state check. DAO is currently set to address(0) (hasnt been set yet).
        assertEq(gogeToken.gogeDao(), address(0));

        // Set DAO to address(32).
        assert(dev.try_setGogeDao(address(gogeToken), address(32)));

        // Post-state check. Verify that gogeDao is set to address(32).
        assertEq(gogeToken.gogeDao(), address(32));
    }

    // This tests the proper state changes when calling updateSwapTokensAtAmount().
    function test_gogeToken_updateSwapTokensAtAmount() public {
        // Pre-state check. Verify current value of swapTokensAtAmount
        assertEq(gogeToken.swapTokensAtAmount(), 20_000_000 * WAD);

        // Update swapTokensAtAmount
        assert(dev.try_updateSwapTokensAtAmount(address(gogeToken), 1_000_000));

        // Post-state check. Verify updated value of swapTokensAtAmount
        assertEq(gogeToken.swapTokensAtAmount(), 1_000_000 * WAD);
    }

    // updateFees test
    function test_gogeToken_updateFees() public {
        //Pre-state check.
        assertEq(gogeToken.cakeDividendRewardsFee(), 10);
        assertEq(gogeToken.marketingFee(), 2);
        assertEq(gogeToken.buyBackFee(), 2);
        assertEq(gogeToken.teamFee(), 2);

        assertEq(gogeToken.totalFees(), 16);

        // Call updateFees
        assert(dev.try_updateFees(address(gogeToken), 14, 6, 3, 3));

        // Post-state check.
        assertEq(gogeToken.cakeDividendRewardsFee(), 14);
        assertEq(gogeToken.marketingFee(), 6);
        assertEq(gogeToken.buyBackFee(), 3);
        assertEq(gogeToken.teamFee(), 3);

        assertEq(gogeToken.totalFees(), 26);

        // Restriction: Cannot set totalFee to be greater than 40
        assert(!dev.try_updateFees(address(gogeToken), 20, 10, 5, 6)); // 41
    }

    // setBuyBackEnabled test
    function test_gogeToken_setBuyBackEnabled() public {
        // Pre-state check.
        assertEq(gogeToken.buyBackEnabled(), true);
        assertEq(gogeToken.buyBackFee(), 2);
        assertEq(gogeToken.previousbuyBackFee(), 0);

        // Disable buyBack
        assert(dev.try_setBuyBackEnabled(address(gogeToken), false));

        //Post-state check.
        assertEq(gogeToken.buyBackEnabled(), false);
        assertEq(gogeToken.buyBackFee(), 0);
        assertEq(gogeToken.previousbuyBackFee(), 2);
    }

    // setMarketingEnabled test
    function test_gogeToken_setMarketingEnabled() public {
        // Pre-state check.
        assertEq(gogeToken.marketingEnabled(), true);
        assertEq(gogeToken.marketingFee(), 2);
        assertEq(gogeToken.previousMarketingFee(), 0);

        // Disable buyBack
        assert(dev.try_setMarketingEnabled(address(gogeToken), false));

        //Post-state check.
        assertEq(gogeToken.marketingEnabled(), false);
        assertEq(gogeToken.marketingFee(), 0);
        assertEq(gogeToken.previousMarketingFee(), 2);
    }

    // setCakeDividendEnabled test
    function test_gogeToken_setCakeDividendEnabled() public {
        // Pre-state check.
        assertEq(gogeToken.cakeDividendEnabled(), true);
        assertEq(gogeToken.cakeDividendRewardsFee(), 10);
        assertEq(gogeToken.previousCakeDividendRewardsFee(), 0);

        // Disable buyBack
        assert(dev.try_setCakeDividendEnabled(address(gogeToken), false));

        //Post-state check.
        assertEq(gogeToken.cakeDividendEnabled(), false);
        assertEq(gogeToken.cakeDividendRewardsFee(), 0);
        assertEq(gogeToken.previousCakeDividendRewardsFee(), 10);
    }

    // setTeamEnabled test
    function test_gogeToken_setTeamEnabled() public {
        // Pre-state check.
        assertEq(gogeToken.teamEnabled(), true);
        assertEq(gogeToken.teamFee(), 2);
        assertEq(gogeToken.previousTeamFee(), 0);

        // Disable buyBack
        assert(dev.try_setTeamEnabled(address(gogeToken), false));

        //Post-state check.
        assertEq(gogeToken.teamEnabled(), false);
        assertEq(gogeToken.teamFee(), 0);
        assertEq(gogeToken.previousTeamFee(), 2);
    }

    function test_gogeToken_safeWithdraw() public {
        mint("BUSD", address(gogeToken), 1_000 ether);

        assertEq(IERC20(BUSD).balanceOf(address(gogeToken)), 1_000 ether);
        assertEq(IERC20(BUSD).balanceOf(address(dev)), 0);

        assert(dev.try_safeWithdraw(address(gogeToken), BUSD));

        assertEq(IERC20(BUSD).balanceOf(address(gogeToken)), 0);
        assertEq(IERC20(BUSD).balanceOf(address(dev)), 1_000 ether);
    }

}
