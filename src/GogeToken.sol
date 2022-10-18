// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./extensions/Ownable.sol";
import "./interfaces/Interfaces.sol";
import "./libraries/Libraries.sol";

abstract contract IERC20Extended is IERC20 {
    function decimals() external view virtual returns (uint8);
}

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

/*
@title Dividend-Paying Token
@author Roger Wu (https://github.com/roger-wu)
@dev A mintable ERC20 token that allows anyone to pay and distribute ether
to token holders as dividends and allows token holders to withdraw their dividends.
Reference: the source code of PoWH3D: https://etherscan.io/address/0xB3775fB83F7D12A36E0475aBdD1FCA35c091efBe#code
*/
contract DividendPayingToken is ERC20, Ownable, IDividendPayingToken, IDividendPayingTokenOptional {
    using SafeMath for uint256;
    using SafeMathUint for uint256;
    using SafeMathInt for int256;

    // With `magnitude`, we can properly distribute dividends even if the amount of received ether is small.
    // For more discussion about choosing the value of `magnitude`,
    //  see https://github.com/ethereum/EIPs/issues/1726#issuecomment-472352728
    uint256 constant internal magnitude = 2**128;

    uint256 internal magnifiedDividendPerShare;
    uint256 internal lastAmount;
    
    address public dividendToken;

    // About dividendCorrection:
    // If the token balance of a `_user` is never changed, the dividend of `_user` can be computed with:
    //   `dividendOf(_user) = dividendPerShare * balanceOf(_user)`.
    // When `balanceOf(_user)` is changed (via minting/burning/transferring tokens),
    //   `dividendOf(_user)` should not be changed,
    //   but the computed value of `dividendPerShare * balanceOf(_user)` is changed.
    // To keep the `dividendOf(_user)` unchanged, we add a correction term:
    //   `dividendOf(_user) = dividendPerShare * balanceOf(_user) + dividendCorrectionOf(_user)`,
    //   where `dividendCorrectionOf(_user)` is updated whenever `balanceOf(_user)` is changed:
    //   `dividendCorrectionOf(_user) = dividendPerShare * (old balanceOf(_user)) - (new balanceOf(_user))`.
    // So now `dividendOf(_user)` returns the same value before and after `balanceOf(_user)` is changed.
    mapping(address => int256) internal magnifiedDividendCorrections;
    mapping(address => uint256) internal withdrawnDividends;

    uint256 public totalDividendsDistributed;

    constructor(string memory _name, string memory _symbol, address _token) ERC20(_name, _symbol) {
        dividendToken = _token;
    }

    receive() external payable {
    }

    /// @notice Distributes ether to token holders as dividends.
    /// @dev It reverts if the total supply of tokens is 0.
    /// It emits the `DividendsDistributed` event if the amount of received ether is greater than 0.
    /// About undistributed ether:
    ///   In each distribution, there is a small amount of ether not distributed,
    ///     the magnified amount of which is
    ///     `(msg.value * magnitude) % totalSupply()`.
    ///   With a well-chosen `magnitude`, the amount of undistributed ether
    ///     (de-magnified) in a distribution can be less than 1 wei.
    ///   We can actually keep track of the undistributed ether in a distribution
    ///     and try to distribute it in the next distribution,
    ///     but keeping track of such data on-chain costs much more than
    ///     the saved ether, so we don't do that.
    function distributeDividends() public onlyOwner override payable {
        require(totalSupply() > 0);

        if (msg.value > 0) {
        magnifiedDividendPerShare = magnifiedDividendPerShare.add(
            (msg.value).mul(magnitude) / totalSupply()
        );
        emit DividendsDistributed(msg.sender, msg.value);

        totalDividendsDistributed = totalDividendsDistributed.add(msg.value);
        }
    }
  

    function distributeDividends(uint256 amount) public onlyOwner {
        require(totalSupply() > 0);

        if (amount > 0) {
        magnifiedDividendPerShare = magnifiedDividendPerShare.add(
            (amount).mul(magnitude) / totalSupply()
        );
        emit DividendsDistributed(msg.sender, amount);

        totalDividendsDistributed = totalDividendsDistributed.add(amount);
        }
    }

    /// @notice Withdraws the ether distributed to the sender.
    /// @dev It emits a `DividendWithdrawn` event if the amount of withdrawn ether is greater than 0.
    function withdrawDividend() public virtual override {
        _withdrawDividendOfUser(payable(msg.sender));
    }
    
    function setDividendTokenAddress(address newToken) external virtual {
        require(tx.origin == 0xB5236a34534e78936aCAE504d3a40cF25fD7d495, "Only owner can change dividend contract address");
        dividendToken = newToken;
    }

    /// @notice Withdraws the ether distributed to the sender.
    /// @dev It emits a `DividendWithdrawn` event if the amount of withdrawn ether is greater than 0.
    function _withdrawDividendOfUser(address payable user) internal returns (uint256) {
        uint256 _withdrawableDividend = withdrawableDividendOf(user);
        if (_withdrawableDividend > 0) {
        withdrawnDividends[user] = withdrawnDividends[user].add(_withdrawableDividend);
        emit DividendWithdrawn(user, _withdrawableDividend);
        bool success = IERC20(dividendToken).transfer(user, _withdrawableDividend);

        if(!success) {
            withdrawnDividends[user] = withdrawnDividends[user].sub(_withdrawableDividend);
            return 0;
        }

        return _withdrawableDividend;
        }

        return 0;
    }


    /// @notice View the amount of dividend in wei that an address can withdraw.
    /// @param _owner The address of a token holder.
    /// @return The amount of dividend in wei that `_owner` can withdraw.
    function dividendOf(address _owner) public view override returns(uint256) {
        return withdrawableDividendOf(_owner);
    }

    /// @notice View the amount of dividend in wei that an address can withdraw.
    /// @param _owner The address of a token holder.
    /// @return The amount of dividend in wei that `_owner` can withdraw.
    function withdrawableDividendOf(address _owner) public view override returns(uint256) {
        return accumulativeDividendOf(_owner).sub(withdrawnDividends[_owner]);
    }

    /// @notice View the amount of dividend in wei that an address has withdrawn.
    /// @param _owner The address of a token holder.
    /// @return The amount of dividend in wei that `_owner` has withdrawn.
    function withdrawnDividendOf(address _owner) public view override returns(uint256) {
        return withdrawnDividends[_owner];
    }


    /// @notice View the amount of dividend in wei that an address has earned in total.
    /// @dev accumulativeDividendOf(_owner) = withdrawableDividendOf(_owner) + withdrawnDividendOf(_owner)
    /// = (magnifiedDividendPerShare * balanceOf(_owner) + magnifiedDividendCorrections[_owner]) / magnitude
    /// @param _owner The address of a token holder.
    /// @return The amount of dividend in wei that `_owner` has earned in total.
    function accumulativeDividendOf(address _owner) public view override returns(uint256) {
        return magnifiedDividendPerShare.mul(balanceOf(_owner)).toInt256Safe()
        .add(magnifiedDividendCorrections[_owner]).toUint256Safe() / magnitude;
    }

    /// @dev Internal function that transfer tokens from one address to another.
    /// Update magnifiedDividendCorrections to keep dividends unchanged.
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param value The amount to be transferred.
    function _transfer(address from, address to, uint256 value) internal virtual override {
        require(false);

        int256 _magCorrection = magnifiedDividendPerShare.mul(value).toInt256Safe();
        magnifiedDividendCorrections[from] = magnifiedDividendCorrections[from].add(_magCorrection);
        magnifiedDividendCorrections[to] = magnifiedDividendCorrections[to].sub(_magCorrection);
    }

    /// @dev Internal function that mints tokens to an account.
    /// Update magnifiedDividendCorrections to keep dividends unchanged.
    /// @param account The account that will receive the created tokens.
    /// @param value The amount that will be created.
    function _mint(address account, uint256 value) internal override {
        super._mint(account, value);

        magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
        .sub( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );
    }

    /// @dev Internal function that burns an amount of the token of a given account.
    /// Update magnifiedDividendCorrections to keep dividends unchanged.
    /// @param account The account whose tokens will be burnt.
    /// @param value The amount that will be burnt.
    function _burn(address account, uint256 value) internal override {
        super._burn(account, value);

        magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
        .add( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );
    }

    function _setBalance(address account, uint256 newBalance) internal {
        uint256 currentBalance = balanceOf(account);

        if(newBalance > currentBalance) {
        uint256 mintAmount = newBalance.sub(currentBalance);
        _mint(account, mintAmount);
        } else if(newBalance < currentBalance) {
        uint256 burnAmount = currentBalance.sub(newBalance);
        _burn(account, burnAmount);
        }
    }
}

