// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ProtardioTreasury} from "../src/ProtardioTreasury.sol";

contract DeployProtardioTreasury is Script {
    // Protardio NFT contract on Base Sepolia
    address public constant PROTARDIO_NFT = 0x5d38451841Ee7A2E824A88AFE47b00402157b08d;

    // Swap price: ~$5 in ETH (adjust based on current ETH price)
    // At ETH = $2500, $6 = 0.002 ETH
    uint256 public constant SWAP_PRICE = 0.002 ether;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        ProtardioTreasury treasury = new ProtardioTreasury(PROTARDIO_NFT, SWAP_PRICE);

        console.log("ProtardioTreasury deployed at:", address(treasury));
        console.log("Protardio NFT:", PROTARDIO_NFT);
        console.log("Swap price:", SWAP_PRICE);

        vm.stopBroadcast();
    }
}
