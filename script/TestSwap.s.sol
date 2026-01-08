// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {TestNFT} from "../src/TestNFT.sol";
import {ProtardioTreasury} from "../src/ProtardioTreasury.sol";

contract TestSwap is Script {
    // Deployed addresses on Base Sepolia
    address constant NFT_ADDRESS = 0x2ad52D0DDA18d03B2ADeFBB0E242b5E7e4F319f0;
    address constant TREASURY_ADDRESS = 0x4575a3c03D3d0818a44aB2960163d277C53adad0;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        TestNFT nft = TestNFT(NFT_ADDRESS);
        ProtardioTreasury treasury = ProtardioTreasury(payable(TREASURY_ADDRESS));

        console.log("=== BEFORE SWAP ===");
        console.log("User address:", deployer);
        console.log("User ETH balance:", deployer.balance);
        console.log("Owner of NFT #100:", nft.ownerOf(100));
        console.log("Owner of NFT #1:", nft.ownerOf(1));
        console.log("Treasury size:", treasury.treasurySize());
        console.log("Swap price:", treasury.swapPrice());

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Approve treasury for NFT #100
        console.log("");
        console.log("Step 1: Approving treasury for NFT #100...");
        nft.approve(TREASURY_ADDRESS, 100);

        // Step 2: Swap NFT #100 for treasury NFT #1
        console.log("Step 2: Swapping NFT #100 + 0.002 ETH for NFT #1...");
        treasury.swap{value: 0.002 ether}(100, 1);

        vm.stopBroadcast();

        console.log("");
        console.log("=== AFTER SWAP ===");
        console.log("Owner of NFT #100:", nft.ownerOf(100));
        console.log("Owner of NFT #1:", nft.ownerOf(1));
        console.log("Treasury size:", treasury.treasurySize());
        console.log("Is NFT #100 in treasury?", treasury.isInTreasury(100));
        console.log("Is NFT #1 in treasury?", treasury.isInTreasury(1));
        console.log("Treasury ETH balance:", TREASURY_ADDRESS.balance);
    }
}
