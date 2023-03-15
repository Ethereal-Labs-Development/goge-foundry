// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import { Owned } from "./extensions/Owned.sol";
import "./extensions/IGogeERC20.sol";

/*
    TODO: Add description
*/

contract GogeDAO is Owned {

    address public governanceTokenAddr;

    uint256 public pollNum;
    uint256 public minPeriod = 86400;
    uint256 public minAuthorBal = 10_000_000 ether;

    uint256 public marketingBalance;
    uint256 public teamBalance;
    uint256 public quorum = 50;

    bool public gateKeeping = true;
    bool public createPollEnabled;

    address [] public teamMembers;
    uint256 [] public activePolls;
    string  [] public actions;
    
    mapping(uint256 => mapping(address => uint256)) public polls;
    mapping(uint256 => address[]) public voterLibrary;
    mapping(uint256 => uint256) public totalVotes;
    mapping(uint256 => uint256) public pollStartTime;
    mapping(uint256 => uint256) public pollEndTime;
    mapping(uint256 => address) public pollAuthor;

    mapping(uint256 => bool) public passed;
    mapping(address => bool) public gateKeeper;
    
    mapping(address => uint256[]) public advocateFor;

    mapping(uint256 => PollType) public pollTypes;
    mapping(uint256 => Metadata) public pollMap;

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
        updateGateKeeper,
        setGateKeeping,
        setBuyBackEnabled,
        setCakeDividendEnabled,
        setMarketingEnabled,
        setTeamEnabled,
        updateCakeDividendTracker,
        updateUniswapV2Router,
        excludeFromFees,
        excludeFromDividends,
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
        uint256 endTime;
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
        uint256 endTime;
        uint8 cakeDividendsFee;
        uint8 marketingFee;
        uint8 buyBackFee;
        uint8 teamFee;
    }

    struct Funding {
        string description;
        uint256 endTime;
        address payable recipient;
        address token;
        uint256 amount;
    }

    struct SetGogeDao {
        string description;
        uint256 endTime;
        address addr;
    }

    struct SetCex {
        string description;
        uint256 endTime;
        address addr; 
    }

    struct SetDex {
        string description;
        uint256 endTime;
        address addr;
        bool boolVar;
    }

    struct ExcludeFromCirculatingSupply {
        string description;
        uint256 endTime;
        address addr;
        bool boolVar;
    }

    struct UpdateDividendToken {
        string description;
        uint256 endTime;
        address addr;
    }

    struct UpdateMarketingWallet {
        string description;
        uint256 endTime;
        address payable addr;
    }

    struct UpdateTeamWallet {
        string description;
        uint256 endTime;
        address payable addr;
    }

    struct UpdateTeamMember {
        string description;
        uint256 endTime;
        address payable addr;
        bool boolVar;
    }

    struct UpdateGateKeeper {
        string description;
        uint256 endTime;
        address addr;
        bool boolVar;  
    }

    struct SetGateKeeping {
        string description;
        uint256 endTime;
        bool boolVar;      
    }

    struct SetBuyBackEnabled {
        string description;
        uint256 endTime;
        bool boolVar;      
    }

    struct SetCakeDividendEnabled {
        string description;
        uint256 endTime;
        bool boolVar;      
    }

    struct SetMarketingEnabled {
        string description;
        uint256 endTime;
        bool boolVar;      
    }

    struct SetTeamEnabled {
        string description;
        uint256 endTime;
        bool boolVar;      
    }

    struct UpdateCakeDividendTracker {
        string description;
        uint256 endTime;
        address payable addr;
    }

    struct UpdateUniswapV2Router {
        string description;
        uint256 endTime;
        address payable addr;
    }

    struct ExcludeFromFees {
        string description;
        uint256 endTime;
        address payable addr;
        bool boolVar;
    }

    struct ExcludeFromDividends {
        string description;
        uint256 endTime;
        address payable addr;
    }

    struct ModifyBlacklist {
        string description;
        uint256 endTime;
        address payable addr;
        bool blacklisted;
    }

    struct TransferOwnership {
        string description;
        uint256 endTime;
        address payable addr;
    }

    struct MigrateTreasury {
        string description;
        uint256 endTime;
        address payable addr;
        address token;
    }

    struct SetQuorum {
        string description;
        uint256 endTime;
        uint256 amount;
    }

    struct SetMinPollPeriod {
        string description;
        uint256 endTime;
        uint256 amount;
    }

    struct UpdateGovernanceToken {
        string description;
        uint256 endTime;
        address addr;
    }

    struct Other {
        string description;
        uint256 endTime;
    }

    event ProposalCreated(uint256 pollNum, PollType pollType, uint256 endTime);
    event ProposalPassed(uint256 pollNum);
    event GateKeepingModified(bool enabled);

    constructor(address _governanceToken) Owned(msg.sender) {
       _setGateKeeper(owner, true);
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
            "updateGateKeeper",
            "setGateKeeping",
            "setBuyBackEnabled",
            "setCakeDividendEnabled",
            "setMarketingEnabled",
            "setTeamEnabled",
            "updateCakeDividendTracker",
            "updateUniswapV2Router",
            "excludeFromFees",
            "excludeFromDividends",
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

    // ---------- Functions ----------

    /// @notice is used to create a new poll.
    /// @param  _pollType enum type of poll being created.
    /// @param  _change the matching metadata that will result in the execution of the poll.
    function createPoll(PollType _pollType, Metadata memory _change) public {
        require(createPollEnabled, "ability to create poll is disabled");
        require(IGogeERC20(governanceTokenAddr).balanceOf(msg.sender) >= minAuthorBal, "Exceeds Balance");

        require(block.timestamp < _change.endTime, "End time must be later than start time");
        require(_change.endTime - block.timestamp >= minPeriod, "Polling period must be greater than 24 hours");

        emit ProposalCreated(pollNum, _pollType, _change.endTime);

        pollNum += 1;

        pollTypes[pollNum]     = _pollType;
        pollMap[pollNum]       = _change;
        pollStartTime[pollNum] = block.timestamp;
        pollEndTime[pollNum]   = _change.endTime;
        pollAuthor[pollNum]    = msg.sender;

        activePolls.push(pollNum);
    }

    /// @notice A method for a voter to add a vote to an existing poll.
    /// @param  _pollNum The poll number.
    /// @param  _numVotes The size of the vote to be created.
    function addVote(uint256 _pollNum, uint256 _numVotes) public {
        require(_pollNum <= pollNum, "Poll doesn't Exist");
        require(block.timestamp >= pollStartTime[_pollNum] && block.timestamp < pollEndTime[_pollNum], "Poll Closed");
        require(isActivePoll(_pollNum), "Poll is not active");

        require(block.timestamp - IGogeERC20(governanceTokenAddr).getLastReceived(msg.sender) >= (5 minutes), "Must wait 5 minutes after purchasing tokens to place any votes.");
        require(IGogeERC20(governanceTokenAddr).balanceOf(msg.sender) >= _numVotes, "Exceeds Balance");
        require(IGogeERC20(governanceTokenAddr).transferFrom(msg.sender, address(this), _numVotes));

        _addToVoterLibrary(_pollNum, msg.sender);
        _addToAdvocateFor(_pollNum, msg.sender);

        polls[_pollNum][msg.sender] += _numVotes;
        totalVotes[_pollNum]        += _numVotes;

        bool quorumMet = getProportion(_pollNum) >= quorum;
        bool enactChange = false;

        if (!gateKeeping && quorumMet) {
            enactChange = true;
        }
        else if (gateKeeper[msg.sender] && quorumMet) {
            enactChange = true;
        }

        if (enactChange) {
            _executeProposal(_pollNum);
        }
    }

    /// @notice A method for a voter to remove their votes from all active polls.
    function removeAllVotes() public {
        for (uint256 i = 0; i < activePolls.length; i++) {
            _removeVote(activePolls[i]);
        }
    }

    /// @notice A method for a voter to remove their votes from a single poll.
    function removeVotesFromPoll(uint256 _pollNum) public {
        require(isActivePoll(_pollNum), "GogeDao.sol::removeVotesFromPoll() poll is not active");
        _removeVote(_pollNum);
    }

    function getVotes(address addr, uint256 _pollNum) public view returns (uint256) {
        return polls[_pollNum][addr];
    }

    function getMetadata(uint256 _pollNum) public view returns (Metadata memory) {
        return pollMap[_pollNum];
    }

    /// @notice Will take the BNB balance within teamBalance and pay team members.
    function payTeam() public {
        uint256 amount = teamBalance / teamMembers.length;
        uint256 l = teamMembers.length - 1;

        if (l > 0) {
            for(uint256 i = 0; i < l; i++) {

                (bool sent,) = teamMembers[i].call{value: amount}("");
                require(sent, "Failed to pay team");

                teamBalance -= amount;
            }
        }

        (bool sent,) = teamMembers[l].call{value: teamBalance}("");
        require(sent, "Failed to pay team");

        teamBalance = 0;
    }

    /// @notice A method for querying all active poll end times, and if poll is expired, remove from ActivePolls.
    /// @dev Should be called on a regular time interval using an external script.
    ///      Solution: https://automation.chain.link/
    function queryEndTime() external {
        uint counter;
        uint256[] memory expired;
        (expired, counter) = _findExpiredPolls();

        for (uint256 i = 0; i < counter; i++) {

            _updateEndTime(expired[i]);
            _removePollFromActivePolls(expired[i]);
            _refundVotersPostChange(expired[i]);
        }
    }

    // ---------- Functions (Permissioned) ----------

    // onlyOwner

    function setGateKeeping(bool enabled) external onlyOwner() {
        _setGateKeeping(enabled);
    }

    function updateGateKeeper(address _account, bool _gateKeeper) external onlyOwner() {
        _setGateKeeper(_account, _gateKeeper);
    }

    function passPoll(uint256 _pollNum) external onlyOwner() {
        require(isActivePoll(_pollNum), "Poll is not active");

        _executeProposal(_pollNum);
    }

    function toggleCreatePollEnabled() external onlyOwner() {
        createPollEnabled = !createPollEnabled;
    }

    function endPoll(uint256 _pollNum) external onlyOwner() {
        require(isActivePoll(_pollNum), "Poll is not active");

        _updateEndTime(_pollNum);
        _removePollFromActivePolls(_pollNum);
        _refundVotersPostChange(_pollNum);
    }

    function updateMinPollPeriod(uint256 amount) external onlyOwner() {
        _updateMinPollPeriod(amount);
    }

    function setTeamMember(address _address, bool _isMember) external onlyOwner() {
        _setTeamMember(_address, _isMember);
    }

    function updateMinAuthorBal(uint256 _amount) external onlyOwner() {
        minAuthorBal = _amount;
    }

    // governanceTokenAddr

    function updateTeamBalance(uint256 amount) external {
        require(msg.sender == governanceTokenAddr, "Not Authorized");
        teamBalance += amount;
    }

    function updateMarketingBalance(uint256 amount) external {
        require(msg.sender == governanceTokenAddr, "Not Authorized");
        marketingBalance += amount;
    }

    // ---------- internal -----------

    /// @notice Internal function for executing a poll.
    /// @param _pollNum Unique poll number.
    function _executeProposal(uint256 _pollNum) internal {

        _updateEndTime(_pollNum);
        passed[_pollNum] = true;

        if (pollTypes[_pollNum] == PollType.taxChange) {
            TaxChange memory taxchange;
            (,taxchange,) = getTaxChange(_pollNum);
            IGogeERC20(governanceTokenAddr).updateFees(taxchange.cakeDividendsFee, taxchange.marketingFee, taxchange.buyBackFee, taxchange.teamFee);
        }
        else if (pollTypes[_pollNum] == PollType.funding) {
            Funding memory funding;
            (,funding,) = getFunding(_pollNum);
            //require(funding.amount <= marketingBalance, "Insufficient Funds");
            IGogeERC20(funding.token).transfer(funding.recipient, funding.amount);
            //marketingBalance -= funding.amount;
        }
        else if (pollTypes[_pollNum] == PollType.setGogeDao) {
            SetGogeDao memory setGogeDao;
            (,setGogeDao,) = getSetGogeDao(_pollNum);
            IGogeERC20(governanceTokenAddr).setGogeDao(setGogeDao.addr);
        }
        else if (pollTypes[_pollNum] == PollType.setCex) {
            SetCex memory setCex;
            (,setCex,) = getSetCex(_pollNum);
            IGogeERC20(governanceTokenAddr).addPartnerOrExchange(setCex.addr);
        }
        else if (pollTypes[_pollNum] == PollType.setDex) {
            SetDex memory setDex;
            (,setDex,) = getSetDex(_pollNum);
            IGogeERC20(governanceTokenAddr).setAutomatedMarketMakerPair(setDex.addr, setDex.boolVar);
        }
        else if (pollTypes[_pollNum] == PollType.excludeFromCirculatingSupply) {
            ExcludeFromCirculatingSupply memory excludeFromCirculatingSupply;
            (,excludeFromCirculatingSupply,) = getExcludeFromCirculatingSupply(_pollNum);
            IGogeERC20(governanceTokenAddr).excludeFromCirculatingSupply(excludeFromCirculatingSupply.addr, excludeFromCirculatingSupply.boolVar);
        }
        else if (pollTypes[_pollNum] == PollType.updateDividendToken) {
            UpdateDividendToken memory updateDividendToken;
            (,updateDividendToken,) = getUpdateDividendToken(_pollNum);
            IGogeERC20(governanceTokenAddr).updateCakeDividendToken(updateDividendToken.addr);
        }
        else if (pollTypes[_pollNum] == PollType.updateMarketingWallet) {
            UpdateMarketingWallet memory updateMarketingWallet;
            (,updateMarketingWallet,) = getUpdateMarketingWallet(_pollNum);
            IGogeERC20(governanceTokenAddr).updateMarketingWallet(updateMarketingWallet.addr);
        }
        else if (pollTypes[_pollNum] == PollType.updateTeamWallet) {
            UpdateTeamWallet memory updateTeamWallet;
            (,updateTeamWallet,) = getUpdateTeamWallet(_pollNum);
            IGogeERC20(governanceTokenAddr).updateTeamWallet(updateTeamWallet.addr);
        }
        else if (pollTypes[_pollNum] == PollType.updateTeamMember) {
            UpdateTeamMember memory updateTeamMember;
            (,updateTeamMember,) = getUpdateTeamMember(_pollNum);
            _setTeamMember(updateTeamMember.addr, updateTeamMember.boolVar);
        }
        else if (pollTypes[_pollNum] == PollType.updateGateKeeper) {
            UpdateGateKeeper memory updateGateKeeper;
            (,updateGateKeeper,) = getUpdateGateKeeper(_pollNum);
            _setGateKeeper(updateGateKeeper.addr, updateGateKeeper.boolVar);
        }
        else if (pollTypes[_pollNum] == PollType.setGateKeeping) {
            SetGateKeeping memory setGateKeeping;
            (,setGateKeeping,) = getSetGateKeeping(_pollNum);
            _setGateKeeping(setGateKeeping.boolVar);
        }
        else if (pollTypes[_pollNum] == PollType.setBuyBackEnabled) {
            SetBuyBackEnabled memory setBuyBackEnabled;
            (,setBuyBackEnabled,) = getSetBuyBackEnabled(_pollNum);
            IGogeERC20(governanceTokenAddr).setBuyBackEnabled(setBuyBackEnabled.boolVar);
        }
        else if (pollTypes[_pollNum] == PollType.setCakeDividendEnabled) {
            SetCakeDividendEnabled memory setCakeDividendEnabled;
            (,setCakeDividendEnabled,) = getSetCakeDividendEnabled(_pollNum);
            IGogeERC20(governanceTokenAddr).setCakeDividendEnabled(setCakeDividendEnabled.boolVar);
        }
        else if (pollTypes[_pollNum] == PollType.setMarketingEnabled) {
            SetMarketingEnabled memory setMarketingEnabled;
            (,setMarketingEnabled,) = getSetMarketingEnabled(_pollNum);
            IGogeERC20(governanceTokenAddr).setMarketingEnabled(setMarketingEnabled.boolVar);
        }
        else if (pollTypes[_pollNum] == PollType.setTeamEnabled) {
            SetTeamEnabled memory setTeamEnabled;
            (,setTeamEnabled,) = getSetTeamEnabled(_pollNum);
            IGogeERC20(governanceTokenAddr).setTeamEnabled(setTeamEnabled.boolVar);
        }
        else if (pollTypes[_pollNum] == PollType.updateCakeDividendTracker) {
            UpdateCakeDividendTracker memory updateCakeDividendTracker;
            (,updateCakeDividendTracker,) = getUpdateCakeDividendTracker(_pollNum);
            IGogeERC20(governanceTokenAddr).updateCakeDividendTracker(updateCakeDividendTracker.addr);
        }
        else if (pollTypes[_pollNum] == PollType.updateUniswapV2Router) {
            UpdateUniswapV2Router memory updateUniswapV2Router;
            (,updateUniswapV2Router,) = getUpdateUniswapV2Router(_pollNum);
            IGogeERC20(governanceTokenAddr).updateUniswapV2Router(updateUniswapV2Router.addr);
        }
        else if (pollTypes[_pollNum] == PollType.excludeFromFees) {
            ExcludeFromFees memory excludeFromFees;
            (,excludeFromFees,) = getExcludeFromFees(_pollNum);
            IGogeERC20(governanceTokenAddr).excludeFromFees(excludeFromFees.addr, excludeFromFees.boolVar);
        }
        else if (pollTypes[_pollNum] == PollType.excludeFromDividends) {
            ExcludeFromDividends memory excludeFromDividends;
            (,excludeFromDividends,) = getExcludeFromDividends(_pollNum);
            IGogeERC20(governanceTokenAddr).excludeFromDividend(excludeFromDividends.addr);
        }
        else if (pollTypes[_pollNum] == PollType.modifyBlacklist) {
            ModifyBlacklist memory modifyBlacklist;
            (,modifyBlacklist,) = getModifyBlacklist(_pollNum);
            IGogeERC20(governanceTokenAddr).modifyBlacklist(modifyBlacklist.addr, modifyBlacklist.blacklisted);
        }
        else if (pollTypes[_pollNum] == PollType.transferOwnership) {
            TransferOwnership memory transferOwnership;
            (,transferOwnership,) = getTransferOwnership(_pollNum);
            IGogeERC20(governanceTokenAddr)._transferOwnership(transferOwnership.addr);
        }
        else if (pollTypes[_pollNum] == PollType.migrateTreasury) {
            MigrateTreasury memory migrateTreasury;
            (,migrateTreasury,) = getMigrateTreasury(_pollNum);
            IGogeERC20(migrateTreasury.token).transfer(migrateTreasury.addr, IGogeERC20(migrateTreasury.token).balanceOf(address(this)));
        }
        else if (pollTypes[_pollNum] == PollType.setQuorum) {
            SetQuorum memory setQuorum;
            (,setQuorum,) = getSetQuorum(_pollNum);
            _updateQuorum(setQuorum.amount);
        }
        else if (pollTypes[_pollNum] == PollType.setMinPollPeriod) {
            SetMinPollPeriod memory setMinPollPeriod;
            (,setMinPollPeriod,) = getSetMinPollPeriod(_pollNum);
            _updateMinPollPeriod(setMinPollPeriod.amount);
        }
        else if (pollTypes[_pollNum] == PollType.updateGovernanceToken) {
            UpdateGovernanceToken memory updateGovernanceToken;
            (,updateGovernanceToken,) = getUpdateGovernanceToken(_pollNum);
            _changeGovernanceToken(updateGovernanceToken.addr);
        }

        // remove poll from active polls and refund voters
        _removePollFromActivePolls(_pollNum);
        _refundVotersPostChange(_pollNum);

        emit ProposalPassed(_pollNum);
    }

    function _findExpiredPolls() internal view returns (uint256[] memory expired, uint256 counter) {
        uint256 l = activePolls.length;
        expired = new uint256[](l);

        for (uint256 i = 0; i < l; i++) {
            uint256 endTime = pollEndTime[activePolls[i]];

            if (block.timestamp >= endTime) {
                expired[counter++] = activePolls[i];
            }
        }
    }

    function _addToVoterLibrary(uint256 _pollNum, address _voter) internal {
        uint256 i = 0;
        bool exists;
        for (; i < voterLibrary[_pollNum].length; i++) {
            if (_voter == voterLibrary[_pollNum][i]) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            voterLibrary[_pollNum].push(_voter);
        }
    }

    function _addToAdvocateFor(uint256 _pollNum, address _advocate) internal {
        uint256 i = 0;
        bool exists;
        for (; i < advocateFor[_advocate].length; i++) {
            if (_pollNum == advocateFor[_advocate][i]) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            advocateFor[_advocate].push(_pollNum);
        }
    }

    /// @notice A method for a voter to remove their votes from a single poll.
    /// @param  _pollNum The poll number.
    function _removeVote(uint256 _pollNum) internal {
        uint256 _numVotes = polls[_pollNum][msg.sender];
        if(_numVotes > 0) {
            polls[_pollNum][msg.sender] = 0;
            totalVotes[_pollNum] -= _numVotes;

            _refundVoter(msg.sender, _numVotes);
            _removeAdvocate(msg.sender, _pollNum);
        }
    }

    /// @notice A method for all voters to be refunded after a poll that they've voted on has been passed.
    /// @param  _pollNum The poll number.
    function _refundVotersPostChange(uint256 _pollNum) internal {
        for (uint256 i = 0; i < voterLibrary[_pollNum].length; i++) {
            address voter  = voterLibrary[_pollNum][i];
            uint256 amount = polls[_pollNum][voter];

            _refundVoter(voter, amount);
            _removeAdvocate(voter, _pollNum);
        }
    }

    function _refundVoter(address _voter, uint256 _amount) internal {
        require(IGogeERC20(governanceTokenAddr).transfer(_voter, _amount));
    }

    /// @notice A method for removing polls from an address's advocatesFor mapped array.
    /// @param _advocate address of wallet that we are removing their advocacy.
    /// @param _pollNum the number of the poll the address is no longer an advocate for.
    function _removeAdvocate(address _advocate, uint256 _pollNum) internal {
        uint256 l = advocateFor[_advocate].length;
        for (uint256 i = 0; i < l; i++) {
            if (advocateFor[_advocate][i] == _pollNum) {
                advocateFor[_advocate][i] = advocateFor[_advocate][--l];
                advocateFor[_advocate].pop();
            }
        }
    }

    function _setGateKeeping(bool _enabled) internal {
        require(gateKeeping != _enabled, "Already set");
        gateKeeping = _enabled;
        emit GateKeepingModified(_enabled);
    }

    function _setTeamMember(address addr, bool value) internal {
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

    function _removePollFromActivePolls(uint256 _pollNum) internal {
        uint256 l = activePolls.length;
        for (uint256 i = 0; i < l; i++) {
            if (_pollNum == activePolls[i]) {
                activePolls[i] = activePolls[--l];
                activePolls.pop();
            }
        }
    }

    function _updateEndTime(uint256 _pollNum) internal {
        pollEndTime[_pollNum] = block.timestamp;
    }

    function _setGateKeeper(address addr, bool value) internal {
        require(gateKeeper[addr] != value, "Already set");
        gateKeeper[addr] = value;
    }

    function _updateQuorum(uint256 amount) internal {
        quorum = amount;
    }

    function _updateMinPollPeriod(uint256 amount) internal {
        minPeriod = amount;
    }

    function _changeGovernanceToken(address addr) internal {
        governanceTokenAddr = addr;
    }

    // ---------- View ----------

    function getProportion(uint256 _pollNum) public view returns (uint256) {
        return totalVotes[_pollNum] * 100 / IGogeERC20(governanceTokenAddr).getCirculatingMinusReserve();
    }

    function isActivePoll(uint256 _pollNum) public view returns (bool active) {
        for (uint8 i = 0; i < activePolls.length; i++){
            if (_pollNum == activePolls[i]) {
                return true;
            }
        }
        return false;
    }

    function isTeamMember(address _address) public view returns(bool, uint8) {
        for (uint8 i = 0; i < teamMembers.length; i += 1){
            if (_address == teamMembers[i]) return (true, i);
        }
        return (false, 0);
    }

    function getActivePolls() external view returns (uint256[] memory) {
        return activePolls;
    }

    function getVoterLibrary(uint256 _pollNum) external view returns (address[] memory) {
        return voterLibrary[_pollNum];
    }

    function getAdvocateFor(address _advocate) external view returns (uint256[] memory) {
        return advocateFor[_advocate];
    }

    function getHistoricalResults(uint256 _pollNum) public view returns (uint256, PollType, string memory, bool) {
        require(_pollNum <= pollNum, "does not exist");
        return(_pollNum, pollTypes[_pollNum], pollMap[_pollNum].description, passed[_pollNum]);
    }

    function getTaxChange(uint256 _pollNum) public view returns(uint256, TaxChange memory, bool) {
        require(pollTypes[_pollNum] == PollType.taxChange, "Not TaxChange");
        Metadata memory poll = pollMap[_pollNum];
        TaxChange memory taxChange;
        taxChange.description = poll.description;
        taxChange.endTime = poll.endTime;
        taxChange.cakeDividendsFee = poll.fee1;
        taxChange.marketingFee = poll.fee2;
        taxChange.buyBackFee = poll.fee3;
        taxChange.teamFee = poll.fee4;

        return (totalVotes[_pollNum], taxChange, passed[_pollNum]);
    }

    function getFunding(uint256 _pollNum) public view returns(uint256, Funding memory, bool) {
        require(pollTypes[_pollNum] == PollType.funding, "Not Funding");
        Metadata memory poll = pollMap[_pollNum];
        Funding memory funding;
        funding.description = poll.description;
        funding.endTime = poll.endTime;
        funding.recipient = payable(poll.addr1);
        funding.token = poll.addr2;
        funding.amount = poll.amount;

        return (totalVotes[_pollNum], funding, passed[_pollNum]);
    }

    function getSetGogeDao(uint256 _pollNum) public view returns(uint256, SetGogeDao memory, bool) {
        require(pollTypes[_pollNum] == PollType.setGogeDao, "Not SetGogeDao");
        Metadata memory poll = pollMap[_pollNum];
        SetGogeDao memory setGogeDao;
        setGogeDao.description = poll.description;
        setGogeDao.endTime = poll.endTime;
        setGogeDao.addr = poll.addr1;

        return (totalVotes[_pollNum], setGogeDao, passed[_pollNum]);
    }

    function getSetCex(uint256 _pollNum) public view returns(uint256, SetCex memory, bool) {
        require(pollTypes[_pollNum] == PollType.setCex, "Not setCex");
        Metadata memory poll = pollMap[_pollNum];
        SetCex memory setCex;
        setCex.description = poll.description;
        setCex.endTime = poll.endTime;
        setCex.addr = poll.addr1;

        return (totalVotes[_pollNum], setCex, passed[_pollNum]);
    }

    function getSetDex(uint256 _pollNum) public view returns(uint256, SetDex memory, bool) {
        require(pollTypes[_pollNum] == PollType.setDex, "Not setDex");
        Metadata memory poll = pollMap[_pollNum];
        SetDex memory setDex;
        setDex.description = poll.description;
        setDex.endTime = poll.endTime;
        setDex.addr = poll.addr1;
        setDex.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], setDex, passed[_pollNum]);
    }

    function getExcludeFromCirculatingSupply(uint256 _pollNum) public view returns(uint256, ExcludeFromCirculatingSupply memory, bool) {
        require(pollTypes[_pollNum] == PollType.excludeFromCirculatingSupply, "Not excludeFromCirculatingSupply");
        Metadata memory poll = pollMap[_pollNum];
        ExcludeFromCirculatingSupply memory excludeFromCirculatingSupply;
        excludeFromCirculatingSupply.description = poll.description;
        excludeFromCirculatingSupply.endTime = poll.endTime;
        excludeFromCirculatingSupply.addr = poll.addr1;
        excludeFromCirculatingSupply.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], excludeFromCirculatingSupply, passed[_pollNum]);
    }

    function getUpdateDividendToken(uint256 _pollNum) public view returns(uint256, UpdateDividendToken memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateDividendToken, "Not updateDividendToken");
        Metadata memory poll = pollMap[_pollNum];
        UpdateDividendToken memory updateDividendToken;
        updateDividendToken.description = poll.description;
        updateDividendToken.endTime = poll.endTime;
        updateDividendToken.addr = poll.addr1;

        return (totalVotes[_pollNum], updateDividendToken, passed[_pollNum]);
    }

    function getUpdateMarketingWallet(uint256 _pollNum) public view returns(uint256, UpdateMarketingWallet memory, bool) {
        require(pollTypes[_pollNum] == PollType.funding, "Not updateMarketingWallet");
        Metadata memory poll = pollMap[_pollNum];
        UpdateMarketingWallet memory updateMarketingWallet;
        updateMarketingWallet.description = poll.description;
        updateMarketingWallet.endTime = poll.endTime;
        updateMarketingWallet.addr = payable(poll.addr1);

        return (totalVotes[_pollNum], updateMarketingWallet, passed[_pollNum]);
    }

    function getUpdateTeamWallet(uint256 _pollNum) public view returns(uint256, UpdateTeamWallet memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateTeamWallet, "Not updateTeamWallet");
        Metadata memory poll = pollMap[_pollNum];
        UpdateTeamWallet memory updateTeamWallet;
        updateTeamWallet.description = poll.description;
        updateTeamWallet.endTime = poll.endTime;
        updateTeamWallet.addr = payable(poll.addr1);

        return (totalVotes[_pollNum], updateTeamWallet, passed[_pollNum]);
    }

    function getUpdateTeamMember(uint256 _pollNum) public view returns(uint256, UpdateTeamMember memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateTeamMember, "Not updateTeamMember");
        Metadata memory poll = pollMap[_pollNum];
        UpdateTeamMember memory updateTeamMember;
        updateTeamMember.description = poll.description;
        updateTeamMember.endTime = poll.endTime;
        updateTeamMember.addr = payable(poll.addr1);
        updateTeamMember.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], updateTeamMember, passed[_pollNum]);
    }

    function getUpdateGateKeeper(uint256 _pollNum) public view returns(uint256, UpdateGateKeeper memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateGateKeeper, "Not updateGateKeeper");
        Metadata memory poll = pollMap[_pollNum];
        UpdateGateKeeper memory updateGateKeeper;
        updateGateKeeper.description = poll.description;
        updateGateKeeper.endTime = poll.endTime;
        updateGateKeeper.addr = poll.addr1;
        updateGateKeeper.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], updateGateKeeper, passed[_pollNum]);
    }

    function getSetGateKeeping(uint256 _pollNum) public view returns(uint256, SetGateKeeping memory, bool) {
        require(pollTypes[_pollNum] == PollType.setGateKeeping, "Not setGateKeeping");
        Metadata memory poll = pollMap[_pollNum];
        SetGateKeeping memory setGateKeeping;
        setGateKeeping.description = poll.description;
        setGateKeeping.endTime = poll.endTime;
        setGateKeeping.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], setGateKeeping, passed[_pollNum]);  
    }

    function getSetBuyBackEnabled(uint256 _pollNum) public view returns(uint256, SetBuyBackEnabled memory, bool) {
        require(pollTypes[_pollNum] == PollType.setBuyBackEnabled, "Not setBuyBackEnabled");
        Metadata memory poll = pollMap[_pollNum];
        SetBuyBackEnabled memory setBuyBackEnabled;
        setBuyBackEnabled.description = poll.description;
        setBuyBackEnabled.endTime = poll.endTime;
        setBuyBackEnabled.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], setBuyBackEnabled, passed[_pollNum]);  
    }

    function getSetCakeDividendEnabled(uint256 _pollNum) public view returns(uint256, SetCakeDividendEnabled memory, bool) {
        require(pollTypes[_pollNum] == PollType.setCakeDividendEnabled, "Not setCakeDividendEnabled");
        Metadata memory poll = pollMap[_pollNum];
        SetCakeDividendEnabled memory setCakeDividendEnabled;
        setCakeDividendEnabled.description = poll.description;
        setCakeDividendEnabled.endTime = poll.endTime;
        setCakeDividendEnabled.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], setCakeDividendEnabled, passed[_pollNum]);  
    }

    function getSetMarketingEnabled(uint256 _pollNum) public view returns(uint256, SetMarketingEnabled memory, bool) {
        require(pollTypes[_pollNum] == PollType.setMarketingEnabled, "Not setMarketingEnabled");
        Metadata memory poll = pollMap[_pollNum];
        SetMarketingEnabled memory setMarketingEnabled;
        setMarketingEnabled.description = poll.description;
        setMarketingEnabled.endTime = poll.endTime;
        setMarketingEnabled.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], setMarketingEnabled, passed[_pollNum]);  
    }

    function getSetTeamEnabled(uint256 _pollNum) public view returns(uint256, SetTeamEnabled memory, bool) {
        require(pollTypes[_pollNum] == PollType.setTeamEnabled, "Not setTeamEnabled");
        Metadata memory poll = pollMap[_pollNum];
        SetTeamEnabled memory setTeamEnabled;
        setTeamEnabled.description = poll.description;
        setTeamEnabled.endTime = poll.endTime;
        setTeamEnabled.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], setTeamEnabled, passed[_pollNum]);  
    }

    function getUpdateCakeDividendTracker(uint256 _pollNum) public view returns(uint256, UpdateCakeDividendTracker memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateCakeDividendTracker, "Not updateCakeDividendTracker");
        Metadata memory poll = pollMap[_pollNum];
        UpdateCakeDividendTracker memory updateCakeDividendTracker;
        updateCakeDividendTracker.description = poll.description;
        updateCakeDividendTracker.endTime = poll.endTime;
        updateCakeDividendTracker.addr = payable(poll.addr1);

        return (totalVotes[_pollNum], updateCakeDividendTracker, passed[_pollNum]);
    }

    function getUpdateUniswapV2Router(uint256 _pollNum) public view returns(uint256, UpdateUniswapV2Router memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateUniswapV2Router, "Not updateUniswapV2Router");
        Metadata memory poll = pollMap[_pollNum];
        UpdateUniswapV2Router memory updateUniswapV2Router;
        updateUniswapV2Router.description = poll.description;
        updateUniswapV2Router.endTime = poll.endTime;
        updateUniswapV2Router.addr = payable(poll.addr1);

        return (totalVotes[_pollNum], updateUniswapV2Router, passed[_pollNum]);
    }

    function getExcludeFromFees(uint256 _pollNum) public view returns(uint256, ExcludeFromFees memory, bool) {
        require(pollTypes[_pollNum] == PollType.excludeFromFees, "Not excludeFromFees");
        Metadata memory poll = pollMap[_pollNum];
        ExcludeFromFees memory excludeFromFees;
        excludeFromFees.description = poll.description;
        excludeFromFees.endTime = poll.endTime;
        excludeFromFees.addr = payable(poll.addr1);
        excludeFromFees.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], excludeFromFees, passed[_pollNum]);
    }

    function getExcludeFromDividends(uint256 _pollNum) public view returns(uint256, ExcludeFromDividends memory, bool) {
        require(pollTypes[_pollNum] == PollType.excludeFromDividends, "Not excludeFromDividends");
        Metadata memory poll = pollMap[_pollNum];
        ExcludeFromDividends memory excludeFromDividends;
        excludeFromDividends.description = poll.description;
        excludeFromDividends.endTime = poll.endTime;
        excludeFromDividends.addr = payable(poll.addr1);

        return (totalVotes[_pollNum], excludeFromDividends, passed[_pollNum]);
    }

    function getModifyBlacklist(uint256 _pollNum) public view returns(uint256, ModifyBlacklist memory, bool) {
        require(pollTypes[_pollNum] == PollType.modifyBlacklist, "Not modifyBlacklist");
        Metadata memory poll = pollMap[_pollNum];
        ModifyBlacklist memory modifyBlacklist;
        modifyBlacklist.description = poll.description;
        modifyBlacklist.endTime = poll.endTime;
        modifyBlacklist.addr = payable(poll.addr1);
        modifyBlacklist.blacklisted = poll.boolVar;

        return (totalVotes[_pollNum], modifyBlacklist, passed[_pollNum]);
    }

    function getTransferOwnership(uint256 _pollNum) public view returns(uint256, TransferOwnership memory, bool) {
        require(pollTypes[_pollNum] == PollType.transferOwnership, "Not transferOwnership");
        Metadata memory poll = pollMap[_pollNum];
        TransferOwnership memory transferOwnership;
        transferOwnership.description = poll.description;
        transferOwnership.endTime = poll.endTime;
        transferOwnership.addr = payable(poll.addr1);

        return (totalVotes[_pollNum], transferOwnership, passed[_pollNum]);
    }

    function getMigrateTreasury(uint256 _pollNum) public view returns(uint256, MigrateTreasury memory, bool) {
        require(pollTypes[_pollNum] == PollType.migrateTreasury, "Not migrateTreasury");
        Metadata memory poll = pollMap[_pollNum];
        MigrateTreasury memory migrateTreasury;
        migrateTreasury.description = poll.description;
        migrateTreasury.endTime = poll.endTime;
        migrateTreasury.addr = payable(poll.addr1);
        migrateTreasury.token = poll.addr2;

        return (totalVotes[_pollNum], migrateTreasury, passed[_pollNum]);   
    }

    function getSetQuorum(uint256 _pollNum) public view returns(uint256, SetQuorum memory, bool) {
        require(pollTypes[_pollNum] == PollType.setQuorum, "Not setQuorum");
        Metadata memory poll = pollMap[_pollNum];
        SetQuorum memory setQuorum;
        setQuorum.description = poll.description;
        setQuorum.endTime = poll.endTime;
        setQuorum.amount = poll.amount;

        return (totalVotes[_pollNum], setQuorum, passed[_pollNum]);   
    }

    function getSetMinPollPeriod(uint256 _pollNum) public view returns(uint256, SetMinPollPeriod memory, bool) {
        require(pollTypes[_pollNum] == PollType.setMinPollPeriod, "Not setMinPollPeriod");
        Metadata memory poll = pollMap[_pollNum];
        SetMinPollPeriod memory setMinPollPeriod;
        setMinPollPeriod.description = poll.description;
        setMinPollPeriod.endTime = poll.endTime;
        setMinPollPeriod.amount = poll.amount;

        return (totalVotes[_pollNum], setMinPollPeriod, passed[_pollNum]);   
    }

    function getUpdateGovernanceToken(uint256 _pollNum) public view returns(uint256, UpdateGovernanceToken memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateGovernanceToken, "Not updateGovernanceToken");
        Metadata memory poll = pollMap[_pollNum];
        UpdateGovernanceToken memory updateGovernanceToken;
        updateGovernanceToken.description = poll.description;
        updateGovernanceToken.endTime = poll.endTime;
        updateGovernanceToken.addr = poll.addr1;

        return (totalVotes[_pollNum], updateGovernanceToken, passed[_pollNum]);
    }

    function getOther(uint256 _pollNum) public view returns(uint256, string memory, uint256, bool) {
        require(pollTypes[_pollNum] == PollType.other, "Not Other");
        Metadata memory poll = pollMap[_pollNum];
        Other memory other;
        other.description = poll.description;
        other.endTime = poll.endTime;

        return (totalVotes[_pollNum], poll.description, poll.endTime, passed[_pollNum]);
    }
    
}
