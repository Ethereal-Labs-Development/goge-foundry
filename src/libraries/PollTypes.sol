// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

library PollTypes {

    enum PollType {
        taxChange,
        funding,
        setDao,
        setCex,
        setDex,
        updateDividendToken,
        updateMarketingWallet,
        updateTeamWallet,
        updateTeamMember,
        updateVetoAuthority,
        setVetoEnabled,
        setSwapTokensAtAmount,
        setBuyBackEnabled,
        setCakeDividendEnabled,
        setMarketingEnabled,
        setTeamEnabled,
        updateCakeDividendTracker,
        updateUniswapV2Router,
        excludeFromFees,
        excludeFromDividends,
        updateGasForProcessing,
        updateMinimumBalanceForDividends,
        modifyBlacklist,
        transferOwnership,
        migrateTreasury,
        setQuorum,
        setMinPollPeriod,
        updateGovernanceToken,
        other
    }

    struct Metadata {
        string description;
        uint256 time1;
        uint256 time2;
        uint8 fee1;
        uint8 fee2;
        uint8 fee3;
        uint8 fee4;
	    uint8 multiplier;
        address addr1;
        address addr2;
        uint256 amount;
        bool boolVar;
    }

}