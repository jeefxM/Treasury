// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {TestNFT} from "../src/TestNFT.sol";
import {ProtardioTreasury} from "../src/ProtardioTreasury.sol";

contract DeployLocal is Script {
    uint256 public constant SWAP_PRICE = 0.002 ether; // ~$5

    // Anvil default accounts
    uint256 constant OWNER_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 constant USER_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    function run() public {
        address owner = vm.addr(OWNER_KEY);
        address user = vm.addr(USER_KEY);

        console.log("Owner:", owner);
        console.log("User:", user);

        // === OWNER: Deploy and setup treasury ===
        vm.startBroadcast(OWNER_KEY);

        TestNFT nft = new TestNFT();
        console.log("TestNFT deployed:", address(nft));

        ProtardioTreasury treasury = new ProtardioTreasury(address(nft), SWAP_PRICE);
        console.log("Treasury deployed:", address(treasury));

        // Mint NFTs 1-10 to owner for treasury
        uint256[] memory treasuryTokenIds = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            treasuryTokenIds[i] = i + 1;
        }
        nft.mintBatch(owner, treasuryTokenIds);

        // Deposit into treasury
        nft.setApprovalForAll(address(treasury), true);
        treasury.depositNFTs(treasuryTokenIds);
        console.log("Treasury loaded with NFTs 1-10");

        // Mint NFT #100 to user for testing
        nft.mint(user, 100);
        console.log("Minted NFT #100 to user");

        vm.stopBroadcast();

        // === USER: Perform swap ===
        console.log("");
        console.log("=== USER SWAP TEST ===");
        console.log("User ETH before:", user.balance);
        console.log("NFT #100 owner:", nft.ownerOf(100));
        console.log("NFT #5 owner:", nft.ownerOf(5));

        vm.startBroadcast(USER_KEY);

        // TX 1: Approve
        nft.approve(address(treasury), 100);
        console.log("TX1: Approved treasury for NFT #100");

        // TX 2: Swap (sends 0.002 ETH + receives NFT #5)
        treasury.swap{value: SWAP_PRICE}(100, 5);
        console.log("TX2: Swapped NFT #100 + 0.002 ETH for NFT #5");

        vm.stopBroadcast();

        console.log("");
        console.log("=== RESULTS ===");
        console.log("NFT #100 owner:", nft.ownerOf(100));
        console.log("NFT #5 owner:", nft.ownerOf(5));
        console.log("Treasury ETH balance:", address(treasury).balance);
        console.log("User paid:", SWAP_PRICE, "wei (0.002 ETH)");
    }
}