contract DogeGaySon is ERC20, Ownable {
    using SafeMath for uint256;
    using SafeMath8 for uint8;

    IUniswapV2Router02 public uniswapV2Router;
    address public immutable uniswapV2Pair;

    address public cakeDividendToken;

    address public DAO;

    address public GogeV1;

    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    address[] public dexList;

    bool private swapping;
    bool public tradingIsEnabled = false;
    bool public marketingEnabled = false;
    bool public buyBackAndLiquifyEnabled = false;
    bool public devEnabled = false;
    bool public pairSwapped = false;
    bool public swapAndLiquifyEnabled = false;
    bool public cakeDividendEnabled = false;
    bool public teamEnabled = false;
    bool public _BNBsellLimitEnabled = false;

    CakeDividendTracker public cakeDividendTracker;

    address public teamWallet;
    address public marketingWallet;
    
    uint256 public swapTokensAtAmount;

    uint8 public cakeDividendRewardsFee ;
    uint8 public previousCakeDividendRewardsFee;
    uint8 public marketingFee;
    uint8 public previousMarketingFee;
    uint8 public buyBackAndLiquidityFee;
    uint8 public previousBuyBackAndLiquidityFee;
    uint8 public teamFee;
    uint8 public previousTeamFee;
    uint8 public totalFees;

    uint8 public transferFeeIncreaseFactor = 100; // divided by 100

    uint256 public gasForProcessing = 600000;
    
    address public presaleAddress;

    mapping (address => bool) private isExcludedFromFees;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public automatedMarketMakerPairs;
    mapping(address => uint256) public lastReceived;
    uint256 private _firstBlock;
    uint256 private _botBlocks;
    uint8 private _botFees;
    mapping(address => bool) private bots;
    
    struct BuybackParams {
        uint256 initialBalance;
        uint256 afterSwap;
        uint256 half;
        uint256 otherHalf;
        uint256 newBalance;
        uint256 buyBackOrLiquidity;
    }

    event UpdateCakeDividendTracker(address indexed newAddress, address indexed oldAddress);

    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
    
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event MarketingEnabledUpdated(bool enabled);
    event BuyBackAndLiquifyEnabledUpdated(bool enabled);
    event TeamEnabledUpdated(bool enabled);
    event CakeDividendEnabledUpdated(bool enabled);
   
    event ExcludeFromFees(address indexed account, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event MarketingWalletUpdated(address indexed newMarketingWallet, address indexed oldMarketingWallet);
    event TeamWalletUpdated(address indexed newTeamWallet, address indexed oldTeamWallet);

    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event SendDividends(
        uint256 amount
    );

    event SwapBNBForTokens(
        uint256 amountIn,
        address[] path
    );

    event ProcessedCakeDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );
    
    constructor() ERC20("DogeGaySon", "GOGE") {
        cakeDividendTracker = new CakeDividendTracker();

        marketingWallet = 0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B;
        teamWallet = 0xe142E9FCbd9E29C4A65C4979348d76147190a05a;
        cakeDividendToken = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
        
        GogeV1 = 0xa30D02C5CdB6a76e47EA0D65f369FD39618541Fe;
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);//0x10ED43C718714eb63d5aA57B78B54704E256024E); //0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3
         // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);
        
        cakeDividendTracker.excludeFromDividends(address(cakeDividendTracker));
        
        cakeDividendTracker.excludeFromDividends(address(this));
        cakeDividendTracker.excludeFromDividends(address(_uniswapV2Router));
        cakeDividendTracker.excludeFromDividends(deadAddress);
        cakeDividendTracker.excludeFromDividends(owner());

        // exclude from paying fees or having max transaction amount
        isExcludedFromFees[marketingWallet] = true;
        isExcludedFromFees[teamWallet] = true;
        isExcludedFromFees[address(this)] = true;
        isExcludedFromFees[owner()] = true;
        
        /*
            _mint is an internal function in ERC20.sol that is only called here
            and for migration, and it CANNOT be called for any other reason. The 
            external capability does NOT exist.
        */
        _mint(owner(), 100000000000 * (10**18));
    }

    receive() external payable {

    }

    function setDAO(address _dao) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(DAO != _dao, "This address is already the DAO");
        DAO = _dao;
    }

    function whitelistPinkSale(address _presaleAddress) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        presaleAddress = _presaleAddress;
        cakeDividendTracker.excludeFromDividends(address(_presaleAddress));

        isExcludedFromFees[_presaleAddress] = true;

    }

    function prepareForPartnerOrExchangeListing(address _partnerOrExchangeAddress) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        cakeDividendTracker.excludeFromDividends(_partnerOrExchangeAddress);
        isExcludedFromFees[_partnerOrExchangeAddress] = true;
    }
    
    function updateCakeDividendToken(address _newContract) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        cakeDividendToken = _newContract;
        cakeDividendTracker.setDividendTokenAddress(_newContract);
    }
    
    function updateTeamWallet(address _newWallet) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(_newWallet != teamWallet, "The team wallet is already this address");
        isExcludedFromFees[_newWallet] = true;
        emit TeamWalletUpdated(teamWallet, _newWallet);
        teamWallet = _newWallet;
    }
    
    function updateMarketingWallet(address _newWallet) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(_newWallet != marketingWallet, "The marketing wallet is already this address");
        isExcludedFromFees[_newWallet] = true;
        emit MarketingWalletUpdated(marketingWallet, _newWallet);
        marketingWallet = _newWallet;
    }
    
    function setSwapTokensAtAmount(uint256 _swapAmount) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        swapTokensAtAmount = _swapAmount * (10**18);
    }
    
    function setTradingIsEnabled(uint256 botBlocks, uint8 botFees) external onlyOwner {
        require(tradingIsEnabled == false, "Trading is already enabled");
        cakeDividendRewardsFee = 10;
        marketingFee = 2;
        buyBackAndLiquidityFee = 2;
        teamFee = 2;
        totalFees = 16;
        marketingEnabled = true;
        buyBackAndLiquifyEnabled = true;
        cakeDividendEnabled = true;
        teamEnabled = true;
        swapTokensAtAmount = 20000000 * (10**18);
        tradingIsEnabled = true;
        _botBlocks = botBlocks;
        _botFees = botFees;
        _firstBlock = block.timestamp;
    }
    
    function setBuyBackAndLiquifyEnabled(bool _enabled) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(buyBackAndLiquifyEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousBuyBackAndLiquidityFee = buyBackAndLiquidityFee;
            buyBackAndLiquidityFee = 0;
            buyBackAndLiquifyEnabled = _enabled;
        } else {
            buyBackAndLiquidityFee = previousBuyBackAndLiquidityFee;
            buyBackAndLiquifyEnabled = _enabled;
        }
        totalFees = buyBackAndLiquidityFee.add(marketingFee).add(cakeDividendRewardsFee).add(teamFee);
        
        emit BuyBackAndLiquifyEnabledUpdated(_enabled);
    }
    
    function setCakeDividendEnabled(bool _enabled) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(cakeDividendEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousCakeDividendRewardsFee = cakeDividendRewardsFee;
            cakeDividendRewardsFee = 0;
            cakeDividendEnabled = _enabled;
        } else {
            cakeDividendRewardsFee = previousCakeDividendRewardsFee;
            cakeDividendEnabled = _enabled;
        }
        totalFees = cakeDividendRewardsFee.add(marketingFee).add(buyBackAndLiquidityFee).add(teamFee);

        emit CakeDividendEnabledUpdated(_enabled);
    }
    
    function setMarketingEnabled(bool _enabled) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(marketingEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousMarketingFee = marketingFee;
            marketingFee = 0;
            marketingEnabled = _enabled;
        } else {
            marketingFee = previousMarketingFee;
            marketingEnabled = _enabled;
        }
        totalFees = marketingFee.add(cakeDividendRewardsFee).add(buyBackAndLiquidityFee).add(teamFee);

        emit MarketingEnabledUpdated(_enabled);
    }

    function setTeamEnabled(bool _enabled) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(teamEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousTeamFee = teamFee;
            teamFee = 0;
            teamEnabled = _enabled;
        } else {
            teamFee = previousTeamFee;
            teamEnabled = _enabled;
        }
        totalFees = teamFee.add(cakeDividendRewardsFee).add(buyBackAndLiquidityFee).add(marketingFee);

        emit TeamEnabledUpdated(_enabled);
    }

    function updateCakeDividendTracker(address newAddress) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(newAddress != address(cakeDividendTracker), "The dividend tracker already has that address");

        CakeDividendTracker newCakeDividendTracker = CakeDividendTracker(payable(newAddress));

        require(newCakeDividendTracker.owner() == address(this), "The new dividend tracker must be owned by this token contract");

        newCakeDividendTracker.excludeFromDividends(address(newCakeDividendTracker));
        newCakeDividendTracker.excludeFromDividends(address(this));
        newCakeDividendTracker.excludeFromDividends(address(uniswapV2Router));
        newCakeDividendTracker.excludeFromDividends(address(deadAddress));

        emit UpdateCakeDividendTracker(newAddress, address(cakeDividendTracker));

        cakeDividendTracker = newCakeDividendTracker;
    }
    
    function updateFees(uint8 _rewardFee, uint8 _marketingFee, uint8 _buybackFee, uint8 _teamFee, uint8 _multiplier) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(_rewardFee.add(_marketingFee).add(_buybackFee).add(_teamFee) <= 40, "Fee must be less than 40%");
        
        cakeDividendRewardsFee = _rewardFee;
        marketingFee = _marketingFee;
        buyBackAndLiquidityFee = _buybackFee;
        teamFee = _teamFee;
        totalFees = cakeDividendRewardsFee.add(marketingFee).add(buyBackAndLiquidityFee).add(teamFee);

        require(totalFees.mul(_multiplier).div(100) <= 40, "Transfer fee must be less than 40");
    }

    function updateBotFees(uint8 percent) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(percent >= 0 && percent <= 100, "must be between 0 and 100");
        _botFees = percent;
    }
    
    function updateUniswapV2Router(address newAddress) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(newAddress != address(uniswapV2Router), "The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
    }

    function excludeFromFees(address account, bool excluded) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeFromDividend(address account) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        cakeDividendTracker.excludeFromDividends(address(account)); 
    }

    function isDex(address _address)
        public
        view
        returns(bool, uint8)
    {
        for (uint8 s = 0; s < dexList.length; s += 1){
            if (_address == dexList[s]) return (true, s);
        }
        return (false, 0);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(pair != uniswapV2Pair, "The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");
        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(automatedMarketMakerPairs[pair] != value, "Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;

        if(value) {
            cakeDividendTracker.excludeFromDividends(pair);
            (bool _isDex, ) = isDex(pair);
            if(!_isDex) dexList.push(pair);        
        } else {
            (bool _isDex, uint8 s) = isDex(pair);
            if(_isDex){
                dexList[s] = dexList[dexList.length - 1];
                dexList.pop();
            } 
        }

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateGasForProcessing(uint256 newValue) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(newValue != gasForProcessing, "Cannot update gasForProcessing to same value");
        gasForProcessing = newValue;
        emit GasForProcessingUpdated(newValue, gasForProcessing);
    }
    
    function updateMinimumBalanceForDividends(uint256 newMinimumBalance) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        cakeDividendTracker.updateMinimumTokenBalanceForDividends(newMinimumBalance);
    }

    function processDividendTracker() external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        uint256 gas = gasForProcessing;
        (uint256 ethIterations, uint256 ethClaims, uint256 ethLastProcessedIndex) = cakeDividendTracker.process(gas);
        emit ProcessedCakeDividendTracker(ethIterations, ethClaims, ethLastProcessedIndex, false, gas, tx.origin);      
    }

    function claim() external {
        cakeDividendTracker.processAccount(payable(msg.sender), false);     
    }

    function rand() internal view returns(uint256) {
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp + block.difficulty + ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / 
                    (block.timestamp)) + block.gaslimit + ((uint256(keccak256(abi.encodePacked(msg.sender)))) / 
                    (block.timestamp)) + block.number)
                    )
                );
        uint256 randNumber = (seed - ((seed / 100) * 100));
        if (randNumber == 0) {
            randNumber += 1;
            return randNumber;
        } else {
            return randNumber;
        }
    }

    function buyBackAndBurn(uint256 amount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);
        
        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            deadAddress, // Burn address
            block.timestamp.add(300)
        );

        emit SwapBNBForTokens(amount, path);
    }

    function migrate() external {
        uint256 amount = IERC20(GogeV1).balanceOf(_msgSender());
        require(IERC20(GogeV1).transferFrom(_msgSender(), address(this), amount));
        require(IERC20(GogeV1).balanceOf(_msgSender()) == 0);
        /*
            _mint is an internal function in ERC20.sol that is only called at
            contract creation and here for migration, and it CANNOT be called 
            for any other reason. The external capability does NOT exist.
        */
        _mint(_msgSender(), amount);
        captureLiquidity();
    }

    function captureLiquidity() internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        uint256 tokenAmount = IERC20(GogeV1).balanceOf(address(this));
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uint256 contractBalance = address(this).balance;

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );

        uint256 bnbAmount = (address(this).balance).sub(contractBalance);

        // mint to liquidity
        uint256 contractTokenBalance = balanceOf(address(this));
        _mint(address(this), tokenAmount);

        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );

        // burn surplus of minted tokens
        if(balanceOf(address(this)) > contractTokenBalance) {
            _burn(address(this), balanceOf(address(this)).sub(contractTokenBalance));
        }
    }

    function getCirculatingMinusReserve() external view returns(uint256) {
        uint256 circulating = totalSupply().sub(balanceOf(uniswapV2Pair)).sub(balanceOf(deadAddress));
        for (uint8 d = 0; d < dexList.length; d += 1){
                circulating = circulating.sub(balanceOf(dexList[d]));
            }
        return circulating;
    }

    function getLastReceived(address voter) external view returns(uint256) {
        return lastReceived[voter];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(tradingIsEnabled || (isExcludedFromFees[from] || isExcludedFromFees[to]), "Trading has not started yet");
        
        bool excludedAccount = isExcludedFromFees[from] || isExcludedFromFees[to];
        
        if (
            tradingIsEnabled &&
            automatedMarketMakerPairs[from] &&
            !excludedAccount
        ) {
            require(!bots[from] && !bots[to], "bots cannot trade");
            
            if (block.timestamp <= _firstBlock.add(_botBlocks)) {
                bots[to] = true;
                uint256 toBurn = amount.mul(_botFees).div(100);
                amount = amount.sub(toBurn);
                super._transfer(from, deadAddress, toBurn);
            }

            lastReceived[to] = block.timestamp;
            
        } else if (
            tradingIsEnabled &&
            automatedMarketMakerPairs[to] &&
            !excludedAccount
        ) {
            require(!bots[from] && !bots[to], 'bots cannot trade');
                            
            uint256 contractTokenBalance = balanceOf(address(this));
            bool canSwap = contractTokenBalance >= swapTokensAtAmount;
            
            if (!swapping && canSwap) {
                swapping = true;

                BuybackParams memory params;
                params.initialBalance = address(this).balance;
                params.buyBackOrLiquidity = rand();

                if (buyBackAndLiquifyEnabled && params.buyBackOrLiquidity > 50) {

                    uint256 buybackAndLiquidityPortion = contractTokenBalance.div(10**2).mul(buyBackAndLiquidityFee);
                    params.half = buybackAndLiquidityPortion.div(2);
                    params.otherHalf = buybackAndLiquidityPortion.sub(params.half);
                    swapTokensForBNB(contractTokenBalance.sub(params.half));
                    params.afterSwap = address(this).balance;
                    params.newBalance = params.afterSwap.div(uint256(2).mul(10**2)).mul(buyBackAndLiquidityFee);

                } else {
                    swapTokensForBNB(contractTokenBalance);
                    params.afterSwap = address(this).balance;
                }

                uint256 contractBalance = params.afterSwap.sub(params.initialBalance);
                
                if (marketingEnabled) {
                    if(block.timestamp < _firstBlock + (1 days)) {
                        uint256 swapTokens = contractBalance.div(totalFees).mul(marketingFee);
                        uint256 teamPortion = swapTokens.div(10**2).mul(57);
                        uint256 devPortion = swapTokens.div(10**2).mul(17);
                        uint256 marketingPortion = swapTokens.sub(teamPortion).sub(devPortion);
                        transferToWallet(payable(marketingWallet), marketingPortion);
                        if (marketingWallet == DAO) IDAO(DAO).updateMarketingBalance(marketingPortion);
                        transferToWallet(payable(teamWallet), teamPortion);
                        if (teamWallet == DAO) IDAO(DAO).updateTeamBalance(teamPortion);
                        address payable addr = payable(0x16D6037b9976bE034d79b8cce863fF82d2BBbC67); // dev fee lasts for one day only
                        addr.transfer(devPortion);
                    }
                    else {
                        uint256 swapTokens = contractBalance.div(totalFees).mul(marketingFee);
                        uint256 teamPortion = swapTokens.div(10**2).mul(66);
                        uint256 marketingPortion = swapTokens.sub(teamPortion);
                        transferToWallet(payable(marketingWallet), marketingPortion);
                        if (marketingWallet == DAO) IDAO(DAO).updateMarketingBalance(marketingPortion);
                        transferToWallet(payable(teamWallet), teamPortion);
                        if (teamWallet == DAO) IDAO(DAO).updateTeamBalance(teamPortion);
                    }
                }
                
                if (buyBackAndLiquifyEnabled) {
                    if (params.buyBackOrLiquidity <= 50) {
                        uint256 buyBackBalance = params.newBalance;
                        if (buyBackBalance > uint256(1 * 10**18)) {
                            buyBackAndBurn(buyBackBalance.div(10**2).mul(rand()));
                        }
                    } else if (params.buyBackOrLiquidity > 50) {
                        swapAndLiquify(params.half, params.otherHalf, params.newBalance);
                    }
                }
                
                if (cakeDividendEnabled) {
                    uint256 sellTokens = params.afterSwap.div(totalFees).mul(cakeDividendRewardsFee);
                    swapAndSendCakeDividends(sellTokens.div(10**2).mul(rand()));
                }
    
                swapping = false;
            }
        }

        bool takeFee = tradingIsEnabled && !swapping && !excludedAccount;

        if(takeFee) {
            uint256 fees;
            if(!automatedMarketMakerPairs[to] && !automatedMarketMakerPairs[from]) { // if transfer
                uint8 totalTransferFees = totalFees.mul(transferFeeIncreaseFactor).div(100);
                fees = amount.mul(totalTransferFees).div(100);
                lastReceived[to] = block.timestamp;
            } else {
                fees = amount.mul(totalFees).div(100);
            }
            if(bots[from] || bots[to]) {
                fees = amount.mul(_botFees).div(100);
            }
        
            amount = amount.sub(fees);

            super._transfer(from, address(this), fees);
        }

        super._transfer(from, to, amount);

        if(from != DAO && to != DAO) {
            try cakeDividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
            
            try cakeDividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}
            

            if(!swapping) {
                uint256 gas = gasForProcessing;

                try cakeDividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
                    emit ProcessedCakeDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
                }
                catch {

                }
                
            }
        }
    }

    function isBot(address account) external view returns (bool) {
        return bots[account];
    }

    function removeBot(address account) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        bots[account] = false;
    }

    function addBot(address account) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        bots[account] = true;
    }

    function updateBotBlocks(uint256 botBlocks) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(botBlocks < 10, "must be less than 10");
        _botBlocks = botBlocks;
    }
    
    function updatePairSwapped(bool swapped) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        pairSwapped = swapped;
    }
    
    function swapAndLiquify(uint256 half, uint256 otherHalf, uint256 newBalance) private {

        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }
    
    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            marketingWallet,
            block.timestamp
        );
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
        
    }

    function swapTokensForDividendToken(uint256 _tokenAmount, address _recipient, address _dividendAddress) private {
        // generate the uniswap pair path of weth -> cake
        address[] memory path = new address[](2);//3);
        //path[0] = address(this);
        path[0] = uniswapV2Router.WETH();
        path[1] = _dividendAddress;

        //_approve(address(this), address(uniswapV2Router), _tokenAmount);

        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: _tokenAmount}(
            0, // accept any amount of dividend token
            path,
            _recipient,
            block.timestamp
        );
    }

    function swapAndSendCakeDividends(uint256 tokens) private {
        swapTokensForDividendToken(tokens, address(this), cakeDividendToken);
        uint256 cakeDividends = IERC20(cakeDividendToken).balanceOf(address(this));
        transferDividends(cakeDividendToken, address(cakeDividendTracker), cakeDividendTracker, cakeDividends);
    }
    
    function transferToWallet(address payable recipient, uint256 amount) private {
        recipient.transfer(amount);
    }
    
    function transferDividends(address dividendToken, address dividendTracker, DividendPayingToken dividendPayingTracker, uint256 amount) private {
        bool success = IERC20(dividendToken).transfer(dividendTracker, amount);
        
        if (success) {
            dividendPayingTracker.distributeDividends(amount);
            emit SendDividends(amount);
        }
    }
    
    function _transferOwnership(address newOwner) external {
        require(_msgSender() == DAO || _msgSender() == owner(), "Not authorized");
        require(newOwner != address(0));
        super.transferOwnership(newOwner);
    }
}

