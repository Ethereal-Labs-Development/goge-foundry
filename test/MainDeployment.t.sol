// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";

import { IUniswapV2Router02, IUniswapV2Pair, IUniswapV2Router01, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";

import { DogeGaySon } from "../src/GogeToken.sol";
import { DogeGaySon1 } from "../src/TokenV1.sol";
import { GogeDAO } from "../src/GogeDao.sol";

contract MainDeploymentTesting is Utility, Test {


}