pragma solidity ^0.8.10;

import "../lib/forge-std/src/Script.sol";
import "src/GogeDao.sol";

contract DeployDao is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // TODO: Update token address param to mainnet when deploying to BSC
        GogeDAO gogeDao = new GogeDAO(0x1618efC9867F3Bd7D2bf80ce5f7E6174Fd3bEf96);

        vm.stopBroadcast();
    }
}