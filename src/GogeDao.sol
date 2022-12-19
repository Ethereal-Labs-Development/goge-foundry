/*
$GOGE DAO

Name to be determined: 
GogeDAO / $GOGE 
DogeGaySon/ $GOGE

Automatic $CAKE rewards. 

Ability to stake tokens during vote (Perhaps  the ability to leave tokens staked and still get cake rewards as a collective pool) 

Contract owned by DAO.
Marketing wallet owned by DAO.
Team wallet owned by DAO.

Votes must reach a threshold amount (whatever is recommended, quorum, and will have perhaps 10-14 days period of proposal. (We can even have upcoming votes scheduled ect) 

Manual / External proposals that can be made by the community and executed by the GOGE Core team / community / DAO. (For example having people vote on a flag for the micronation) 

Automatic payments to the full team per month approved by the DAO

The More tokens you have the more vote power you have type of DAO. 

All current issues fixed in contract so we pass an audit with 100% :D (also show we show up on token scanners without any warnings) (I believe these were the 90% scanners / ability to make taxes a very high amount, perhaps we should have a way we can never change the taxes to something over our starting tax, or the rainbow hours max %) (also the anti bot I think had something that could be changed/ the blacklisting issue) (I can’t think of anything else as of right now) 

* if possible * A charity wallet that the ĐAO could control if possible (for direct action charity and also for charity donations)
*/
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./libraries/Libraries.sol";
import "./extensions/Ownable.sol";
import "./extensions/ERC20.sol";


