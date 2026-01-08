// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {TestNFT} from "../src/TestNFT.sol";
import {ProtardioTreasury} from "../src/ProtardioTreasury.sol";

contract DeployTest is Script {
    // Swap price: ~$5 in ETH (0.002 ETH at ~$2500/ETH)
    uint256 public constant SWAP_PRICE = 0.002 ether;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy TestNFT
        TestNFT nft = new TestNFT();
        console.log("TestNFT deployed at:", address(nft));

        // 2. Deploy Treasury
        ProtardioTreasury treasury = new ProtardioTreasury(address(nft), SWAP_PRICE);
        console.log("Treasury deployed at:", address(treasury));

        // 3. Mint NFTs for treasury (token IDs 1-10)
        uint256[] memory treasuryTokenIds = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            treasuryTokenIds[i] = i + 1;
        }
        nft.mintBatch(deployer, treasuryTokenIds);
        console.log("Minted NFTs 1-10 to deployer for treasury");

        // 4. Mint NFTs for "user" testing (token IDs 100-105)
        uint256[] memory userTokenIds = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            userTokenIds[i] = 100 + i;
        }
        nft.mintBatch(deployer, userTokenIds);
        console.log("Minted NFTs 100-105 to deployer for user testing");

        // 5. Approve treasury and deposit NFTs 1-10
        nft.setApprovalForAll(address(treasury), true);
        treasury.depositNFTs(treasuryTokenIds);
        console.log("Deposited NFTs 1-10 into treasury");

        vm.stopBroadcast();

        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("TestNFT:", address(nft));
        console.log("Treasury:", address(treasury));
        console.log("Swap Price:", SWAP_PRICE, "wei");
        console.log("");
        console.log("Treasury has NFTs: 1-10");
        console.log("You own NFTs: 100-105 (for swap testing)");
        console.log("");
        console.log("To test swap:");
        console.log("1. Approve treasury for NFT 100: nft.approve(treasury, 100)");
        console.log("2. Swap: treasury.swap{value: 0.002 ether}(100, 1)");
    }
}
