// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import { Owned } from "./extensions/Owned.sol";
import { IGogeERC20 } from "./extensions/IGogeERC20.sol";

/// @title Doge Day Son Dao Contract.
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
    /// @notice The minimum time needed for a new poll -> default is 1 day.
    uint256 public minPeriod = 1 days;
    /// @notice The maximum time needed for a new poll -> default is 60 days.
    uint256 public maxPeriod = 60 days;
    /// @notice The minimum balance of governance token the author of a poll must be holding at the time of creation.
    uint256 public minAuthorBal = 10_000_000 ether;
    /// @notice The maximum amount of polls an author can have active at any given time.
    uint256 public maxPollsPerAuthor = 1;
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
    
    /// @notice Double Mapping of pollNum to amount of votes per voter.
    mapping(uint256 => mapping(address => uint256)) public polls;
    /// @notice Mapping of pollNum to array of addresses of voters
    mapping(uint256 => address[]) public voterLibrary;
    /// @notice Mapping of pollNum to amount of total votes per poll.
    mapping(uint256 => uint256) public totalVotes;
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
        setQuorum,
        updateGovernanceToken,
        other
    }

    // -------- Poll Structs -----------

    /// @notice Metadata block. All combinations.
    /// @param amount uint256 amount input.                     
    /// @param startTime unix timestamp of poll creation date.
    /// @param endTime unix timestamp of poll expiration date.
    /// @param fee1 uint8 rewardFee.
    /// @param fee2 uint8 marketingFee.
    /// @param fee3 uint8 buyBackFee.
    /// @param fee4 uint8 teamFee.
    /// @param boolVar boolean input.
    /// @param addr1 first address input.                       
    /// @param addr2 second address input.
    /// @param description proposal description.
    struct Metadata {
        uint256 amount;      // Slot 0 -> 32 bytes
        uint256 startTime;   // Slot 1 -> 32 bytes
        uint256 endTime;     // Slot 2 -> 32 bytes
        uint8 fee1;
        uint8 fee2;
        uint8 fee3;
        uint8 fee4;
        bool boolVar;
        address addr1;       // (slot 3 -> 25 bytes)
        address addr2;       // (slot 4 -> 20 bytes)
        string description;  // (slot 5+ -> 32 bytes+)
    }
    

    // -----------
    // Constructor
    // -----------

    /// @notice Initializes GogeDao.sol
    /// @param _governanceToken address of governance token.
    constructor(address _governanceToken) Owned(msg.sender) {
       _setGateKeeper(owner, true);
        governanceTokenAddr = _governanceToken;
    }


    // ---------
    // Modifiers
    // ---------

    /// @notice Modifier for permissioned functions excluding wallets except owner and poll author.
    modifier onlyOwnerOrAuthor(uint256 _pollNum) {
        require(msg.sender == owner || msg.sender == pollAuthor[_pollNum], "UNAUTHORIZED");
        _;
    }

    /// @notice Modifier for permissioned functions where msg.sender must be governance token.
    modifier onlyGovernanceToken() {
        require(msg.sender == governanceTokenAddr, "UNAUTHORIZED");
        _;
    }

    /// @notice Modifier for permissioned functions excluding wallets except gatekeepers.
    modifier onlyGatekeeper() {
        require(gatekeeper[msg.sender], "UNAUTHORIZED");
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
        require(_change.endTime - block.timestamp >= minPeriod, "GogeDao.sol::createPoll() Polling period must be greater than minPeriod");
        require(_change.endTime - block.timestamp <= maxPeriod, "GogeDao.sol::createPoll() Polling period must be less than maxPeriod");

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
        pollAuthor[pollNum]    = msg.sender;

        activePolls.push(pollNum);
    }

    /// @notice A method for a voter to add a vote to an existing poll.
    /// @param  _pollNum The poll number.
    /// @param  _numVotes The size of the vote to be created.
    function addVote(uint256 _pollNum, uint256 _numVotes) external {
        require(block.timestamp < pollMap[_pollNum].endTime, "GogeDao.sol::addVote() Poll Closed");
        require(block.timestamp - IGogeERC20(governanceTokenAddr).getLastReceived(msg.sender) >= (5 minutes), "GogeDao.sol::addVote() Must wait 5 minutes after purchasing tokens to place any votes.");
        require(IGogeERC20(governanceTokenAddr).balanceOf(msg.sender) >= _numVotes, "GogeDao.sol::addVote() Exceeds Balance");
        require(IGogeERC20(governanceTokenAddr).transferFrom(msg.sender, address(this), _numVotes));

        _addToVoterLibrary(_pollNum, msg.sender);
        _addToAdvocateFor(_pollNum, msg.sender);

        polls[_pollNum][msg.sender] += _numVotes;
        totalVotes[_pollNum]        += _numVotes;

        bool quorumMet = getProportion(_pollNum) >= quorum;

        if(!gatekeeping && quorumMet) {
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
        // ensures contract balance can support team balance
        uint256 balance = teamBalance;
        require(balance <= address(this).balance, "GogeDao.sol::payTeam Insufficient balance!");

        // ensures no division by zero.
        uint256 length = teamMembers.length;
        require(length > 0, "GogeDao.sol::payTeam No team members!");

        // ensures no payments are made if payment is not greater than zero
        uint256 payment = balance / length;
        require(payment > 0, "GogeDao.sol::payTeam Insufficient balance!");

        for(uint256 i; i < length;) {
            (bool sent,) = teamMembers[i].call{value: payment}("");
            require(sent, "GogeDao.sol::payTeam Failed to send payment");
            unchecked {
                ++i;
            }
        }

        teamBalance = balance % length;
    }

    /// @notice A method for querying all active poll end times, and if poll is expired, remove from ActivePolls.
    /// @dev Should be called on a regular time interval using an external script.
    ///      Solution: https://automation.chain.link/
    function queryEndTime() external {
        uint256 length = activePolls.length;
        // iterate through activePolls
        for (uint256 i; i < length;) {
            uint256 endTime = pollMap[activePolls[i]].endTime;
            // check if poll has reached endTime
            if (block.timestamp >= endTime) {
                // refund voters
                _refundVoters(activePolls[i]);
                // remove poll
                activePolls[i] = activePolls[--length];
                activePolls.pop();                
            }
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
    function setGateKeeping(bool _enabled) external onlyOwner {
        _setGateKeeping(_enabled);
    }

    /// @notice An owner method for updating quorum.
    /// @param  _amount new quourum.
    function updateQuorum(uint256 _amount) external onlyOwner {
        _updateQuorum(_amount);
    }

    /// @notice An owner method for adding new gate keeper addresses.
    /// @param  _account new gate keeper.
    /// @param  _gateKeeper is a gate keeper.
    function updateGateKeeper(address _account, bool _gateKeeper) external onlyOwner {
        _setGateKeeper(_account, _gateKeeper);
    }

    /// @notice An owner method for manually passing a poll.
    /// @param  _pollNum unique poll identifier.
    /// @dev    poll must be an active poll
    function passPoll(uint256 _pollNum) external onlyOwner {
        require(block.timestamp < pollMap[_pollNum].endTime, "GogeDao.sol::passPoll() Poll Closed");
        _executeProposal(_pollNum);
    }

    /// @notice An owner method for updating status of createPoll.
    function toggleCreatePollEnabled() external onlyOwner {
        require(IGogeERC20(governanceTokenAddr).isExcludedFromFees(address(this)), "GogeDao.sol::toggleCreatePollEnabled() !isExcludedFromFees(address(this))");
        createPollEnabled = !createPollEnabled;
    }

    /// @notice An owner method for manually ending a poll.
    /// @param  _pollNum unique poll identifier.
    /// @dev    Poll must be an active poll.
    ///         This function is also callable by the author of _pollNum.
    function endPoll(uint256 _pollNum) external onlyOwnerOrAuthor(_pollNum) {
        require(block.timestamp < pollMap[_pollNum].endTime, "GogeDao.sol::endPoll() Poll Closed");
        _updateEndTime(_pollNum);
        _removePoll(_pollNum);
        _refundVoters(_pollNum);
    }

    /// @notice An owner method for updating minPeriod.
    /// @param  _amountOfDays new minPeriod in days.
    function updateMinPeriod(uint8 _amountOfDays) external onlyOwner {
        require(_amountOfDays < maxPeriod, "GogeDao.sol::updateMinPeriod() minPeriod must be less than maxPeriod");
        minPeriod = uint256(_amountOfDays) * 1 days;
    }

    /// @notice An owner method for updating maxPeriod.
    /// @param  _amountOfDays new maxPeriod in days.
    function updateMaxPeriod(uint8 _amountOfDays) external onlyOwner {
        require(_amountOfDays > minPeriod, "GogeDao.sol::updateMaxPeriod() minPeriod must be greater than minPeriod");
        maxPeriod = uint256(_amountOfDays) * 1 days;
    }

    /// @notice An owner method for adding new team member.
    /// @param  _account new team member.
    /// @param  _isMember is a team member.
    function setTeamMember(address _account, bool _isMember) external onlyOwner {
        _setTeamMember(_account, _isMember);
    }

    /// @notice An owner method for updating minAuthorBal.
    /// @param  _amount new min balance of a poll author.
    function updateMinAuthorBal(uint256 _amount) external onlyOwner {
        minAuthorBal = _amount;
    }

    /// @notice An owner method for updating maxPollsPerAuthor.
    /// @param  _limit amount of active polls an author can have at any given time.
    function updateMaxPollsPerAuthor(uint8 _limit) external onlyOwner {
        maxPollsPerAuthor = uint256(_limit);
    }

    /// @notice Withdraws the entire ETH balance of this contract into the multisig wallet.
    /// @dev Call pattern adopted from the sendValue(address payable recipient, uint256 amount)
    ///      function in OZ's utils/Address.sol contract. "Please consider reentrancy potential" - OZ.
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance - (marketingBalance + teamBalance);
        require(balance > 0, "GogeDao.sol::withdraw() Insufficient BNB balance");

        (bool success,) = owner.call{value: balance}("");
        require(success, "GogeDao.sol::withdraw() Unable to withdraw funds, recipient may have reverted");
    }

    /// @notice Withdraws any ERC20 token balance of this contract.
    /// @param  _token Address of an ERC20 compliant token.
    /// @dev    _token cannot be governance token address.
    function withdrawERC20(address _token) external onlyOwner {
        require(_token != governanceTokenAddr, "GogeDao.sol::withdrawERC20() Address cannot be governance token");

        uint256 balance = IGogeERC20(_token).balanceOf(address(this));
        require(balance > 0, "GogeDao.sol::withdrawERC20() Insufficient token balance");

        require(IGogeERC20(_token).transfer(msg.sender, balance), "GogeDao.sol::withdrawERC20() Transfer failed");
    }

    // NOTE: governanceTokenAddr

    /// @notice A method for updating team balance.
    /// @param  _amount amount of BNB to add to teamBalance.
    /// @dev    Only callable by governanceTokenAddr
    function updateTeamBalance(uint256 _amount) external onlyGovernanceToken {
        teamBalance += _amount;
    }

    /// @notice A method for updating marketing balance.
    /// @param  _amount amount of BNB to add to marketingBalanace.
    /// @dev    Only callable by governanceTokenAddr
    function updateMarketingBalance(uint256 _amount) external onlyGovernanceToken {
        marketingBalance += _amount;
    }

    // NOTE: gatekeeper

    /// @notice A Gatekeeper method for manually passing a poll.
    /// @param  _pollNum unique poll identifier.
    /// @dev    poll must be an active poll and have met quorum.
    function passPollAsGatekeeper(uint256 _pollNum) external onlyGatekeeper {
        require(block.timestamp < pollMap[_pollNum].endTime, "GogeDao.sol::passPollAsGatekeeper() Poll Closed");
        require(gatekeeping, "GogeDao.sol::passPollAsGatekeeper() Gatekeeping disabled");
        require(getProportion(_pollNum) >= quorum, "GogeDao.sol::passPollAsGatekeeper() Poll Quorum not met");

        _executeProposal(_pollNum);
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
            Metadata memory taxChange = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).updateFees(taxChange.fee1, taxChange.fee2, taxChange.fee3, taxChange.fee4);
        }
        else if (_pollType == PollType.funding) {
            Metadata memory funding = pollMap[_pollNum];
            require(funding.amount <= marketingBalance, "Insufficient Funds");
            (bool success,) = funding.addr1.call{value: funding.amount}("");
            require(success, "call unsuccessful");
            marketingBalance -= funding.amount;
        }
        else if (_pollType == PollType.setGogeDao) {
            Metadata memory setGogeDao = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).setGogeDao(setGogeDao.addr1);
        }
        else if (_pollType == PollType.setCex) {
            Metadata memory setCex = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).addPartnerOrExchange(setCex.addr1);
        }
        else if (_pollType == PollType.setDex) {
            Metadata memory setDex = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).setAutomatedMarketMakerPair(setDex.addr1, setDex.boolVar);
        }
        else if (_pollType == PollType.excludeFromCirculatingSupply) {
            Metadata memory excludeFromCirculatingSupply = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).excludeFromCirculatingSupply(excludeFromCirculatingSupply.addr1, excludeFromCirculatingSupply.boolVar);
        }
        else if (_pollType == PollType.updateDividendToken) {
            Metadata memory updateDividendToken = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).updateCakeDividendToken(updateDividendToken.addr1);
        }
        else if (_pollType == PollType.updateMarketingWallet) {
            Metadata memory updateMarketingWallet = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).updateMarketingWallet(updateMarketingWallet.addr1);
        }
        else if (_pollType == PollType.updateTeamWallet) {
            Metadata memory updateTeamWallet = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).updateTeamWallet(updateTeamWallet.addr1);
        }
        else if (_pollType == PollType.updateTeamMember) {
            Metadata memory updateTeamMember = pollMap[_pollNum];
            _setTeamMember(updateTeamMember.addr1, updateTeamMember.boolVar);
        }
        else if (_pollType == PollType.updateGatekeeper) {
            Metadata memory modifyGateKeeper = pollMap[_pollNum];
            _setGateKeeper(modifyGateKeeper.addr1, modifyGateKeeper.boolVar);
        }
        else if (_pollType == PollType.setGatekeeping) {
            Metadata memory modifyGateKeeping = pollMap[_pollNum];
            _setGateKeeping(modifyGateKeeping.boolVar);
        }
        else if (_pollType == PollType.setBuyBackEnabled) {
            Metadata memory setBuyBackEnabled = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).setBuyBackEnabled(setBuyBackEnabled.boolVar);
        }
        else if (_pollType == PollType.setCakeDividendEnabled) {
            Metadata memory setCakeDividendEnabled = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).setCakeDividendEnabled(setCakeDividendEnabled.boolVar);
        }
        else if (_pollType == PollType.setMarketingEnabled) {
            Metadata memory setMarketingEnabled = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).setMarketingEnabled(setMarketingEnabled.boolVar);
        }
        else if (_pollType == PollType.setTeamEnabled) {
            Metadata memory setTeamEnabled = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).setTeamEnabled(setTeamEnabled.boolVar);
        }
        else if (_pollType == PollType.excludeFromFees) {
            Metadata memory excludeFromFees = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).excludeFromFees(excludeFromFees.addr1, excludeFromFees.boolVar);
        }
        else if (_pollType == PollType.excludeFromDividends) {
            Metadata memory excludeFromDividends = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).excludeFromDividend(excludeFromDividends.addr1);
        }
        else if (_pollType == PollType.modifyBlacklist) {
            Metadata memory modifyBlacklist = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr).modifyBlacklist(modifyBlacklist.addr1, modifyBlacklist.boolVar);
        }
        else if (_pollType == PollType.transferOwnership) {
            Metadata memory transferOwnership = pollMap[_pollNum];
            IGogeERC20(governanceTokenAddr)._transferOwnership(transferOwnership.addr1);
        }
        else if (_pollType == PollType.setQuorum) {
            Metadata memory setQuorum = pollMap[_pollNum];
            _updateQuorum(setQuorum.amount);
        }
        else if (_pollType == PollType.updateGovernanceToken) {
            Metadata memory updateGovernanceToken = pollMap[_pollNum];

            _removePoll(_pollNum);
            _refundVoters(_pollNum);

            _changeGovernanceToken(updateGovernanceToken.addr1);
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
        if (_value) {
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
        uint256 length = activePolls.length;
        for (uint256 i; i < length;) {
            if (_pollNum == activePolls[i]) {
                activePolls[i] = activePolls[--length];
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
        pollMap[_pollNum].endTime = block.timestamp;
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
                unchecked {
                    _num = _num + 1;
                }
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
        uint256 length = teamMembers.length;
        for (uint8 i; i < length;){
            if (_account == teamMembers[i]) {
                return (true, i);
            }
            unchecked {
                i = i + 1;
            }
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
    
}