contract GogeDAO is Ownable {
    using SafeMath for uint256;
    
    address public governanceTokenAddr;
    uint256 public pollNum;
    uint256 public minPeriod = 86400;
    mapping(uint256 => mapping(address => uint256)) public polls;
    mapping(uint256 => address[]) public voterLibrary;
    mapping(uint256 => uint256) public totalVotes;
    mapping(uint256 => uint256) public historicalTally;
    mapping(uint256 => uint256) public pollStartTime;
    mapping(uint256 => uint256) public pollEndTime;
    mapping(uint256 => bool) public passed;
    bool public veto = true;
    mapping(address => bool) public vetoAuthority;
    address [] public teamMembers;
    string [] public actions;
    uint256 public marketingBalance;
    uint256 public teamBalance;

    uint256 public quorum = 50;

    //PollTypes.PollType public PollType;

    enum PollType {
        taxChange,
        funding,
        setGogeDao,
        setCex,
        setDex,
        excludeFromCirculatingSupply,
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

    // -------- Poll Structs -----------

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

    struct TaxChange {
        string description;
        uint256 startTime;
        uint256 endTime;
        uint8 cakeDividendsFee;
        uint8 marketingFee;
        uint8 buyBackFee;
        uint8 teamFee;
    }

    struct Funding {
        string description;
        uint256 startTime;
        uint256 endTime;
        address payable recipient;
        address token;
        uint256 amount;
    }

    struct SetGogeDao {
        string description;
        uint256 startTime;
        uint256 endTime;
        address addr;
    }

    struct SetCex {
        string description;
        uint256 startTime;
        uint256 endTime;
        address addr; 
    }

    struct SetDex {
        string description;
        uint256 startTime;
        uint256 endTime;
        address addr;
        bool boolVar;
    }

    struct ExcludeFromCirculatingSupply {
        string description;
        uint256 startTime;
        uint256 endTime;
        address addr;
        bool boolVar;
    }

    struct UpdateDividendToken {
        string description;
        uint256 startTime;
        uint256 endTime;
        address addr;
    }

    struct UpdateMarketingWallet {
        string description;
        uint256 startTime;
        uint256 endTime;
        address payable addr;
    }

    struct UpdateTeamWallet {
        string description;
        uint256 startTime;
        uint256 endTime;
        address payable addr;
    }

    struct UpdateTeamMember {
        string description;
        uint256 startTime;
        uint256 endTime;
        address payable addr;
        bool boolVar;
    }

    struct UpdateVetoAuthority {
        string description;
        uint256 startTime;
        uint256 endTime;
        address addr;
        bool boolVar;  
    }

    struct SetVetoEnabled {
        string description;
        uint256 startTime;
        uint256 endTime;
        bool boolVar;      
    }

    struct SetSwapTokensAtAmount {
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 amount;  
    }

    struct SetBuyBackEnabled {
        string description;
        uint256 startTime;
        uint256 endTime;
        bool boolVar;      
    }

    struct SetCakeDividendEnabled {
        string description;
        uint256 startTime;
        uint256 endTime;
        bool boolVar;      
    }

    struct SetMarketingEnabled {
        string description;
        uint256 startTime;
        uint256 endTime;
        bool boolVar;      
    }

    struct SetTeamEnabled {
        string description;
        uint256 startTime;
        uint256 endTime;
        bool boolVar;      
    }

    struct UpdateCakeDividendTracker {
        string description;
        uint256 startTime;
        uint256 endTime;
        address payable addr;
    }

    struct UpdateUniswapV2Router {
        string description;
        uint256 startTime;
        uint256 endTime;
        address payable addr;
    }

    struct ExcludeFromFees {
        string description;
        uint256 startTime;
        uint256 endTime;
        address payable addr;
        bool boolVar;
    }

    struct ExcludeFromDividends {
        string description;
        uint256 startTime;
        uint256 endTime;
        address payable addr;
    }

    struct UpdateGasForProcessing {
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 amount;  
    }

    struct UpdateMinimumBalanceForDividends {
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 amount;  
    }

    struct ModifyBlacklist {
        string description;
        uint256 startTime;
        uint256 endTime;
        address payable addr;
        bool blacklisted;
    }

    struct TransferOwnership {
        string description;
        uint256 startTime;
        uint256 endTime;
        address payable addr;
    }

    struct MigrateTreasury {
        string description;
        uint256 startTime;
        uint256 endTime;
        address payable addr;
        address token;
    }

    struct SetQuorum {
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 amount;
    }

    struct SetMinPollPeriod {
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 amount;
    }

    struct UpdateGovernanceToken {
        string description;
        uint256 startTime;
        uint256 endTime;
        address addr;
    }

    struct Other {
        string description;
        uint256 startTime;
        uint256 endTime;
    }

    mapping(uint256 => PollType) public pollTypes;
    mapping(uint256 => Metadata) public pollMap;

    event ProposalCreated(uint256 pollNum, PollType pollType, uint256 startTime, uint256 endTime);
    event VetoEnabledUpdated(bool enabled);

    constructor(address _governanceToken) {
        governanceTokenAddr = _governanceToken;
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
            "updateVetoAuthority",
            "setVetoEnabled",
            "setSwapTokensAtAmount",
            "setBuyBackAndLiquifyEnabled",
            "setCakeDividendEnabled",
            "setMarketingEnabled",
            "setTeamEnabled",
            "updateCakeDividendTracker",
            "updateUniswapV2Router",
            "excludeFromFees",
            "excludeFromDividends",
            "updateGasForProcessing",
            "updateMinimumBalanceForDividends",
            "modifyBlacklist",
            "transferOwnership",
            "migrateTreasury",
            "setQuorum",
            "setMinPollPeriod",
            "updateGovernanceToken",
            "other"
        ];
    }

    receive() payable external {}

    // ---------- Votes ----------

    /// @notice A method for a voter to create a vote.
    /// @param  _pollNum The poll number.
    /// @param  _numVotes The size of the vote to be created.
    function addVote(uint256 _pollNum, uint256 _numVotes) public {

        require(block.timestamp - ERC20(governanceTokenAddr).getLastReceived(_msgSender()) >= (5 minutes), "Must wait 5 minutes after purchasing tokens to place any votes.");
        require(_pollNum <= pollNum, "Poll doesn't Exist");
        require(ERC20(governanceTokenAddr).balanceOf(_msgSender()) >= _numVotes, "Exceeds Balance");
        require(block.timestamp >= pollStartTime[_pollNum] && block.timestamp < pollEndTime[_pollNum], "Poll Closed");
        require(ERC20(governanceTokenAddr).transferFrom(_msgSender(), address(this), _numVotes));

        voterLibrary[_pollNum].push(_msgSender());
        polls[_pollNum][_msgSender()] = _numVotes;
        totalVotes[_pollNum] += _numVotes;
        historicalTally[_pollNum] += _numVotes;

        bool quorumMet = ( totalVotes[_pollNum] * 100 / ERC20(governanceTokenAddr).getCirculatingMinusReserve() ) >= quorum;
        bool enactChange = false;

        if (!veto && quorumMet) {
            enactChange = true;
        }
        else if (vetoAuthority[_msgSender()] && quorumMet) {
            enactChange = true;
        }

        if (enactChange) {

            pollEndTime[_pollNum] = block.timestamp;
            passed[_pollNum] = true;

            if (pollTypes[_pollNum] == PollType.taxChange) {
                TaxChange memory taxchange;
                (,taxchange,) = getTaxChange(_pollNum);
                ERC20(governanceTokenAddr).updateFees(taxchange.cakeDividendsFee, taxchange.marketingFee, taxchange.buyBackFee, taxchange.teamFee);
            }
            else if (pollTypes[_pollNum] == PollType.funding) {
                Funding memory funding;
                (,funding,) = getFunding(_pollNum);
                //require(funding.amount <= marketingBalance, "Insufficient Funds");
                ERC20(funding.token).transfer(funding.recipient, funding.amount);
                //marketingBalance -= funding.amount;
            }
            else if (pollTypes[_pollNum] == PollType.setGogeDao) {
                SetGogeDao memory setGogeDao;
                (,setGogeDao,) = getSetGogeDao(_pollNum);
                ERC20(governanceTokenAddr).setGogeDao(setGogeDao.addr);
            }
            else if (pollTypes[_pollNum] == PollType.setCex) {
                SetCex memory setCex;
                (,setCex,) = getSetCex(_pollNum);
                ERC20(governanceTokenAddr).addPartnerOrExchange(setCex.addr);
            }
            else if (pollTypes[_pollNum] == PollType.setDex) {
                SetDex memory setDex;
                (,setDex,) = getSetDex(_pollNum);
                ERC20(governanceTokenAddr).setAutomatedMarketMakerPair(setDex.addr, setDex.boolVar);
            }
            else if (pollTypes[_pollNum] == PollType.excludeFromCirculatingSupply) {
                ExcludeFromCirculatingSupply memory excludeFromCirculatingSupply;
                (,excludeFromCirculatingSupply,) = getExcludeFromCirculatingSupply(_pollNum);
                ERC20(governanceTokenAddr).excludeFromCirculatingSupply(excludeFromCirculatingSupply.addr, excludeFromCirculatingSupply.boolVar);
            }
            else if (pollTypes[_pollNum] == PollType.updateDividendToken) {
                UpdateDividendToken memory updateDividendToken;
                (,updateDividendToken,) = getUpdateDividendToken(_pollNum);
                ERC20(governanceTokenAddr).updateCakeDividendToken(updateDividendToken.addr);
            }
            else if (pollTypes[_pollNum] == PollType.updateMarketingWallet) {
                UpdateMarketingWallet memory updateMarketingWallet;
                (,updateMarketingWallet,) = getUpdateMarketingWallet(_pollNum);
                ERC20(governanceTokenAddr).updateMarketingWallet(updateMarketingWallet.addr);
            }
            else if (pollTypes[_pollNum] == PollType.updateTeamWallet) {
                UpdateTeamWallet memory updateTeamWallet;
                (,updateTeamWallet,) = getUpdateTeamWallet(_pollNum);
                ERC20(governanceTokenAddr).updateTeamWallet(updateTeamWallet.addr);
            }
            else if (pollTypes[_pollNum] == PollType.updateTeamMember) {
                UpdateTeamMember memory updateTeamMember;
                (,updateTeamMember,) = getUpdateTeamMember(_pollNum);
                setTeamMember(updateTeamMember.addr, updateTeamMember.boolVar);
            }
            else if (pollTypes[_pollNum] == PollType.updateVetoAuthority) {
                UpdateVetoAuthority memory updateVetoAuthority;
                (,updateVetoAuthority,) = getUpdateVetoAuthority(_pollNum);
                setVetoAuthority(updateVetoAuthority.addr, updateVetoAuthority.boolVar);
            }
            else if (pollTypes[_pollNum] == PollType.setVetoEnabled) {
                SetVetoEnabled memory setVetoEnabled;
                (,setVetoEnabled,) = getSetVetoEnabled(_pollNum);
                _updateVetoEnabled(setVetoEnabled.boolVar);
            }
            else if (pollTypes[_pollNum] == PollType.setSwapTokensAtAmount) {
                SetSwapTokensAtAmount memory setSwapTokensAtAmount;
                (,setSwapTokensAtAmount,) = getSetSwapTokensAtAmount(_pollNum);
                ERC20(governanceTokenAddr).setSwapTokensAtAmount(setSwapTokensAtAmount.amount);
            }
            else if (pollTypes[_pollNum] == PollType.setBuyBackEnabled) {
                SetBuyBackEnabled memory setBuyBackEnabled;
                (,setBuyBackEnabled,) = getSetBuyBackEnabled(_pollNum);
                ERC20(governanceTokenAddr).setBuyBackEnabled(setBuyBackEnabled.boolVar);
            }
            else if (pollTypes[_pollNum] == PollType.setCakeDividendEnabled) {
                SetCakeDividendEnabled memory setCakeDividendEnabled;
                (,setCakeDividendEnabled,) = getSetCakeDividendEnabled(_pollNum);
                ERC20(governanceTokenAddr).setCakeDividendEnabled(setCakeDividendEnabled.boolVar);
            }
            else if (pollTypes[_pollNum] == PollType.setMarketingEnabled) {
                SetMarketingEnabled memory setMarketingEnabled;
                (,setMarketingEnabled,) = getSetMarketingEnabled(_pollNum);
                ERC20(governanceTokenAddr).setMarketingEnabled(setMarketingEnabled.boolVar);
            }
            else if (pollTypes[_pollNum] == PollType.setTeamEnabled) {
                SetTeamEnabled memory setTeamEnabled;
                (,setTeamEnabled,) = getSetTeamEnabled(_pollNum);
                ERC20(governanceTokenAddr).setTeamEnabled(setTeamEnabled.boolVar);
            }
            else if (pollTypes[_pollNum] == PollType.updateCakeDividendTracker) {
                UpdateCakeDividendTracker memory updateCakeDividendTracker;
                (,updateCakeDividendTracker,) = getUpdateCakeDividendTracker(_pollNum);
                ERC20(governanceTokenAddr).updateCakeDividendTracker(updateCakeDividendTracker.addr);
            }
            else if (pollTypes[_pollNum] == PollType.updateUniswapV2Router) {
                UpdateUniswapV2Router memory updateUniswapV2Router;
                (,updateUniswapV2Router,) = getUpdateUniswapV2Router(_pollNum);
                ERC20(governanceTokenAddr).updateUniswapV2Router(updateUniswapV2Router.addr);
            }
            else if (pollTypes[_pollNum] == PollType.excludeFromFees) {
                ExcludeFromFees memory excludeFromFees;
                (,excludeFromFees,) = getExcludeFromFees(_pollNum);
                ERC20(governanceTokenAddr).excludeFromFees(excludeFromFees.addr, excludeFromFees.boolVar);
            }
            else if (pollTypes[_pollNum] == PollType.excludeFromDividends) {
                ExcludeFromDividends memory excludeFromDividends;
                (,excludeFromDividends,) = getExcludeFromDividends(_pollNum);
                ERC20(governanceTokenAddr).excludeFromDividend(excludeFromDividends.addr);
            }
            else if (pollTypes[_pollNum] == PollType.updateGasForProcessing) {
                UpdateGasForProcessing memory updateGasForProcessing;
                (,updateGasForProcessing,) = getUpdateGasForProcessing(_pollNum);
                ERC20(governanceTokenAddr).updateGasForProcessing(updateGasForProcessing.amount);
            }
            else if (pollTypes[_pollNum] == PollType.updateMinimumBalanceForDividends) {
                UpdateMinimumBalanceForDividends memory updateMinimumBalanceForDividends;
                (,updateMinimumBalanceForDividends,) = getUpdateMinimumBalanceForDividends(_pollNum);
                ERC20(governanceTokenAddr).updateMinimumBalanceForDividends(updateMinimumBalanceForDividends.amount);
            }
            else if (pollTypes[_pollNum] == PollType.modifyBlacklist) {
                ModifyBlacklist memory modifyBlacklist;
                (,modifyBlacklist,) = getModifyBlacklist(_pollNum);
                ERC20(governanceTokenAddr).modifyBlacklist(modifyBlacklist.addr, modifyBlacklist.blacklisted);
            }
            else if (pollTypes[_pollNum] == PollType.transferOwnership) {
                TransferOwnership memory transferOwnership;
                (,transferOwnership,) = getTransferOwnership(_pollNum);
                ERC20(governanceTokenAddr)._transferOwnership(transferOwnership.addr);
            }
            else if (pollTypes[_pollNum] == PollType.migrateTreasury) {
                MigrateTreasury memory migrateTreasury;
                (,migrateTreasury,) = getMigrateTreasury(_pollNum);
                ERC20(migrateTreasury.token).transfer(migrateTreasury.addr, ERC20(migrateTreasury.token).balanceOf(address(this)));
            }
            else if (pollTypes[_pollNum] == PollType.setQuorum) {
                SetQuorum memory setQuorum;
                (,setQuorum,) = getSetQuorum(_pollNum);
                updateQuorum(setQuorum.amount);
            }
            else if (pollTypes[_pollNum] == PollType.setMinPollPeriod) {
                SetMinPollPeriod memory setMinPollPeriod;
                (,setMinPollPeriod,) = getSetMinPollPeriod(_pollNum);
                updateMinPollPeriod(setMinPollPeriod.amount);
            }
            else if (pollTypes[_pollNum] == PollType.updateGovernanceToken) {
                UpdateGovernanceToken memory updateGovernanceToken;
                (,updateGovernanceToken,) = getUpdateGovernanceToken(_pollNum);
                changeGovernanceToken(updateGovernanceToken.addr);
            }

            // refund voters
            refundVotersPostChange(_pollNum);
        }
    }

    /// TODO: NEEDS TESTING
    /// @notice A method for all voters to be refunded after a poll that they've voted on has been passed.
    /// @param  _pollNum The poll number.
    function refundVotersPostChange(uint256 _pollNum) internal {
        for (uint256 i = 0; i < voterLibrary[_pollNum].length; i++) {
            address voter = voterLibrary[_pollNum][i];
            uint256 amnt  = polls[_pollNum][voter];
            ERC20(governanceTokenAddr).transfer(voter, amnt);
        }
    }

    /// @notice A method for a voter to remove their votes from a single poll.
    /// @param  _pollNum The poll number.
    function removeVote(uint256 _pollNum) public {
        uint256 _numVotes = polls[_pollNum][_msgSender()];
        if(_numVotes > 0) {
            polls[_pollNum][_msgSender()] = 0;
            totalVotes[_pollNum] -= _numVotes;
            if (block.timestamp <= pollEndTime[_pollNum]) {
                historicalTally[_pollNum] -= _numVotes;
            }
            require(ERC20(governanceTokenAddr).transfer(_msgSender(), _numVotes));
        }
    }

    /// @notice A method for a voter to remove their votes from all polls.
    function removeAllVotes() public {
        for(uint256 i=0; i<=pollNum; i++) {
            removeVote(i);
        }
    }


    /// @notice A method for a voter to remove their votes from all polls.
    function removeVotesRange(uint256 startPollNum, uint256 endPollNum) public {
        for(uint256 i=startPollNum; i<=endPollNum; i++) {
            removeVote(i);
        }
    }
    
    // ---------- Polls ----------

    /// @notice is used to create a new poll.
    /// @param  _pollType enum type of poll being created.
    /// @param  _change the matching metadata that will result in the execution of the poll.
    function createPoll(PollType _pollType, Metadata memory _change) public {
        _change.time1 = block.timestamp;

        require(_change.time1 < _change.time2, "End time must be later than start time");
        require(_change.time2.sub(_change.time1) >= minPeriod, "Polling period must be greater than 24 hours");

        emit ProposalCreated(pollNum, _pollType, _change.time1, _change.time2);

        pollNum += 1;
        pollTypes[pollNum] = _pollType;
        pollMap[pollNum]   = _change;

        pollStartTime[pollNum] = _change.time1;
        pollEndTime[pollNum]   = _change.time2;
    }

    // ---------- Admin ----------

    function _transferOwnership(address newOwner) public onlyOwner() {
        require(newOwner != address(0));
        super.transferOwnership(newOwner);
    }

    function payTeam() public {
        uint256 amount = teamBalance.div(teamMembers.length);
        for(uint256 i = 0; i < teamMembers.length.sub(1); i++) {
            payable(teamMembers[i]).transfer(amount);
            teamBalance -= amount;
        }
        payable(teamMembers[teamMembers.length.sub(1)]).transfer(teamBalance);
    }

    // ---------- Mutative -----------

    function _updateVetoEnabled(bool enabled) internal {
        require(veto != enabled, "Already set");
        veto = enabled;
        emit VetoEnabledUpdated(enabled);
    }

    function updateVetoEnabled(bool enabled) external onlyOwner() {
        _updateVetoEnabled(enabled);
    }

    function setTeamMember(address addr, bool value) internal {
        if(value) {
            (bool _isTeamMember, ) = isTeamMember(addr);
            if(!_isTeamMember) teamMembers.push(addr);        
        } else {
            (bool _isTeamMember, uint8 s) = isTeamMember(addr);
            if(_isTeamMember){
                teamMembers[s] = teamMembers[teamMembers.length - 1];
                teamMembers.pop();
            } 
        }
    }

    function setVetoAuthority(address addr, bool value) internal {
        require(vetoAuthority[addr] != value, "Already set");
        vetoAuthority[addr] = value;
    }

    function updateQuorum(uint256 amount) internal {
        quorum = amount;
    }

    function updateMinPollPeriod(uint256 amount) internal {
        minPeriod = amount;
    }

    function changeGovernanceToken(address addr) internal {
        governanceTokenAddr = addr;
    }

    function updateTeamBalance(uint256 amount) external {
        require(_msgSender() == governanceTokenAddr, "Not Authorized");
        teamBalance += amount;
    }

    function updateMarketingBalance(uint256 amount) external {
        require(_msgSender() == governanceTokenAddr, "Not Authorized");
        marketingBalance += amount;
    }

    // ---------- Views ----------
    function getHistoricalResults(uint256 _pollNum) public view returns (uint256, PollType, string memory, bool) {
        require(_pollNum <= pollNum, "does not exist");
        return(_pollNum, pollTypes[_pollNum], pollMap[_pollNum].description, passed[_pollNum]);
    }

    function getTaxChange(uint256 _pollNum) public view returns(uint256, TaxChange memory, bool) {
        require(pollTypes[_pollNum] == PollType.taxChange, "Not TaxChange");
        Metadata memory poll = pollMap[_pollNum];
        TaxChange memory taxChange;
        taxChange.description = poll.description;
        taxChange.startTime = poll.time1;
        taxChange.endTime = poll.time2;
        taxChange.cakeDividendsFee = poll.fee1;
        taxChange.marketingFee = poll.fee2;
        taxChange.buyBackFee = poll.fee3;
        taxChange.teamFee = poll.fee4;

        return (historicalTally[_pollNum], taxChange, passed[_pollNum]);
    }

    function getFunding(uint256 _pollNum) public view returns(uint256, Funding memory, bool) {
        require(pollTypes[_pollNum] == PollType.funding, "Not Funding");
        Metadata memory poll = pollMap[_pollNum];
        Funding memory funding;
        funding.description = poll.description;
        funding.startTime = poll.time1;
        funding.endTime = poll.time2;
        funding.recipient = payable(poll.addr1);
        funding.token = poll.addr2;
        funding.amount = poll.amount;

        return (historicalTally[_pollNum], funding, passed[_pollNum]);
    }

    function getSetGogeDao(uint256 _pollNum) public view returns(uint256, SetGogeDao memory, bool) {
        require(pollTypes[_pollNum] == PollType.setGogeDao, "Not SetGogeDao");
        Metadata memory poll = pollMap[_pollNum];
        SetGogeDao memory setGogeDao;
        setGogeDao.description = poll.description;
        setGogeDao.startTime = poll.time1;
        setGogeDao.endTime = poll.time2;
        setGogeDao.addr = poll.addr1;

        return (historicalTally[_pollNum], setGogeDao, passed[_pollNum]);
    }

    function getSetCex(uint256 _pollNum) public view returns(uint256, SetCex memory, bool) {
        require(pollTypes[_pollNum] == PollType.setCex, "Not setCex");
        Metadata memory poll = pollMap[_pollNum];
        SetCex memory setCex;
        setCex.description = poll.description;
        setCex.startTime = poll.time1;
        setCex.endTime = poll.time2;
        setCex.addr = poll.addr1;

        return (historicalTally[_pollNum], setCex, passed[_pollNum]);
    }

    function getSetDex(uint256 _pollNum) public view returns(uint256, SetDex memory, bool) {
        require(pollTypes[_pollNum] == PollType.setDex, "Not setDex");
        Metadata memory poll = pollMap[_pollNum];
        SetDex memory setDex;
        setDex.description = poll.description;
        setDex.startTime = poll.time1;
        setDex.endTime = poll.time2;
        setDex.addr = poll.addr1;
        setDex.boolVar = poll.boolVar;

        return (historicalTally[_pollNum], setDex, passed[_pollNum]);
    }

    function getExcludeFromCirculatingSupply(uint256 _pollNum) public view returns(uint256, ExcludeFromCirculatingSupply memory, bool) {
        require(pollTypes[_pollNum] == PollType.excludeFromCirculatingSupply, "Not excludeFromCirculatingSupply");
        Metadata memory poll = pollMap[_pollNum];
        ExcludeFromCirculatingSupply memory excludeFromCirculatingSupply;
        excludeFromCirculatingSupply.description = poll.description;
        excludeFromCirculatingSupply.startTime = poll.time1;
        excludeFromCirculatingSupply.endTime = poll.time2;
        excludeFromCirculatingSupply.addr = poll.addr1;
        excludeFromCirculatingSupply.boolVar = poll.boolVar;

        return (historicalTally[_pollNum], excludeFromCirculatingSupply, passed[_pollNum]);
    }

    function getUpdateDividendToken(uint256 _pollNum) public view returns(uint256, UpdateDividendToken memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateDividendToken, "Not updateDividendToken");
        Metadata memory poll = pollMap[_pollNum];
        UpdateDividendToken memory updateDividendToken;
        updateDividendToken.description = poll.description;
        updateDividendToken.startTime = poll.time1;
        updateDividendToken.endTime = poll.time2;
        updateDividendToken.addr = poll.addr1;

        return (historicalTally[_pollNum], updateDividendToken, passed[_pollNum]);
    }

    function getUpdateMarketingWallet(uint256 _pollNum) public view returns(uint256, UpdateMarketingWallet memory, bool) {
        require(pollTypes[_pollNum] == PollType.funding, "Not updateMarketingWallet");
        Metadata memory poll = pollMap[_pollNum];
        UpdateMarketingWallet memory updateMarketingWallet;
        updateMarketingWallet.description = poll.description;
        updateMarketingWallet.startTime = poll.time1;
        updateMarketingWallet.endTime = poll.time2;
        updateMarketingWallet.addr = payable(poll.addr1);

        return (historicalTally[_pollNum], updateMarketingWallet, passed[_pollNum]);
    }

    function getUpdateTeamWallet(uint256 _pollNum) public view returns(uint256, UpdateTeamWallet memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateTeamWallet, "Not updateTeamWallet");
        Metadata memory poll = pollMap[_pollNum];
        UpdateTeamWallet memory updateTeamWallet;
        updateTeamWallet.description = poll.description;
        updateTeamWallet.startTime = poll.time1;
        updateTeamWallet.endTime = poll.time2;
        updateTeamWallet.addr = payable(poll.addr1);

        return (historicalTally[_pollNum], updateTeamWallet, passed[_pollNum]);
    }

    function getUpdateTeamMember(uint256 _pollNum) public view returns(uint256, UpdateTeamMember memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateTeamMember, "Not updateTeamMember");
        Metadata memory poll = pollMap[_pollNum];
        UpdateTeamMember memory updateTeamMember;
        updateTeamMember.description = poll.description;
        updateTeamMember.startTime = poll.time1;
        updateTeamMember.endTime = poll.time2;
        updateTeamMember.addr = payable(poll.addr1);
        updateTeamMember.boolVar = poll.boolVar;

        return (historicalTally[_pollNum], updateTeamMember, passed[_pollNum]);
    }

    function isTeamMember(address _address) public view returns(bool, uint8) {
        for (uint8 s = 0; s < teamMembers.length; s += 1){
            if (_address == teamMembers[s]) return (true, s);
        }
        return (false, 0);
    }

    function getUpdateVetoAuthority(uint256 _pollNum) public view returns(uint256, UpdateVetoAuthority memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateVetoAuthority, "Not updateVetoAuthority");
        Metadata memory poll = pollMap[_pollNum];
        UpdateVetoAuthority memory updateVetoAuthority;
        updateVetoAuthority.description = poll.description;
        updateVetoAuthority.startTime = poll.time1;
        updateVetoAuthority.endTime = poll.time2;
        updateVetoAuthority.addr = poll.addr1;
        updateVetoAuthority.boolVar = poll.boolVar;

        return (historicalTally[_pollNum], updateVetoAuthority, passed[_pollNum]);
    }

    function isVetoAuthority(address addr) public view returns(bool) {
        return vetoAuthority[addr];
    }

    function getSetVetoEnabled(uint256 _pollNum) public view returns(uint256, SetVetoEnabled memory, bool) {
        require(pollTypes[_pollNum] == PollType.setVetoEnabled, "Not setVetoEnabled");
        Metadata memory poll = pollMap[_pollNum];
        SetVetoEnabled memory setVetoEnabled;
        setVetoEnabled.description = poll.description;
        setVetoEnabled.startTime = poll.time1;
        setVetoEnabled.endTime = poll.time2;
        setVetoEnabled.boolVar = poll.boolVar;

        return (historicalTally[_pollNum], setVetoEnabled, passed[_pollNum]);  
    }

    function getSetSwapTokensAtAmount(uint256 _pollNum) public view returns(uint256, SetSwapTokensAtAmount memory, bool) {
        require(pollTypes[_pollNum] == PollType.setSwapTokensAtAmount, "Not setSwapTokensAtAmount");
        Metadata memory poll = pollMap[_pollNum];
        SetSwapTokensAtAmount memory setSwapTokensAtAmount;
        setSwapTokensAtAmount.description = poll.description;
        setSwapTokensAtAmount.startTime = poll.time1;
        setSwapTokensAtAmount.endTime = poll.time2;
        setSwapTokensAtAmount.amount = poll.amount;

        return (historicalTally[_pollNum], setSwapTokensAtAmount, passed[_pollNum]);   
    }

    function getSetBuyBackEnabled(uint256 _pollNum) public view returns(uint256, SetBuyBackEnabled memory, bool) {
        require(pollTypes[_pollNum] == PollType.setBuyBackEnabled, "Not setBuyBackEnabled");
        Metadata memory poll = pollMap[_pollNum];
        SetBuyBackEnabled memory setBuyBackEnabled;
        setBuyBackEnabled.description = poll.description;
        setBuyBackEnabled.startTime = poll.time1;
        setBuyBackEnabled.endTime = poll.time2;
        setBuyBackEnabled.boolVar = poll.boolVar;

        return (historicalTally[_pollNum], setBuyBackEnabled, passed[_pollNum]);  
    }

    function getSetCakeDividendEnabled(uint256 _pollNum) public view returns(uint256, SetCakeDividendEnabled memory, bool) {
        require(pollTypes[_pollNum] == PollType.setVetoEnabled, "Not setCakeDividendEnabled");
        Metadata memory poll = pollMap[_pollNum];
        SetCakeDividendEnabled memory setCakeDividendEnabled;
        setCakeDividendEnabled.description = poll.description;
        setCakeDividendEnabled.startTime = poll.time1;
        setCakeDividendEnabled.endTime = poll.time2;
        setCakeDividendEnabled.boolVar = poll.boolVar;

        return (historicalTally[_pollNum], setCakeDividendEnabled, passed[_pollNum]);  
    }

    function getSetMarketingEnabled(uint256 _pollNum) public view returns(uint256, SetMarketingEnabled memory, bool) {
        require(pollTypes[_pollNum] == PollType.setMarketingEnabled, "Not setMarketingEnabled");
        Metadata memory poll = pollMap[_pollNum];
        SetMarketingEnabled memory setMarketingEnabled;
        setMarketingEnabled.description = poll.description;
        setMarketingEnabled.startTime = poll.time1;
        setMarketingEnabled.endTime = poll.time2;
        setMarketingEnabled.boolVar = poll.boolVar;

        return (historicalTally[_pollNum], setMarketingEnabled, passed[_pollNum]);  
    }

    function getSetTeamEnabled(uint256 _pollNum) public view returns(uint256, SetTeamEnabled memory, bool) {
        require(pollTypes[_pollNum] == PollType.setTeamEnabled, "Not setTeamEnabled");
        Metadata memory poll = pollMap[_pollNum];
        SetTeamEnabled memory setTeamEnabled;
        setTeamEnabled.description = poll.description;
        setTeamEnabled.startTime = poll.time1;
        setTeamEnabled.endTime = poll.time2;
        setTeamEnabled.boolVar = poll.boolVar;

        return (historicalTally[_pollNum], setTeamEnabled, passed[_pollNum]);  
    }

    function getUpdateCakeDividendTracker(uint256 _pollNum) public view returns(uint256, UpdateCakeDividendTracker memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateCakeDividendTracker, "Not updateCakeDividendTracker");
        Metadata memory poll = pollMap[_pollNum];
        UpdateCakeDividendTracker memory updateCakeDividendTracker;
        updateCakeDividendTracker.description = poll.description;
        updateCakeDividendTracker.startTime = poll.time1;
        updateCakeDividendTracker.endTime = poll.time2;
        updateCakeDividendTracker.addr = payable(poll.addr1);

        return (historicalTally[_pollNum], updateCakeDividendTracker, passed[_pollNum]);
    }

    function getUpdateUniswapV2Router(uint256 _pollNum) public view returns(uint256, UpdateUniswapV2Router memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateUniswapV2Router, "Not updateUniswapV2Router");
        Metadata memory poll = pollMap[_pollNum];
        UpdateUniswapV2Router memory updateUniswapV2Router;
        updateUniswapV2Router.description = poll.description;
        updateUniswapV2Router.startTime = poll.time1;
        updateUniswapV2Router.endTime = poll.time2;
        updateUniswapV2Router.addr = payable(poll.addr1);

        return (historicalTally[_pollNum], updateUniswapV2Router, passed[_pollNum]);
    }

    function getExcludeFromFees(uint256 _pollNum) public view returns(uint256, ExcludeFromFees memory, bool) {
        require(pollTypes[_pollNum] == PollType.excludeFromFees, "Not excludeFromFees");
        Metadata memory poll = pollMap[_pollNum];
        ExcludeFromFees memory excludeFromFees;
        excludeFromFees.description = poll.description;
        excludeFromFees.startTime = poll.time1;
        excludeFromFees.endTime = poll.time2;
        excludeFromFees.addr = payable(poll.addr1);
        excludeFromFees.boolVar = poll.boolVar;

        return (historicalTally[_pollNum], excludeFromFees, passed[_pollNum]);
    }

    function getExcludeFromDividends(uint256 _pollNum) public view returns(uint256, ExcludeFromDividends memory, bool) {
        require(pollTypes[_pollNum] == PollType.excludeFromDividends, "Not excludeFromDividends");
        Metadata memory poll = pollMap[_pollNum];
        ExcludeFromDividends memory excludeFromDividends;
        excludeFromDividends.description = poll.description;
        excludeFromDividends.startTime = poll.time1;
        excludeFromDividends.endTime = poll.time2;
        excludeFromDividends.addr = payable(poll.addr1);

        return (historicalTally[_pollNum], excludeFromDividends, passed[_pollNum]);
    }

    function getUpdateGasForProcessing(uint256 _pollNum) public view returns(uint256, UpdateGasForProcessing memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateGasForProcessing, "Not updateGasForProcessing");
        Metadata memory poll = pollMap[_pollNum];
        UpdateGasForProcessing memory updateGasForProcessing;
        updateGasForProcessing.description = poll.description;
        updateGasForProcessing.startTime = poll.time1;
        updateGasForProcessing.endTime = poll.time2;
        updateGasForProcessing.amount = poll.amount;

        return (historicalTally[_pollNum], updateGasForProcessing, passed[_pollNum]);   
    }

    function getUpdateMinimumBalanceForDividends(uint256 _pollNum) public view returns(uint256, UpdateMinimumBalanceForDividends memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateMinimumBalanceForDividends, "Not updateMinimumBalanceForDividends");
        Metadata memory poll = pollMap[_pollNum];
        UpdateMinimumBalanceForDividends memory updateMinimumBalanceForDividends;
        updateMinimumBalanceForDividends.description = poll.description;
        updateMinimumBalanceForDividends.startTime = poll.time1;
        updateMinimumBalanceForDividends.endTime = poll.time2;
        updateMinimumBalanceForDividends.amount = poll.amount;

        return (historicalTally[_pollNum], updateMinimumBalanceForDividends, passed[_pollNum]);
    }

    function getModifyBlacklist(uint256 _pollNum) public view returns(uint256, ModifyBlacklist memory, bool) {
        require(pollTypes[_pollNum] == PollType.modifyBlacklist, "Not modifyBlacklist");
        Metadata memory poll = pollMap[_pollNum];
        ModifyBlacklist memory modifyBlacklist;
        modifyBlacklist.description = poll.description;
        modifyBlacklist.startTime = poll.time1;
        modifyBlacklist.endTime = poll.time2;
        modifyBlacklist.addr = payable(poll.addr1);
        modifyBlacklist.blacklisted = poll.boolVar;

        return (historicalTally[_pollNum], modifyBlacklist, passed[_pollNum]);
    }

    function getTransferOwnership(uint256 _pollNum) public view returns(uint256, TransferOwnership memory, bool) {
        require(pollTypes[_pollNum] == PollType.transferOwnership, "Not transferOwnership");
        Metadata memory poll = pollMap[_pollNum];
        TransferOwnership memory transferOwnership;
        transferOwnership.description = poll.description;
        transferOwnership.startTime = poll.time1;
        transferOwnership.endTime = poll.time2;
        transferOwnership.addr = payable(poll.addr1);

        return (historicalTally[_pollNum], transferOwnership, passed[_pollNum]);
    }

    function getMigrateTreasury(uint256 _pollNum) public view returns(uint256, MigrateTreasury memory, bool) {
        require(pollTypes[_pollNum] == PollType.migrateTreasury, "Not migrateTreasury");
        Metadata memory poll = pollMap[_pollNum];
        MigrateTreasury memory migrateTreasury;
        migrateTreasury.description = poll.description;
        migrateTreasury.startTime = poll.time1;
        migrateTreasury.endTime = poll.time2;
        migrateTreasury.addr = payable(poll.addr1);
        migrateTreasury.token = poll.addr2;

        return (historicalTally[_pollNum], migrateTreasury, passed[_pollNum]);   
    }

    function getSetQuorum(uint256 _pollNum) public view returns(uint256, SetQuorum memory, bool) {
        require(pollTypes[_pollNum] == PollType.setQuorum, "Not setQuorum");
        Metadata memory poll = pollMap[_pollNum];
        SetQuorum memory setQuorum;
        setQuorum.description = poll.description;
        setQuorum.startTime = poll.time1;
        setQuorum.endTime = poll.time2;
        setQuorum.amount = poll.amount;

        return (historicalTally[_pollNum], setQuorum, passed[_pollNum]);   
    }

    function getSetMinPollPeriod(uint256 _pollNum) public view returns(uint256, SetMinPollPeriod memory, bool) {
        require(pollTypes[_pollNum] == PollType.setMinPollPeriod, "Not setMinPollPeriod");
        Metadata memory poll = pollMap[_pollNum];
        SetMinPollPeriod memory setMinPollPeriod;
        setMinPollPeriod.description = poll.description;
        setMinPollPeriod.startTime = poll.time1;
        setMinPollPeriod.endTime = poll.time2;
        setMinPollPeriod.amount = poll.amount;

        return (historicalTally[_pollNum], setMinPollPeriod, passed[_pollNum]);   
    }

    function getUpdateGovernanceToken(uint256 _pollNum) public view returns(uint256, UpdateGovernanceToken memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateGovernanceToken, "Not updateGovernanceToken");
        Metadata memory poll = pollMap[_pollNum];
        UpdateGovernanceToken memory updateGovernanceToken;
        updateGovernanceToken.description = poll.description;
        updateGovernanceToken.startTime = poll.time1;
        updateGovernanceToken.endTime = poll.time2;
        updateGovernanceToken.addr = poll.addr1;

        return (historicalTally[_pollNum], updateGovernanceToken, passed[_pollNum]);
    }

    function getOther(uint256 _pollNum) public view returns(uint256, string memory, uint256, uint256, bool) {
        require(pollTypes[_pollNum] == PollType.other, "Not Other");
        Metadata memory poll = pollMap[_pollNum];
        Other memory other;
        other.description = poll.description;
        other.startTime = poll.time1;
        other.endTime = poll.time2;

        return (historicalTally[_pollNum], poll.description, poll.time1, poll.time2, passed[_pollNum]);
    }

    // READ

    function getVotes(address addr, uint256 _pollNum) public view returns (uint256) {
        return polls[_pollNum][addr];
    }

    function getMetadata(uint256 _pollNum) public view returns (Metadata memory) {
        return pollMap[_pollNum];
    }
}
