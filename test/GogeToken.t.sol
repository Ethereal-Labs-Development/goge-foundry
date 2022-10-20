// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import "../src/GogeToken.sol";

contract TokenTest is Utility, Test {
    DogeGaySon gogeToken;

    function setUp() public {
        createActors();
        setUpTokens();
        
        // deploy token.
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
    }

    // Initial state test.
    function test_gogeToken_init_state() public {
        assertEq(gogeToken.marketingWallet(), address(1));
        assertEq(gogeToken.teamWallet(),      address(2));
        assertEq(gogeToken.totalSupply(),     100_000_000_000 ether);
        assertEq(gogeToken.balanceOf(address(dev)), 100_000_000_000 ether);

        assertTrue(gogeToken.tradingIsEnabled());
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

    // This tests that a blacklisted sender can send tokens to a whitelisted receiver.
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
}
