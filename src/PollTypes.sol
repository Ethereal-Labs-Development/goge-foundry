// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.6;

contract PollTypes {

    /// @notice Array of poll types as strings.
    string  [] public actions;

    /// @notice Metadata block. All combinations.
    /// @param description proposal description.
    /// @param endTime unix timestamp of poll expiration date.
    /// @param fee1 uint8 rewardFee.
    /// @param fee2 uint8 marketingFee.
    /// @param fee3 uint8 buyBackFee.
    /// @param fee4 uint8 teamFee.
    /// @param addr1 first address input.
    /// @param addr2 second address input.
    /// @param amount uint256 amount input.
    /// @param boolVar boolean input.
    struct Metadata {
        string description;
        uint256 endTime;
        uint8 fee1;
        uint8 fee2;
        uint8 fee3;
        uint8 fee4;
        address addr1;
        address addr2;
        uint256 amount;
        bool boolVar;
    }

    /// @notice Poll type to propose a tax change.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  cakeDividendsFee uint8 rewardFee.
    /// @param  marketingFee uint8 marketingFee.
    /// @param  buyBackFee uint8 buyBackFee.
    /// @param  teamFee uint8 teamFee.
    /// @dev    Sum or totalFee has to be equal-to or less-than 40.
    ///         Will result in a call to GovernanceTokenAddr.updateFees().
    struct TaxChange {
        string description;
        uint256 endTime;
        uint8 cakeDividendsFee;
        uint8 marketingFee;
        uint8 buyBackFee;
        uint8 teamFee;
    }
    
    /// @notice Poll type to propose a funding from marketingBalance.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  recipient address of funding recipient.
    /// @dev    Will result in a transfer of BNB from address(this) to recipient.
    struct Funding {
        string description;
        uint256 endTime;
        address payable recipient;
        uint256 amount;
    }

    /// @notice Poll type to propose changing gogeDao address on governance token.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr address of new DAO contract.
    /// @dev    Will result in a call to GovernanceTokenAddr.setGogeDao().
    struct SetGogeDao {
        string description;
        uint256 endTime;
        address addr;
    }

    /// @notice Poll type to propose whitelisting and exluding from dividends an address.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr address of partner address.
    /// @dev    Will result in a call to GovernanceTokenAddr.addPartnerOrExchange().
    struct SetCex {
        string description;
        uint256 endTime;
        address addr; 
    }

    /// @notice Poll type to propose adding an exchange/pair to governacne token.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr address of new exchange/pair.
    /// @dev    Will result in a call to GovernanceTokenAddr.setAutomatedMarketMakerPair().
    struct SetDex {
        string description;
        uint256 endTime;
        address addr;
        bool boolVar;
    }

    /// @notice Poll type to propose excluding an address from circulating supply.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr address of excluded address.
    /// @param  bool is excluded.
    /// @dev    Will result in a call to GovernanceTokenAddr.excludeFromCirculatingSupply().
    struct ExcludeFromCirculatingSupply {
        string description;
        uint256 endTime;
        address addr;
        bool boolVar;
    }

    /// @notice Poll type to propose changing the rewards token.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr address of new dividend token.
    /// @dev    Will result in a call to GovernanceTokenAddr.updateCakeDividendToken().
    struct UpdateDividendToken {
        string description;
        uint256 endTime;
        address addr;
    }

    /// @notice Poll type to propose changing the marketing wallet.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr address of new marketing wallet.
    /// @dev    Will result in a call to GovernanceTokenAddr.updateMarketingWallet().
    struct UpdateMarketingWallet {
        string description;
        uint256 endTime;
        address payable addr;
    }

    /// @notice Poll type to propose changing the team wallet.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr address of new team wallet.
    /// @dev    Will result in a call to GovernanceTokenAddr.updateTeamWallet().
    struct UpdateTeamWallet {
        string description;
        uint256 endTime;
        address payable addr;
    }

    /// @notice Poll type to propose adding a new team member.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr address of new team member address.
    /// @param  boolVar wallet is a team member.
    /// @dev    Will result in a call to _setTeamMember().
    struct UpdateTeamMember {
        string description;
        uint256 endTime;
        address payable addr;
        bool boolVar;
    }

    /// @notice Poll type to propose adding wallet to gate keepers.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr address of new gate keeper address.
    /// @param  boolVar wallet is a gate keeper.
    /// @dev    Will result in a call to _setGateKeeper().
    struct UpdateGatekeeper {
        string description;
        uint256 endTime;
        address addr;
        bool boolVar;  
    }

    /// @notice Poll type to propose updating status of gateKeeping.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  boolVar gateKeeping is enabled.
    /// @dev    Will result in a call to _setGateKeeping().
    struct SetGatekeeping {
        string description;
        uint256 endTime;
        bool boolVar;      
    }

    /// @notice Poll type to propose updating status of buyBackFee tax.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  boolVar buyBackFee is enabled.
    /// @dev    Will result in a call to GovernanceTokenAddr.setBuyBackEnabled().
    struct SetBuyBackEnabled {
        string description;
        uint256 endTime;
        bool boolVar;      
    }

    /// @notice Poll type to propose updating status of cakeDividendFee tax.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  boolVar cakeDividendFee is enabled.
    /// @dev    Will result in a call to GovernanceTokenAddr.setCakeDividendEnabled().
    struct SetCakeDividendEnabled {
        string description;
        uint256 endTime;
        bool boolVar;      
    }

    /// @notice Poll type to propose updating status of cakeDividend tax.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  boolVar marketingFee is enabled.
    /// @dev    Will result in a call to GovernanceTokenAddr.setMarketingEnabled().
    struct SetMarketingEnabled {
        string description;
        uint256 endTime;
        bool boolVar;      
    }

    /// @notice Poll type to propose updating status of teamFee tax.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  boolVar teamFee is enabled.
    /// @dev    Will result in a call to GovernanceTokenAddr.setTeamEnabled().
    struct SetTeamEnabled {
        string description;
        uint256 endTime;
        bool boolVar;      
    }

    /// @notice Poll type to propose excluding an address from fees.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr address to exclude from fees.
    /// @param  boolVar is excluded from fees.
    /// @dev    Will result in a call to GovernanceTokenAddr.excludeFromFees().
    struct ExcludeFromFees {
        string description;
        uint256 endTime;
        address payable addr;
        bool boolVar;
    }

    /// @notice Poll type to propose excluding an address from dividend rewards.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr address to exclude from dividends.
    /// @dev    Will result in a call to GovernanceTokenAddr.excludeFromDividend().
    struct ExcludeFromDividends {
        string description;
        uint256 endTime;
        address payable addr;
    }

    /// @notice Poll type to propose adding an address to the blacklist.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr address to blacklist.
    /// @param  boolVar is blacklisted.
    /// @dev    Will result in a call to GovernanceTokenAddr.modifyBlacklist().
    struct ModifyBlacklist {
        string description;
        uint256 endTime;
        address payable addr;
        bool blacklisted;
    }

    /// @notice Poll type to propose transferring the ownership of governance token.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr address to pass ownership to.
    /// @dev    Will result in a call to GovernanceTokenAddr._transferOwnership().
    struct TransferOwnership {
        string description;
        uint256 endTime;
        address payable addr;
    }

    /// @notice Poll type to propose changing the voting quorum.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  amount new quorum.
    /// @dev    Will result in a call to _updateQuorum().
    struct SetQuorum {
        string description;
        uint256 endTime;
        uint256 amount;
    }

    /// @notice Poll type to propose updating the governanceTokenAddr.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr new governance token.
    /// @dev    Will result in a call to _changeGovernanceToken().
    struct UpdateGovernanceToken {
        string description;
        uint256 endTime;
        address addr;
    }

    struct UpdateMinPeriod {
        string description;
        uint256 endTime;
        uint256 amount;
    }

    struct UpdateMaxPeriod {
        string description;
        uint256 endTime;
        uint256 amount;
    }

    struct UpdateMinAuthorBal {
        string description;
        uint256 endTime;
        uint256 amount;
    }

    struct UpdateMaxPollsPerAuthor {
        string description;
        uint256 endTime;
        uint256 amount;
    }

    /// @notice Poll type to propose an arbitrary proposal.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    struct Other {
        string description;
        uint256 endTime;
    }

    constructor () public {
        actions = [
            "taxChange",
            "funding",
            "setGogeDao",
            "setCex",
            "setDex",
            "excludeFromCirculatingSupply",
            "updateDividendToken",
            "updateMarketingWallet",
            "updateTeamWallet",
            "updateTeamMember",
            "updateGateKeeper",
            "setGateKeeping",
            "setBuyBackEnabled",
            "setCakeDividendEnabled",
            "setMarketingEnabled",
            "setTeamEnabled",
            "excludeFromFees",
            "excludeFromDividends",
            "modifyBlacklist",
            "transferOwnership",
            "migrateTreasury",
            "setQuorum",
            "updateGovernanceToken",
            "updateMinPeriod",
            "updateMaxPeriod",
            "updateMinAuthorBal",
            "updateMaxPollsPerAuthor",
            "other"
        ];
    }
    
}