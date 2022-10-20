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

    // This tests that a blacklisted wallet can only make transfers to a whitelisted wallet.
    // function test_taxToken_blacklist_whitelist() public {
    //     // This contract can successfully send assets to address(32).
    //     assert(taxToken.transfer(address(32), 1 ether));

    //     // Blacklist this contract.
    //     taxToken.modifyBlacklist(address(this), true);

    //     // This contract can no longer send tokens to address(32).
    //     assert(!taxToken.transfer(address(32), 1 ether));

    //     // Whitelist address(32).
    //     taxToken.modifyWhitelist(address(32), true);

    //     // This contract can successfully send assets to whitelisted address(32).
    //     assert(taxToken.transfer(address(32), 1 ether));
    // }
}