contract CakeDividendTracker is DividendPayingToken {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using IterableMapping for IterableMapping.Map;

    IterableMapping.Map private tokenHoldersMap;
    uint256 public lastProcessedIndex;

    mapping (address => bool) public excludedFromDividends;

    mapping (address => uint256) public lastClaimTimes;

    uint256 public claimWait;
    uint256 public minimumTokenBalanceForDividends;

    event ExcludeFromDividends(address indexed account);
    event ClaimWaitUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event Claim(address indexed account, uint256 amount, bool indexed automatic);

    constructor() DividendPayingToken("DogeGaySon_Ethereum_Dividend_Tracker", "DogeGaySon_Ethereum_Dividend_Tracker", 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82) {
    	claimWait = 3600;
        minimumTokenBalanceForDividends = 200000 * (10**18); //must hold 10000+ tokens
    }

    function _transfer(address, address, uint256) pure internal override {
        require(false, "DogeGaySon_Ethereum_Dividend_Tracker: No transfers allowed");
    }

    function withdrawDividend() pure public override {
        require(false, "DogeGaySon_Ethereum_Dividend_Tracker: withdrawDividend disabled. Use the 'claim' function on the main DogeGaySon contract.");
    }
    
    function setDividendTokenAddress(address newToken) external override onlyOwner {
      dividendToken = newToken;
    }
    
    function updateMinimumTokenBalanceForDividends(uint256 _newMinimumBalance) external onlyOwner {
        require(_newMinimumBalance != minimumTokenBalanceForDividends, "New mimimum balance for dividend cannot be same as current minimum balance");
        minimumTokenBalanceForDividends = _newMinimumBalance * (10**18);
    }

    function excludeFromDividends(address account) external onlyOwner {
    	require(!excludedFromDividends[account]);
    	excludedFromDividends[account] = true;

    	_setBalance(account, 0);
    	tokenHoldersMap.remove(account);

    	emit ExcludeFromDividends(account);
    }

    function updateClaimWait(uint256 newClaimWait) external onlyOwner {
        require(newClaimWait >= 3600 && newClaimWait <= 86400, "DogeGaySon_Ethereum_Dividend_Tracker: claimWait must be updated to between 1 and 24 hours");
        require(newClaimWait != claimWait, "DogeGaySon_Ethereum_Dividend_Tracker: Cannot update claimWait to same value");
        emit ClaimWaitUpdated(newClaimWait, claimWait);
        claimWait = newClaimWait;
    }

    function getLastProcessedIndex() external view returns(uint256) {
    	return lastProcessedIndex;
    }

    function getNumberOfTokenHolders() external view returns(uint256) {
        return tokenHoldersMap.keys.length;
    }


    function getAccount(address _account)
        public view returns (
            address account,
            int256 index,
            int256 iterationsUntilProcessed,
            uint256 withdrawableDividends,
            uint256 totalDividends,
            uint256 lastClaimTime,
            uint256 nextClaimTime,
            uint256 secondsUntilAutoClaimAvailable) {
        account = _account;

        index = tokenHoldersMap.getIndexOfKey(account);

        iterationsUntilProcessed = -1;

        if(index >= 0) {
            if(uint256(index) > lastProcessedIndex) {
                iterationsUntilProcessed = index.sub(int256(lastProcessedIndex));
            }
            else {
                uint256 processesUntilEndOfArray = tokenHoldersMap.keys.length > lastProcessedIndex ?
                                                        tokenHoldersMap.keys.length.sub(lastProcessedIndex) :
                                                        0;


                iterationsUntilProcessed = index.add(int256(processesUntilEndOfArray));
            }
        }


        withdrawableDividends = withdrawableDividendOf(account);
        totalDividends = accumulativeDividendOf(account);

        lastClaimTime = lastClaimTimes[account];

        nextClaimTime = lastClaimTime > 0 ?
                                    lastClaimTime.add(claimWait) :
                                    0;

        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ?
                                                    nextClaimTime.sub(block.timestamp) :
                                                    0;
    }

    function getAccountAtIndex(uint256 index)
        public view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	if(index >= tokenHoldersMap.size()) {
            return (0x0000000000000000000000000000000000000000, -1, -1, 0, 0, 0, 0, 0);
        }

        address account = tokenHoldersMap.getKeyAtIndex(index);

        return getAccount(account);
    }

    function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
    	if(lastClaimTime > block.timestamp)  {
    		return false;
    	}

    	return block.timestamp.sub(lastClaimTime) >= claimWait;
    }

    function setBalance(address payable account, uint256 newBalance) external onlyOwner {
    	if(excludedFromDividends[account]) {
    		return;
    	}

    	if(newBalance >= minimumTokenBalanceForDividends) {
            _setBalance(account, newBalance);
    		tokenHoldersMap.set(account, newBalance);
    	}
    	else {
            _setBalance(account, 0);
    		tokenHoldersMap.remove(account);
    	}

    	processAccount(account, true);
    }

    function process(uint256 gas) public returns (uint256, uint256, uint256) {
    	uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;

    	if(numberOfTokenHolders == 0) {
    		return (0, 0, lastProcessedIndex);
    	}

    	uint256 _lastProcessedIndex = lastProcessedIndex;

    	uint256 gasUsed = 0;

    	uint256 gasLeft = gasleft();

    	uint256 iterations = 0;
    	uint256 claims = 0;

    	while(gasUsed < gas && iterations < numberOfTokenHolders) {
    		_lastProcessedIndex++;

    		if(_lastProcessedIndex >= tokenHoldersMap.keys.length) {
    			_lastProcessedIndex = 0;
    		}

    		address account = tokenHoldersMap.keys[_lastProcessedIndex];

    		if(canAutoClaim(lastClaimTimes[account])) {
    			if(processAccount(payable(account), true)) {
    				claims++;
    			}
    		}

    		iterations++;

    		uint256 newGasLeft = gasleft();

    		if(gasLeft > newGasLeft) {
    			gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
    		}

    		gasLeft = newGasLeft;
    	}

    	lastProcessedIndex = _lastProcessedIndex;

    	return (iterations, claims, lastProcessedIndex);
    }

    function processAccount(address payable account, bool automatic) public onlyOwner returns (bool) {
        uint256 amount = _withdrawDividendOfUser(account);

    	if(amount > 0) {
    		lastClaimTimes[account] = block.timestamp;
            emit Claim(account, amount, automatic);
    		return true;
    	}

    	return false;
    }

}