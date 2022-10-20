// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20 } from "../interfaces/Interfaces.sol";

contract Actor {

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/


    //////////////////////////////////////////////////////////////////////////
    ///                             GOGE TOKEN                             ///
    //////////////////////////////////////////////////////////////////////////


    function try_transferToken(address token, address to, uint256 amt) external returns (bool ok) {
        string memory sig = "transfer(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amt));
    }

    function try_transferFromToken(address token, address from, address to, uint256 amt) external returns (bool ok) {
        string memory sig = "transferFrom(address,address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amt));
    }

    function try_approveToken(address token, address to, uint256 amt) external returns (bool ok) {
        string memory sig = "approve(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amt));
    }

    function try_increaseAllowance(address token, address account, uint amt) external returns (bool ok) {
        string memory sig = "increaseAllowance(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amt));
    }

    function try_decreaseAllowance(address token, address account, uint amt) external returns (bool ok) {
        string memory sig = "decreaseAllowance(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amt));
    }

    function try_updateStable(address treasury, address stablecoin) external returns (bool ok) {
        string memory sig = "updateStable(address)";
        (ok,) = address(treasury).call(abi.encodeWithSignature(sig, stablecoin));
    }

    function try_enableTrading(address token) external returns (bool ok) {
        string memory sig = "enableTrading()";
        (ok,) = address(token).call(abi.encodeWithSignature(sig));
    }

    function try_modifyBlacklist(address token, address account, bool blacklisted) external returns (bool ok) {
        string memory sig = "modifyBlacklist(address,bool)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, blacklisted));
    }
}