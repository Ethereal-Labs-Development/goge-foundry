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

}