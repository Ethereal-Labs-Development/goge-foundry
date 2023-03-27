// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import { Owned } from "./extensions/Owned.sol";
import "./extensions/IGogeERC20.sol";

/// @title Gay Doge Dao Contract.
/// @notice This contract is a governance contract which acts as a layer that sits on top of a governance token. This contract allows holders of the governance token
///         to create proposals of a chosen pollType. Each pollType has unique parameters which, if passes quorum, will result in a function call to the governance token.
/// @author Chase Brown
contract GogeDAO is Owned {

    // ---------------
    // State Variables
    // ---------------

    /// @notice Contract address of governance token.
    address public governanceTokenAddr;
    
    /// @notice Unique identifier of each poll that is created.
    uint256 public pollNum;
    /// @notice The minimum time needed for a new poll -> default is 24 hours or 86400 seconds.
    uint256 public minPeriod = 1 days;
    /// @notice The minimum balance of governance token the author of a poll must be holding at the time of creation.
    uint256 public minAuthorBal = 10_000_000 ether;
    /// @notice The maximum amount of polls an author can have active at any given time.
    uint8   public maxPollsPerAuthor = 1;
    /// @notice The threshold that must be met to pass a poll
    uint256 public quorum = 50;

    /// @notice Amount of BNB held for marketing purposes.
    uint256 public marketingBalance;
    /// @notice Amount of BNB held for team pay
    uint256 public teamBalance;

    /// @notice Bool if gate keeping is enabled.
    bool public gatekeeping = true;
    /// @notice Bool if createPoll is callable.
    bool public createPollEnabled;

    /// @notice Array of team member addresses.
    address [] public teamMembers;
    /// @notice Array of active polls -> array of poll nums.
    uint256 [] public activePolls;
    /// @notice Array of poll types as strings.
    string  [] public actions;
    
    /// @notice Double Mapping of pollNum to amount of votes per voter.
    mapping(uint256 => mapping(address => uint256)) public polls;
    /// @notice Mapping of pollNum to array of addresses of voters
    mapping(uint256 => address[]) public voterLibrary;
    /// @notice Mapping of pollNum to amount of total votes per poll.
    mapping(uint256 => uint256) public totalVotes;
    /// @notice Mapping of pollNum to starting timestamp.
    mapping(uint256 => uint256) public pollStartTime;
    /// @notice Mapping of pollNum to ending timestamp (expiration date).
    mapping(uint256 => uint256) public pollEndTime;
    /// @notice Mapping of pollNum to poll author's address.
    mapping(uint256 => address) public pollAuthor;

    /// @notice Mapping of pollNum to whether or not a poll has been passed (bool).
    mapping(uint256 => bool) public passed;
    /// @notice Mapping of address to whether or not it is a gate keeper.
    mapping(address => bool) public gatekeeper;
    
    /// @notice Mapping of address to array of pollNums it has outstanding votes for.
    mapping(address => uint256[]) public advocateFor;

    /// @notice Mapping of pollNum to it's specified pollType.
    mapping(uint256 => PollType) public pollTypes;
    /// @notice Mapping of pollNum to it's specified metadata.
    mapping(uint256 => Metadata) public pollMap;

    /// @notice enum of all pollTypes which correspond with it's index in the actions array.
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
        updateGatekeeper,
        setGatekeeping,
        setBuyBackEnabled,
        setCakeDividendEnabled,
        setMarketingEnabled,
        setTeamEnabled,
        excludeFromFees,
        excludeFromDividends,
        modifyBlacklist,
        transferOwnership,
        migrateTreasury,
        setQuorum,
        updateGovernanceToken,
        other
    }

    // -------- Poll Structs -----------

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

    /// @notice Poll type to propose withdrawing ERC20 tokens from this contract.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    /// @param  addr recipient of tokens.
    /// @param  token address of tokens to withdraw.
    /// @dev    Will result in the transfer of funds from address(this) to a recipient.
    struct MigrateTreasury {
        string description;
        uint256 endTime;
        address payable addr;
        address token;
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

    /// @notice Poll type to propose an arbitrary proposal.
    /// @param  description proposal description.
    /// @param  endTime unix timestamp of poll expiration date.
    struct Other {
        string description;
        uint256 endTime;
    }


    // -----------
    // Constructor
    // -----------

    /// @notice Initializes GogeDao.sol
    /// @param _governanceToken address of governance token.
    constructor(
        address _governanceToken
    )
        Owned(msg.sender)
    {
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
            "excludeFromFees",
            "excludeFromDividends",
            "modifyBlacklist",
            "transferOwnership",
            "migrateTreasury",
            "setQuorum",
            "updateGovernanceToken",
            "other"
        ];
    }


    // ---------
    // Modifiers
    // ---------

    /// @notice Modifier for permissioned functions excluding wallets except owner and poll author.
    modifier onlyOwnerOrAuthor(uint256 _pollNum) {
        require(msg.sender == owner || msg.sender == pollAuthor[_pollNum], "UNAUTHORIZED");
        _;
    }


    // ------
    // Events
    // ------

    /// @notice Emitted when a new poll is created.
    event ProposalCreated(uint256 pollNum, PollType pollType, uint256 endTime);
    /// @notice Emitted when a poll has been passed.
    event ProposalPassed(uint256 pollNum);
    /// @notice Emitted when the status of gateKeeping is updated.
    event GateKeepingModified(bool enabled);


    // ---------
    // Functions
    // ---------

    /// @notice Utility function so this contract can accept BNB.
    receive() payable external {}

    /// @notice is used to create a new poll.
    /// @param  _pollType enum type of poll being created.
    /// @param  _change the matching metadata that will result in the execution of the poll.
    function createPoll(PollType _pollType, Metadata memory _change) external {        
        require(createPollEnabled, "GogeDao.sol::createPoll() Ability to create poll is disabled");
        if (msg.sender != owner) require(getActivePollsFromAuthor(msg.sender) < maxPollsPerAuthor, "GogeDao.sol::createPoll() Exceeds maxPollsPerAuthor");
        require(block.timestamp < _change.endTime, "GogeDao.sol::createPoll() End time must be later than start time");
        require(_change.endTime - block.timestamp >= minPeriod, "GogeDao.sol::createPoll() Polling period must be greater than 24 hours");

        require(IGogeERC20(governanceTokenAddr).balanceOf(msg.sender) >= minAuthorBal, "GogeDao.sol::createPoll() Insufficient balance of tokens");
        require(IGogeERC20(governanceTokenAddr).transferFrom(msg.sender, address(this), minAuthorBal));

        pollNum += 1;

        emit ProposalCreated(pollNum, _pollType, _change.endTime);

        _addToVoterLibrary(pollNum, msg.sender);
        _addToAdvocateFor(pollNum, msg.sender);

        polls[pollNum][msg.sender] += minAuthorBal;
        totalVotes[pollNum]        += minAuthorBal;

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
    function addVote(uint256 _pollNum, uint256 _numVotes) external {
        require(block.timestamp >= pollStartTime[_pollNum] && block.timestamp < pollEndTime[_pollNum], "GogeDao.sol::addVote() Poll Closed");
        require(isActivePoll(_pollNum), "GogeDao.sol::addVote() Poll is not active");

        require(block.timestamp - IGogeERC20(governanceTokenAddr).getLastReceived(msg.sender) >= (5 minutes), "GogeDao.sol::addVote() Must wait 5 minutes after purchasing tokens to place any votes.");
        require(IGogeERC20(governanceTokenAddr).balanceOf(msg.sender) >= _numVotes, "GogeDao.sol::addVote() Exceeds Balance");
        require(IGogeERC20(governanceTokenAddr).transferFrom(msg.sender, address(this), _numVotes));

        _addToVoterLibrary(_pollNum, msg.sender);
        _addToAdvocateFor(_pollNum, msg.sender);

        polls[_pollNum][msg.sender] += _numVotes;
        totalVotes[_pollNum]        += _numVotes;

        bool quorumMet = getProportion(_pollNum) >= quorum;

        if((gatekeeper[msg.sender] || !gatekeeping) && quorumMet) {
            _executeProposal(_pollNum);
        }
    }

    /// @notice A method for a voter to remove their votes from all active polls.
    function removeAllVotes() external {
        uint256 len = activePolls.length;
        for (uint256 i; i < len;) {
            _removeVote(activePolls[i]);
            unchecked {
                i = i + 1;
            }
        }
    }

    /// @notice A method for a voter to remove their votes from a single poll.
    /// @param _pollNum unique poll identifier.
    function removeVotesFromPoll(uint256 _pollNum) external {
        require(isActivePoll(_pollNum), "GogeDao.sol::removeVotesFromPoll() poll is not active");
        _removeVote(_pollNum);
    }

    /// @notice Will take the BNB balance within teamBalance and pay team members.
    function payTeam() public {
        require(teamMembers.length > 0, "GogeDao.sol::payTeam() No team members inside teamMembers array");

        uint256 amount = teamBalance / teamMembers.length;
        uint256 len = teamMembers.length - 1;

        if (len > 0) {
            for(uint256 i; i < len;) {

                (bool sent,) = teamMembers[i].call{value: amount}("");
                require(sent, "Failed to pay team");

                teamBalance -= amount;

                unchecked {
                    i = i + 1;
                }
            }
        }

        (bool sent,) = teamMembers[len].call{value: teamBalance}("");
        require(sent, "Failed to pay team");

        teamBalance = 0;
    }

    /// @notice A method for querying all active poll end times, and if poll is expired, remove from ActivePolls.
    /// @dev Should be called on a regular time interval using an external script.
    ///      Solution: https://automation.chain.link/
    function queryEndTime() external {
        uint counter;
        uint256[] memory expired;
        (expired, counter) = findExpiredPolls();

        for (uint256 i; i < counter;) {

            _updateEndTime(expired[i]);
            _removePoll(expired[i]);
            _refundVoters(expired[i]);

            unchecked {
                i = i + 1;
            }
        }
    }


    // ------------------------
    // Functions (Permissioned)
    // ------------------------

    // NOTE: onlyOwner

    /// @notice An owner method for updating status of gateKeeping.
    /// @param  _enabled status of gateKeeping.
    function setGateKeeping(bool _enabled) external onlyOwner() {
        _setGateKeeping(_enabled);
    }

    /// @notice An owner method for updating quorum.
    /// @param  _amount new quourum.
    function updateQuorum(uint256 _amount) external onlyOwner() {
        _updateQuorum(_amount);
    }

    /// @notice An owner method for adding new gate keeper addresses.
    /// @param  _account new gate keeper.
    /// @param  _gateKeeper is a gate keeper.
    function updateGateKeeper(address _account, bool _gateKeeper) external onlyOwner() {
        _setGateKeeper(_account, _gateKeeper);
    }

    /// @notice An owner method for manually passing a poll.
    /// @param  _pollNum unique poll identifier.
    /// @dev    poll must be an active poll
    function passPoll(uint256 _pollNum) external onlyOwner() {
        require(isActivePoll(_pollNum), "Poll is not active");
        _executeProposal(_pollNum);
    }

    /// @notice An owner method for updating status of createPoll.
    function toggleCreatePollEnabled() external onlyOwner() {
        createPollEnabled = !createPollEnabled;
    }

    /// @notice An owner method for manually ending a poll.
    /// @param  _pollNum unique poll identifier.
    /// @dev    Poll must be an active poll.
    ///         This function is also callable by the author of _pollNum.
    function endPoll(uint256 _pollNum) external onlyOwnerOrAuthor(_pollNum) {
        require(isActivePoll(_pollNum), "Poll is not active");
        _updateEndTime(_pollNum);
        _removePoll(_pollNum);
        _refundVoters(_pollNum);
    }

    /// @notice An owner method for updating minPollPeriod.
    /// @param  _amount new minPollPeriod.
    function updateMinPollPeriod(uint256 _amount) external onlyOwner() {
        minPeriod = _amount;
    }

    /// @notice An owner method for adding new team member.
    /// @param  _account new team member.
    /// @param  _isMember is a team member.
    function setTeamMember(address _account, bool _isMember) external onlyOwner() {
        _setTeamMember(_account, _isMember);
    }

    /// @notice An owner method for updating minAuthorBal.
    /// @param  _amount new min balance of a poll author.
    function updateMinAuthorBal(uint256 _amount) external onlyOwner() {
        minAuthorBal = _amount;
    }

    /// @notice An owner method for updating maxPollsPerAuthor.
    /// @param  _limit amount of active polls an author can have at any given time.
    function updateMaxPollsPerAuthor(uint8 _limit) external onlyOwner() {
        maxPollsPerAuthor = _limit;
    }

    // NOTE: governanceTokenAddr

    /// @notice A method for updating team balance.
    /// @param  _amount amount of BNB to add to teamBalance.
    /// @dev    Only callable by governanceTokenAddr
    function updateTeamBalance(uint256 _amount) external {
        require(msg.sender == governanceTokenAddr, "Not Authorized");
        teamBalance += _amount;
    }

    /// @notice A method for updating marketing balance.
    /// @param  _amount amount of BNB to add to marketingBalanace.
    /// @dev    Only callable by governanceTokenAddr
    function updateMarketingBalance(uint256 _amount) external {
        require(msg.sender == governanceTokenAddr, "Not Authorized");
        marketingBalance += _amount;
    }

    // --------
    // Internal
    // --------

    /// @notice Internal function for executing a poll.
    /// @param _pollNum Unique poll number.
    function _executeProposal(uint256 _pollNum) internal {

        _updateEndTime(_pollNum);
        passed[_pollNum] = true;

        PollType _pollType = pollTypes[_pollNum];

        if (_pollType == PollType.taxChange) {
            TaxChange memory taxchange;
            (,taxchange,) = getTaxChange(_pollNum);
            IGogeERC20(governanceTokenAddr).updateFees(taxchange.cakeDividendsFee, taxchange.marketingFee, taxchange.buyBackFee, taxchange.teamFee);
        }
        else if (_pollType == PollType.funding) {
            Funding memory funding;
            (,funding,) = getFunding(_pollNum);
            require(funding.amount <= marketingBalance, "Insufficient Funds");
            (bool success,) = funding.recipient.call{value: funding.amount}("");
            require(success, "call unsuccessful");
            marketingBalance -= funding.amount;
        }
        else if (_pollType == PollType.setGogeDao) {
            SetGogeDao memory setGogeDao;
            (,setGogeDao,) = getSetGogeDao(_pollNum);
            IGogeERC20(governanceTokenAddr).setGogeDao(setGogeDao.addr);
        }
        else if (_pollType == PollType.setCex) {
            SetCex memory setCex;
            (,setCex,) = getSetCex(_pollNum);
            IGogeERC20(governanceTokenAddr).addPartnerOrExchange(setCex.addr);
        }
        else if (_pollType == PollType.setDex) {
            SetDex memory setDex;
            (,setDex,) = getSetDex(_pollNum);
            IGogeERC20(governanceTokenAddr).setAutomatedMarketMakerPair(setDex.addr, setDex.boolVar);
        }
        else if (_pollType == PollType.excludeFromCirculatingSupply) {
            ExcludeFromCirculatingSupply memory excludeFromCirculatingSupply;
            (,excludeFromCirculatingSupply,) = getExcludeFromCirculatingSupply(_pollNum);
            IGogeERC20(governanceTokenAddr).excludeFromCirculatingSupply(excludeFromCirculatingSupply.addr, excludeFromCirculatingSupply.boolVar);
        }
        else if (_pollType == PollType.updateDividendToken) {
            UpdateDividendToken memory updateDividendToken;
            (,updateDividendToken,) = getUpdateDividendToken(_pollNum);
            IGogeERC20(governanceTokenAddr).updateCakeDividendToken(updateDividendToken.addr);
        }
        else if (_pollType == PollType.updateMarketingWallet) {
            UpdateMarketingWallet memory updateMarketingWallet;
            (,updateMarketingWallet,) = getUpdateMarketingWallet(_pollNum);
            IGogeERC20(governanceTokenAddr).updateMarketingWallet(updateMarketingWallet.addr);
        }
        else if (_pollType == PollType.updateTeamWallet) {
            UpdateTeamWallet memory updateTeamWallet;
            (,updateTeamWallet,) = getUpdateTeamWallet(_pollNum);
            IGogeERC20(governanceTokenAddr).updateTeamWallet(updateTeamWallet.addr);
        }
        else if (_pollType == PollType.updateTeamMember) {
            UpdateTeamMember memory updateTeamMember;
            (,updateTeamMember,) = getUpdateTeamMember(_pollNum);
            _setTeamMember(updateTeamMember.addr, updateTeamMember.boolVar);
        }
        else if (_pollType == PollType.updateGatekeeper) {
            UpdateGatekeeper memory modifyGateKeeper;
            (,modifyGateKeeper,) = getUpdateGateKeeper(_pollNum);
            _setGateKeeper(modifyGateKeeper.addr, modifyGateKeeper.boolVar);
        }
        else if (_pollType == PollType.setGatekeeping) {
            SetGatekeeping memory modifyGateKeeping;
            (,modifyGateKeeping,) = getSetGateKeeping(_pollNum);
            _setGateKeeping(modifyGateKeeping.boolVar);
        }
        else if (_pollType == PollType.setBuyBackEnabled) {
            SetBuyBackEnabled memory setBuyBackEnabled;
            (,setBuyBackEnabled,) = getSetBuyBackEnabled(_pollNum);
            IGogeERC20(governanceTokenAddr).setBuyBackEnabled(setBuyBackEnabled.boolVar);
        }
        else if (_pollType == PollType.setCakeDividendEnabled) {
            SetCakeDividendEnabled memory setCakeDividendEnabled;
            (,setCakeDividendEnabled,) = getSetCakeDividendEnabled(_pollNum);
            IGogeERC20(governanceTokenAddr).setCakeDividendEnabled(setCakeDividendEnabled.boolVar);
        }
        else if (_pollType == PollType.setMarketingEnabled) {
            SetMarketingEnabled memory setMarketingEnabled;
            (,setMarketingEnabled,) = getSetMarketingEnabled(_pollNum);
            IGogeERC20(governanceTokenAddr).setMarketingEnabled(setMarketingEnabled.boolVar);
        }
        else if (_pollType == PollType.setTeamEnabled) {
            SetTeamEnabled memory setTeamEnabled;
            (,setTeamEnabled,) = getSetTeamEnabled(_pollNum);
            IGogeERC20(governanceTokenAddr).setTeamEnabled(setTeamEnabled.boolVar);
        }
        else if (_pollType == PollType.excludeFromFees) {
            ExcludeFromFees memory excludeFromFees;
            (,excludeFromFees,) = getExcludeFromFees(_pollNum);
            IGogeERC20(governanceTokenAddr).excludeFromFees(excludeFromFees.addr, excludeFromFees.boolVar);
        }
        else if (_pollType == PollType.excludeFromDividends) {
            ExcludeFromDividends memory excludeFromDividends;
            (,excludeFromDividends,) = getExcludeFromDividends(_pollNum);
            IGogeERC20(governanceTokenAddr).excludeFromDividend(excludeFromDividends.addr);
        }
        else if (_pollType == PollType.modifyBlacklist) {
            ModifyBlacklist memory modifyBlacklist;
            (,modifyBlacklist,) = getModifyBlacklist(_pollNum);
            IGogeERC20(governanceTokenAddr).modifyBlacklist(modifyBlacklist.addr, modifyBlacklist.blacklisted);
        }
        else if (_pollType == PollType.transferOwnership) {
            TransferOwnership memory transferOwnership;
            (,transferOwnership,) = getTransferOwnership(_pollNum);
            IGogeERC20(governanceTokenAddr)._transferOwnership(transferOwnership.addr);
        }
        else if (_pollType == PollType.migrateTreasury) {
            MigrateTreasury memory migrateTreasury;
            (,migrateTreasury,) = getMigrateTreasury(_pollNum);
            IGogeERC20(migrateTreasury.token).transfer(migrateTreasury.addr, IGogeERC20(migrateTreasury.token).balanceOf(address(this)));
        }
        else if (_pollType == PollType.setQuorum) {
            SetQuorum memory setQuorum;
            (,setQuorum,) = getSetQuorum(_pollNum);
            _updateQuorum(setQuorum.amount);
        }
        else if (_pollType == PollType.updateGovernanceToken) {
            UpdateGovernanceToken memory updateGovernanceToken;
            (,updateGovernanceToken,) = getUpdateGovernanceToken(_pollNum);

            _removePoll(_pollNum);
            _refundVoters(_pollNum);

            _changeGovernanceToken(updateGovernanceToken.addr);
            emit ProposalPassed(_pollNum);

            return;
        }

        // remove poll from active polls and refund voters
        _removePoll(_pollNum);
        _refundVoters(_pollNum);

        emit ProposalPassed(_pollNum);
    }

    /// @notice Internal method for adding voters to voterLibrary.
    /// @param  _pollNum unique identifier for a poll.
    /// @param  _voter address to add to voter library array.
    function _addToVoterLibrary(uint256 _pollNum, address _voter) internal {
        uint256 length = voterLibrary[_pollNum].length;
        for (uint256 i; i < length;) {
            if (_voter == voterLibrary[_pollNum][i]) {
                return;
            }
            unchecked {
                i = i + 1;
            }
        }
        voterLibrary[_pollNum].push(_voter);
    }

    /// @notice Internal method for adding polls to advocateFor.
    /// @param  _pollNum unique identifier for a poll.
    /// @param  _advocate address of advocate.
    function _addToAdvocateFor(uint256 _pollNum, address _advocate) internal {
        uint256 length = advocateFor[_advocate].length;
        for (uint256 i; i < length;) {
            if (_pollNum == advocateFor[_advocate][i]) {
                return;
            }
            unchecked {
                i = i + 1;
            }
        }
        advocateFor[_advocate].push(_pollNum);
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
    function _refundVoters(uint256 _pollNum) internal {
        for (uint256 i = 0; i < voterLibrary[_pollNum].length; i++) {
            address voter  = voterLibrary[_pollNum][i];
            uint256 amount = polls[_pollNum][voter];

            _refundVoter(voter, amount);
            _removeAdvocate(voter, _pollNum);
        }
    }

    /// @notice Internal method for transferring governance tokens to a voter.
    /// @param  _voter address of voter that needs to be refunded.
    /// @param _amount amount of tokens to refund voter.
    function _refundVoter(address _voter, uint256 _amount) internal {
        require(IGogeERC20(governanceTokenAddr).transfer(_voter, _amount));
    }

    /// @notice A method for removing polls from an address's advocatesFor mapped array.
    /// @param _advocate address of wallet that we are removing their advocacy.
    /// @param _pollNum the number of the poll the address is no longer an advocate for.
    function _removeAdvocate(address _advocate, uint256 _pollNum) internal {
        uint256 l = advocateFor[_advocate].length;
        for (uint256 i; i < l;) {
            if (advocateFor[_advocate][i] == _pollNum) {
                advocateFor[_advocate][i] = advocateFor[_advocate][--l];
                advocateFor[_advocate].pop();
            }
            unchecked {
                i = i + 1;
            }
        }
    }

    /// @notice An internal method for changing gateKeeping status.
    /// @param _enabled status of gateKeeping.
    function _setGateKeeping(bool _enabled) internal {
        require(gatekeeping != _enabled, "Already set");
        gatekeeping = _enabled;
        emit GateKeepingModified(_enabled);
    }

    /// @notice An internal method for adding a team member address to the teamMembers array.
    /// @param  _addr address of team member.
    /// @param  _value is a team member.
    function _setTeamMember(address _addr, bool _value) internal {
        if(_value) {
            (bool _isTeamMember, ) = isTeamMember(_addr);
            if(!_isTeamMember) teamMembers.push(_addr);        
        } else {
            (bool _isTeamMember, uint8 s) = isTeamMember(_addr);
            if(_isTeamMember){
                teamMembers[s] = teamMembers[teamMembers.length - 1];
                teamMembers.pop();
            } 
        }
    }

    /// @notice An internal method for removing a poll from activePolls array.
    /// @param _pollNum unique identifier for a poll.
    function _removePoll(uint256 _pollNum) internal {
        uint256 l = activePolls.length;
        for (uint256 i; i < l;) {
            if (_pollNum == activePolls[i]) {
                activePolls[i] = activePolls[--l];
                activePolls.pop();
            }
            unchecked {
                i = i + 1;
            }
        }
    }

    /// @notice An internal method for updating a poll's end unix to current block.timestamp.
    /// @param  _pollNum unique poll identifier.
    function _updateEndTime(uint256 _pollNum) internal {
        pollEndTime[_pollNum] = block.timestamp;
    }

    /// @notice An internal method for setting the status of a gate keeper.
    /// @param  _addr address of gate keeper.
    /// @param  _value is a gate keeper.
    function _setGateKeeper(address _addr, bool _value) internal {
        require(gatekeeper[_addr] != _value, "Already set");
        gatekeeper[_addr] = _value;
    }

    /// @notice An internal method for updating quorum value.
    /// @param  _amount quorum value.
    function _updateQuorum(uint256 _amount) internal {
        require(_amount <= 100 && _amount > 0, "_amount must be between 0 and 100");
        quorum = _amount;
    }

    /// @notice An internal method for updating governanceTokenAddr.
    /// @param  _addr new governance token address.
    function _changeGovernanceToken(address _addr) internal {
        governanceTokenAddr = _addr;
    }

    // ----
    // View
    // ----

    /// @notice A view method for returning the amount of votes of a voter in a poll.
    /// @param  _addr address of voter.
    /// @param _pollNum unique poll identifier.
    function getVotes(address _addr, uint256 _pollNum) public view returns (uint256) {
        return polls[_pollNum][_addr];
    }

    /// @notice A view method for returning a poll's unique metadata.
    /// @param _pollNum unique poll identifier.
    function getMetadata(uint256 _pollNum) public view returns (Metadata memory) {
        return pollMap[_pollNum];
    }

    /// @notice A view method for returning a poll's current proportion of votes over circuating supply.
    /// @param _pollNum unique poll identifier.
    function getProportion(uint256 _pollNum) public view returns (uint256) {
        return totalVotes[_pollNum] * 100 / IGogeERC20(governanceTokenAddr).getCirculatingMinusReserve();
    }

    /// @notice A view method for returning the current polls (by pollNum) are active, but expired.
    /// @return expired array of pollNums that are active, but expired.
    /// @return counter the amount of polls that are active, but expired.
    function findExpiredPolls() public view returns (uint256[] memory expired, uint256 counter) {
        uint256 l = activePolls.length;
        expired = new uint256[](l);

        for (uint256 i; i < l;) {
            uint256 endTime = pollEndTime[activePolls[i]];

            if (block.timestamp >= endTime) {
                expired[counter++] = activePolls[i];
            }
            unchecked {
                i = i + 1;
            }
        }
    }

    /// @notice A view method for returning whether a given poll is active.
    /// @param  _pollNum unique poll identifier.
    /// @return active whether poll is currently active.
    function isActivePoll(uint256 _pollNum) public view returns (bool active) {
        uint256 length = activePolls.length;
        for (uint256 i; i < length;){
            if (_pollNum == activePolls[i]) {
                return true;
            }
            unchecked {
                i = i + 1;
            }
        }
        return false;
    }

    /// @notice A view method for returning the amount of active polls an author currently has.
    /// @param  _account author's wallet address.
    /// @return _num number of polls that are active, by author.
    function getActivePollsFromAuthor(address _account) public view returns (uint256 _num) {
        uint256 length = activePolls.length;
        for (uint256 i = 0; i < length;){
            if (pollAuthor[activePolls[i]] == _account) {
                _num++;
            }
            unchecked {
                i = i + 1;
            }
        }
    }

    /// @notice A view method for returning whether a provided address is a team member.
    /// @param  _account address of potential team member.
    /// @return bool whether or not _account is inside teamMember array.
    /// @return uint8 index in teamMember array in which _account resides.
    function isTeamMember(address _account) public view returns(bool, uint8) {
        for (uint8 i = 0; i < teamMembers.length; i += 1){
            if (_account == teamMembers[i]) return (true, i);
        }
        return (false, 0);
    }

    /// @notice Returns activePolls array.
    function getActivePolls() external view returns (uint256[] memory) {
        return activePolls;
    }

    /// @notice Returns the voter array given a pollNum.
    function getVoterLibrary(uint256 _pollNum) external view returns (address[] memory) {
        return voterLibrary[_pollNum];
    }

    /// @notice Returns an array of pollNum from advocateFor given _advocate.
    function getAdvocateFor(address _advocate) external view returns (uint256[] memory) {
        return advocateFor[_advocate];
    }

    /// @notice A view method for returning metadata for type taxChange.
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

    /// @notice A view method for returning metadata for type funding.
    function getFunding(uint256 _pollNum) public view returns(uint256, Funding memory, bool) {
        require(pollTypes[_pollNum] == PollType.funding, "Not Funding");
        Metadata memory poll = pollMap[_pollNum];
        Funding memory funding;
        funding.description = poll.description;
        funding.endTime = poll.endTime;
        funding.recipient = payable(poll.addr1);
        funding.amount = poll.amount;

        return (totalVotes[_pollNum], funding, passed[_pollNum]);
    }

    /// @notice A view method for returning metadata for type setGogeDao.
    function getSetGogeDao(uint256 _pollNum) public view returns(uint256, SetGogeDao memory, bool) {
        require(pollTypes[_pollNum] == PollType.setGogeDao, "Not SetGogeDao");
        Metadata memory poll = pollMap[_pollNum];
        SetGogeDao memory setGogeDao;
        setGogeDao.description = poll.description;
        setGogeDao.endTime = poll.endTime;
        setGogeDao.addr = poll.addr1;

        return (totalVotes[_pollNum], setGogeDao, passed[_pollNum]);
    }

    /// @notice A view method for returning metadata for type setCex.
    function getSetCex(uint256 _pollNum) public view returns(uint256, SetCex memory, bool) {
        require(pollTypes[_pollNum] == PollType.setCex, "Not setCex");
        Metadata memory poll = pollMap[_pollNum];
        SetCex memory setCex;
        setCex.description = poll.description;
        setCex.endTime = poll.endTime;
        setCex.addr = poll.addr1;

        return (totalVotes[_pollNum], setCex, passed[_pollNum]);
    }

    /// @notice A view method for returning metadata for type setDex.
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

    /// @notice A view method for returning metadata for type excludeFromCirculatingSupply.
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

    /// @notice A view method for returning metadata for type updateDividendToken.
    function getUpdateDividendToken(uint256 _pollNum) public view returns(uint256, UpdateDividendToken memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateDividendToken, "Not updateDividendToken");
        Metadata memory poll = pollMap[_pollNum];
        UpdateDividendToken memory updateDividendToken;
        updateDividendToken.description = poll.description;
        updateDividendToken.endTime = poll.endTime;
        updateDividendToken.addr = poll.addr1;

        return (totalVotes[_pollNum], updateDividendToken, passed[_pollNum]);
    }

    /// @notice A view method for returning metadata for type updateMarketingWallet.
    function getUpdateMarketingWallet(uint256 _pollNum) public view returns(uint256, UpdateMarketingWallet memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateMarketingWallet, "Not updateMarketingWallet");
        Metadata memory poll = pollMap[_pollNum];
        UpdateMarketingWallet memory updateMarketingWallet;
        updateMarketingWallet.description = poll.description;
        updateMarketingWallet.endTime = poll.endTime;
        updateMarketingWallet.addr = payable(poll.addr1);

        return (totalVotes[_pollNum], updateMarketingWallet, passed[_pollNum]);
    }

    /// @notice A view method for returning metadata for type updateTeamWallet.
    function getUpdateTeamWallet(uint256 _pollNum) public view returns(uint256, UpdateTeamWallet memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateTeamWallet, "Not updateTeamWallet");
        Metadata memory poll = pollMap[_pollNum];
        UpdateTeamWallet memory updateTeamWallet;
        updateTeamWallet.description = poll.description;
        updateTeamWallet.endTime = poll.endTime;
        updateTeamWallet.addr = payable(poll.addr1);

        return (totalVotes[_pollNum], updateTeamWallet, passed[_pollNum]);
    }

    /// @notice A view method for returning metadata for type updateTeamMember.
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

    /// @notice A view method for returning metadata for type updateGateKeeper.
    function getUpdateGateKeeper(uint256 _pollNum) public view returns(uint256, UpdateGatekeeper memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateGatekeeper, "Not updateGateKeeper");
        Metadata memory poll = pollMap[_pollNum];
        UpdateGatekeeper memory modifyGatekeeper;
        modifyGatekeeper.description = poll.description;
        modifyGatekeeper.endTime = poll.endTime;
        modifyGatekeeper.addr = poll.addr1;
        modifyGatekeeper.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], modifyGatekeeper, passed[_pollNum]);
    }

    /// @notice A view method for returning metadata for type setGateKeeping.
    function getSetGateKeeping(uint256 _pollNum) public view returns(uint256, SetGatekeeping memory, bool) {
        require(pollTypes[_pollNum] == PollType.setGatekeeping, "Not setGateKeeping");
        Metadata memory poll = pollMap[_pollNum];
        SetGatekeeping memory modifyGatekeeping;
        modifyGatekeeping.description = poll.description;
        modifyGatekeeping.endTime = poll.endTime;
        modifyGatekeeping.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], modifyGatekeeping, passed[_pollNum]);  
    }

    /// @notice A view method for returning metadata for type setBuyBackEnabled.
    function getSetBuyBackEnabled(uint256 _pollNum) public view returns(uint256, SetBuyBackEnabled memory, bool) {
        require(pollTypes[_pollNum] == PollType.setBuyBackEnabled, "Not setBuyBackEnabled");
        Metadata memory poll = pollMap[_pollNum];
        SetBuyBackEnabled memory setBuyBackEnabled;
        setBuyBackEnabled.description = poll.description;
        setBuyBackEnabled.endTime = poll.endTime;
        setBuyBackEnabled.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], setBuyBackEnabled, passed[_pollNum]);  
    }

    /// @notice A view method for returning metadata for type setCakeDividendEnabled.
    function getSetCakeDividendEnabled(uint256 _pollNum) public view returns(uint256, SetCakeDividendEnabled memory, bool) {
        require(pollTypes[_pollNum] == PollType.setCakeDividendEnabled, "Not setCakeDividendEnabled");
        Metadata memory poll = pollMap[_pollNum];
        SetCakeDividendEnabled memory setCakeDividendEnabled;
        setCakeDividendEnabled.description = poll.description;
        setCakeDividendEnabled.endTime = poll.endTime;
        setCakeDividendEnabled.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], setCakeDividendEnabled, passed[_pollNum]);  
    }

    /// @notice A view method for returning metadata for type setMarketingEnabled.
    function getSetMarketingEnabled(uint256 _pollNum) public view returns(uint256, SetMarketingEnabled memory, bool) {
        require(pollTypes[_pollNum] == PollType.setMarketingEnabled, "Not setMarketingEnabled");
        Metadata memory poll = pollMap[_pollNum];
        SetMarketingEnabled memory setMarketingEnabled;
        setMarketingEnabled.description = poll.description;
        setMarketingEnabled.endTime = poll.endTime;
        setMarketingEnabled.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], setMarketingEnabled, passed[_pollNum]);  
    }

    /// @notice A view method for returning metadata for type setTeamEnabled.
    function getSetTeamEnabled(uint256 _pollNum) public view returns(uint256, SetTeamEnabled memory, bool) {
        require(pollTypes[_pollNum] == PollType.setTeamEnabled, "Not setTeamEnabled");
        Metadata memory poll = pollMap[_pollNum];
        SetTeamEnabled memory setTeamEnabled;
        setTeamEnabled.description = poll.description;
        setTeamEnabled.endTime = poll.endTime;
        setTeamEnabled.boolVar = poll.boolVar;

        return (totalVotes[_pollNum], setTeamEnabled, passed[_pollNum]);  
    }

    /// @notice A view method for returning metadata for type excludeFromFees.
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

    /// @notice A view method for returning metadata for type excludeFromDividends.
    function getExcludeFromDividends(uint256 _pollNum) public view returns(uint256, ExcludeFromDividends memory, bool) {
        require(pollTypes[_pollNum] == PollType.excludeFromDividends, "Not excludeFromDividends");
        Metadata memory poll = pollMap[_pollNum];
        ExcludeFromDividends memory excludeFromDividends;
        excludeFromDividends.description = poll.description;
        excludeFromDividends.endTime = poll.endTime;
        excludeFromDividends.addr = payable(poll.addr1);

        return (totalVotes[_pollNum], excludeFromDividends, passed[_pollNum]);
    }

    /// @notice A view method for returning metadata for type modifyBlacklist.
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

    /// @notice A view method for returning metadata for type transferOwnership.
    function getTransferOwnership(uint256 _pollNum) public view returns(uint256, TransferOwnership memory, bool) {
        require(pollTypes[_pollNum] == PollType.transferOwnership, "Not transferOwnership");
        Metadata memory poll = pollMap[_pollNum];
        TransferOwnership memory transferOwnership;
        transferOwnership.description = poll.description;
        transferOwnership.endTime = poll.endTime;
        transferOwnership.addr = payable(poll.addr1);

        return (totalVotes[_pollNum], transferOwnership, passed[_pollNum]);
    }

    /// @notice A view method for returning metadata for type migrateTreasury.
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

    /// @notice A view method for returning metadata for type setQuorum.
    function getSetQuorum(uint256 _pollNum) public view returns(uint256, SetQuorum memory, bool) {
        require(pollTypes[_pollNum] == PollType.setQuorum, "Not setQuorum");
        Metadata memory poll = pollMap[_pollNum];
        SetQuorum memory setQuorum;
        setQuorum.description = poll.description;
        setQuorum.endTime = poll.endTime;
        setQuorum.amount = poll.amount;

        return (totalVotes[_pollNum], setQuorum, passed[_pollNum]);   
    }

    /// @notice A view method for returning metadata for type updateGovernanceToken.
    function getUpdateGovernanceToken(uint256 _pollNum) public view returns(uint256, UpdateGovernanceToken memory, bool) {
        require(pollTypes[_pollNum] == PollType.updateGovernanceToken, "Not updateGovernanceToken");
        Metadata memory poll = pollMap[_pollNum];
        UpdateGovernanceToken memory updateGovernanceToken;
        updateGovernanceToken.description = poll.description;
        updateGovernanceToken.endTime = poll.endTime;
        updateGovernanceToken.addr = poll.addr1;

        return (totalVotes[_pollNum], updateGovernanceToken, passed[_pollNum]);
    }

    /// @notice A view method for returning metadata for type other.
    function getOther(uint256 _pollNum) public view returns(uint256, string memory, uint256, bool) {
        require(pollTypes[_pollNum] == PollType.other, "Not Other");
        Metadata memory poll = pollMap[_pollNum];
        Other memory other;
        other.description = poll.description;
        other.endTime = poll.endTime;

        return (totalVotes[_pollNum], poll.description, poll.endTime, passed[_pollNum]);
    }
    
}
