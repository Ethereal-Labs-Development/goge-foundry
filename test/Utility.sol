// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.6;

import "../src/users/Actor.sol";
import "../lib/forge-std/src/Test.sol";


// NOTE: All contract addresses provided below have been configured for a Binance Smart Chain contract.

contract Utility is Test {

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

    event Debug(string, uint256);
    event Debug(string, address);
    event Debug(string, bool);
    event Debug(string, string);

    constructor() public {}

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
    
}