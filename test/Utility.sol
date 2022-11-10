// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.6;

import "../src/users/Actor.sol";

import "../lib/forge-std/src/Test.sol";

interface Hevm {
    function warp(uint256) external;
    function store(address,bytes32,bytes32) external;
}

interface User {
    function approve(address, uint256) external;
}

// NOTE: All contract addresses provided below have been configured for a Binance Smart Chain contract.

contract Utility is DSTest {

    Hevm hevm;

    /***********************/
    /*** Protocol Actors ***/
    /***********************/
    Actor  joe;
    Actor  dev;
    Actor  sal;
    Actor  jon;
    Actor  nik;
    Actor  tim;

    /**********************************/
    /*** Mainnet Contract Addresses ***/
    /**********************************/
    address constant WBNB  = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant BUSD  = 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3;
    address constant CAKE  = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address constant BUNY  = 0xC9849E6fdB743d08fAeE3E34dd2D1bc69EA11a51;

    IERC20 constant dai  = IERC20(BUSD);
    IERC20 constant wbnb = IERC20(WBNB);
    IERC20 constant cake = IERC20(CAKE);

    address constant UNISWAP_V2_ROUTER_02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Uniswap V2 Router
    address constant UNISWAP_V2_FACTORY   = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // Uniswap V2 factory.

    /*****************/
    /*** Constants ***/
    /*****************/
    uint8 public constant CL_FACTORY = 0;  // Factory type of `CollateralLockerFactory`.
    uint8 public constant DL_FACTORY = 1;  // Factory type of `DebtLockerFactory`.
    uint8 public constant FL_FACTORY = 2;  // Factory type of `FundingLockerFactory`.
    uint8 public constant LL_FACTORY = 3;  // Factory type of `LiquidityLockerFactory`.
    uint8 public constant SL_FACTORY = 4;  // Factory type of `StakeLockerFactory`.

    uint8 public constant INTEREST_CALC_TYPE = 10;  // Calc type of `RepaymentCalc`.
    uint8 public constant LATEFEE_CALC_TYPE  = 11;  // Calc type of `LateFeeCalc`.
    uint8 public constant PREMIUM_CALC_TYPE  = 12;  // Calc type of `PremiumCalc`.

    uint256 constant USD = 10 ** 6;  // USDC precision decimals
    uint256 constant BTC = 10 ** 8;  // WBTC precision decimals
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;

    /*****************/
    /*** Utilities ***/
    /*****************/
    struct Token {
        address addr; // ERC20 Mainnet address
        uint256 slot; // Balance storage slot
        address orcl; // Chainlink oracle address
    }
 
    mapping (bytes32 => Token) tokens;

    struct TestObj {
        uint256 pre;
        uint256 post;
    }

    event Debug(string, uint256);
    event Debug(string, address);
    event Debug(string, bool);
    event Debug(string, string);

    constructor() public { hevm = Hevm(address(bytes20(uint160(uint256(keccak256("hevm cheat code")))))); }

    /**************************************/
    /*** Actor/Multisig Setup Functions ***/
    /**************************************/
    function createActors() public {
        sal = new Actor();
        jon = new Actor();
        nik = new Actor();
        tim = new Actor();
        joe = new Actor();

        dev = new Actor();
    }


    /******************************/
    /*** Test Utility Functions ***/
    /******************************/
    function setUpTokens() public {

        // tokens["USDC"].addr = USDC;
        // tokens["USDC"].slot = 9;

        // tokens["DAI"].addr = DAI;
        // tokens["DAI"].slot = 2;
        // tokens["DAI"].orcl = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;

        // tokens["WETH"].addr = WETH;
        // tokens["WETH"].slot = 3;
        // tokens["WETH"].orcl = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

        // tokens["WBTC"].addr = WBTC;
        // tokens["WBTC"].slot = 0;
        // tokens["WBTC"].orcl = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;

        tokens["WBNB"].addr = WBNB;
        tokens["WBNB"].slot = 0;
        tokens["WBNB"].orcl = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;

        tokens["BUSD"].addr = BUSD;
        tokens["BUSD"].slot = 1;
        tokens["BUSD"].orcl = 0xcBb98864Ef56E9042e7d2efef76141f15731B82f;

        tokens["CAKE"].addr = CAKE;
        tokens["CAKE"].slot = 3;
        tokens["CAKE"].orcl = 0xB6064eD41d4f67e353768aA239cA86f4F73665a1;

        // NOTE: Slots might be wrong here
    }

    // Manipulate mainnet ERC20 balance.
    function mint(bytes32 symbol, address account, uint256 amt) public {
        address addr = tokens[symbol].addr;
        uint256 slot  = tokens[symbol].slot;
        uint256 bal = IERC20(addr).balanceOf(account);

        hevm.store(
            addr,
            keccak256(abi.encode(account, slot)), // Mint tokens
            bytes32(bal + amt)
        );

        assertEq(IERC20(addr).balanceOf(account), bal + amt); // Assert new balance
    }

    // Verify equality within accuracy decimals.
    function withinPrecision(uint256 val0, uint256 val1, uint256 accuracy) public {
        uint256 diff  = val0 > val1 ? val0 - val1 : val1 - val0;
        if (diff == 0) return;

        uint256 denominator = val0 == 0 ? val1 : val0;
        bool check = ((diff * RAY) / denominator) < (RAY / 10 ** accuracy);

        if (!check){
            emit log_named_uint("Error: approx a == b not satisfied, accuracy digits ", accuracy);
            emit log_named_uint("  Expected", val0);
            emit log_named_uint("    Actual", val1);
            fail();
        }
    }

    // Verify equality within difference.
    function withinDiff(uint256 val0, uint256 val1, uint256 expectedDiff) public {
        uint256 actualDiff = val0 > val1 ? val0 - val1 : val1 - val0;
        bool check = actualDiff <= expectedDiff;

        if (!check) {
            emit log_named_uint("Error: approx a == b not satisfied, accuracy difference ", expectedDiff);
            emit log_named_uint("  Expected", val0);
            emit log_named_uint("    Actual", val1);
            fail();
        }
    }

    function constrictToRange(uint256 val, uint256 min, uint256 max) public pure returns (uint256) {
        return constrictToRange(val, min, max, false);
    }

    function constrictToRange(uint256 val, uint256 min, uint256 max, bool nonZero) public pure returns (uint256) {
        if      (val == 0 && !nonZero) return 0;
        else if (max == min)           return max;
        else                           return val % (max - min) + min;
    }

    // DAO vars

    // enum PollType {
    //     taxChange,
    //     funding,
    //     setDao,
    //     setCex,
    //     setDex,
    //     updateDividendToken,
    //     updateMarketingWallet,
    //     updateTeamWallet,
    //     updateTeamMember,
    //     updateVetoAuthority,
    //     setVetoEnabled,
    //     setSwapTokensAtAmount,
    //     setBuyBackEnabled,
    //     setCakeDividendEnabled,
    //     setMarketingEnabled,
    //     setTeamEnabled,
    //     updateCakeDividendTracker,
    //     updateUniswapV2Router,
    //     excludeFromFees,
    //     excludeFromDividends,
    //     updateGasForProcessing,
    //     updateMinimumBalanceForDividends,
    //     modifyBlacklist,
    //     transferOwnership,
    //     migrateTreasury,
    //     setQuorum,
    //     setMinPollPeriod,
    //     updateGovernanceToken,
    //     other
    // }

    struct TaxChange {
        string description;
        uint256 startTime;
        uint256 endTime;
        uint8 cakeDividendRewardsFee;
        uint8 marketingFee;
        uint8 buyBackAndLiquidityFee;
        uint8 teamFee;
        uint8 transferMultiplier;
    }

    struct Funding {
        string description;
        uint256 startTime;
        uint256 endTime;
        address payable recipient;
        address token;
        uint256 amount;
    }

    struct SetDao {
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

    struct SetCex {
        string description;
        uint256 startTime;
        uint256 endTime;
        address addr; 
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

    struct SetBuyBackAndLiquifyEnabled {
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