// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IGogeERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function getCirculatingMinusReserve() external view returns (uint256);
    function getLastReceived(address voter) external view returns (uint256);
    function updateFees(uint8 _rewardFee, uint8 _marketingFee, uint8 _buybackFee, uint8 _teamFee) external;
    function setGogeDao(address _dao) external;
    function whitelistPinkSale(address _presaleAddress) external;
    function addPartnerOrExchange(address _partnerOrExchangeAddress) external;
    function updateCakeDividendToken(address _newContract) external;
    function updateTeamWallet(address _newWallet) external;
    function updateMarketingWallet(address _newWallet) external;
    function setSwapTokensAtAmount(uint256 _swapAmount) external;
    function setBuyBackEnabled(bool _enabled) external;
    function setCakeDividendEnabled(bool _enabled) external;
    function setMarketingEnabled(bool _enabled) external;
    function setTeamEnabled(bool _enabled) external;
    function updateCakeDividendTracker(address newAddress) external;
    function updateUniswapV2Router(address newAddress) external;
    function excludeFromFees(address account, bool excluded) external;
    function excludeFromDividend(address account) external;
    function setAutomatedMarketMakerPair(address pair, bool value) external;
    function excludeFromCirculatingSupply(address account, bool excluded) external;
    function updateGasForProcessing(uint256 newValue) external;
    function updateMinimumBalanceForDividends(uint256 newMinimumBalance) external;
    function processDividendTracker() external;
    function modifyBlacklist(address account, bool blacklisted) external;
    function updatePairSwapped(bool swapped) external;   
    function _transferOwnership(address newOwner) external;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
