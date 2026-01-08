// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ProtardioTreasury} from "../src/ProtardioTreasury.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";

// Mock ERC721 for testing
contract MockERC721 {
    string public name = "Protardio";
    string public symbol = "PROT";

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    function mint(address to, uint256 tokenId) external {
        _owners[tokenId] = to;
        _balances[to]++;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return _owners[tokenId];
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }

    function approve(address to, uint256 tokenId) external {
        _tokenApprovals[tokenId] = to;
    }

    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        require(_owners[tokenId] == from, "Not owner");
        require(
            msg.sender == from || _tokenApprovals[tokenId] == msg.sender || _operatorApprovals[from][msg.sender],
            "Not approved"
        );
        _owners[tokenId] = to;
        _balances[from]--;
        _balances[to]++;
        delete _tokenApprovals[tokenId];
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}

contract ProtardioTreasuryTest is Test {
    ProtardioTreasury public treasury;
    MockERC721 public nft;

    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    uint256 public constant SWAP_PRICE = 0.002 ether; // ~$5 at $2500/ETH

    function setUp() public {
        nft = new MockERC721();
        treasury = new ProtardioTreasury(address(nft), SWAP_PRICE);

        // Mint NFTs to owner for treasury deposit
        for (uint256 i = 1; i <= 10; i++) {
            nft.mint(owner, i);
        }

        // Mint NFTs to users
        nft.mint(user1, 100);
        nft.mint(user1, 101);
        nft.mint(user2, 200);

        // Give users some ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function test_InitialState() public view {
        assertEq(treasury.owner(), owner);
        assertEq(address(treasury.protardioNFT()), address(nft));
        assertEq(treasury.swapPrice(), SWAP_PRICE);
        assertEq(treasury.treasurySize(), 0);
    }

    function test_DepositNFTs() public {
        uint256[] memory tokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            tokenIds[i] = i + 1;
            nft.approve(address(treasury), i + 1);
        }

        treasury.depositNFTs(tokenIds);

        assertEq(treasury.treasurySize(), 5);
        for (uint256 i = 0; i < 5; i++) {
            assertTrue(treasury.isInTreasury(i + 1));
        }
    }

    function test_Swap() public {
        // Deposit NFTs to treasury
        uint256[] memory tokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            tokenIds[i] = i + 1;
            nft.approve(address(treasury), i + 1);
        }
        treasury.depositNFTs(tokenIds);

        // User1 swaps their NFT #100 for treasury NFT #3
        vm.startPrank(user1);
        nft.approve(address(treasury), 100);
        treasury.swap{value: SWAP_PRICE}(100, 3);
        vm.stopPrank();

        // Verify swap
        assertEq(nft.ownerOf(3), user1); // User got NFT #3
        assertEq(nft.ownerOf(100), address(treasury)); // Treasury got NFT #100
        assertTrue(treasury.isInTreasury(100)); // NFT #100 is in treasury
        assertFalse(treasury.isInTreasury(3)); // NFT #3 is no longer in treasury
        assertEq(treasury.treasurySize(), 5); // Size unchanged
    }

    function test_SwapRefundsExcessETH() public {
        // Deposit NFT
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        nft.approve(address(treasury), 1);
        treasury.depositNFTs(tokenIds);

        uint256 userBalanceBefore = user1.balance;

        vm.startPrank(user1);
        nft.approve(address(treasury), 100);
        treasury.swap{value: 1 ether}(100, 1); // Send way more than needed
        vm.stopPrank();

        // User should get refund of excess
        assertEq(user1.balance, userBalanceBefore - SWAP_PRICE);
    }

    function test_RevertSwapInsufficientETH() public {
        // Deposit NFT
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        nft.approve(address(treasury), 1);
        treasury.depositNFTs(tokenIds);

        vm.startPrank(user1);
        nft.approve(address(treasury), 100);
        vm.expectRevert("Insufficient ETH sent");
        treasury.swap{value: SWAP_PRICE - 1}(100, 1);
        vm.stopPrank();
    }

    function test_RevertSwapTokenNotInTreasury() public {
        // Deposit NFT
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        nft.approve(address(treasury), 1);
        treasury.depositNFTs(tokenIds);

        vm.startPrank(user1);
        nft.approve(address(treasury), 100);
        vm.expectRevert("Token not in treasury");
        treasury.swap{value: SWAP_PRICE}(100, 999); // Token 999 doesn't exist in treasury
        vm.stopPrank();
    }

    function test_SetSwapPrice() public {
        uint256 newPrice = 0.005 ether;
        treasury.setSwapPrice(newPrice);
        assertEq(treasury.swapPrice(), newPrice);
    }

    function test_RevertSetSwapPriceNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Not owner");
        treasury.setSwapPrice(0.005 ether);
    }

    function test_WithdrawETH() public {
        // Deposit and perform swap to accumulate ETH
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        nft.approve(address(treasury), 1);
        treasury.depositNFTs(tokenIds);

        vm.startPrank(user1);
        nft.approve(address(treasury), 100);
        treasury.swap{value: SWAP_PRICE}(100, 1);
        vm.stopPrank();

        // Withdraw ETH to user2 (an EOA that can receive ETH)
        uint256 user2BalanceBefore = user2.balance;
        treasury.withdrawETH(user2);
        assertEq(user2.balance, user2BalanceBefore + SWAP_PRICE);
    }

    function test_WithdrawNFT() public {
        // Deposit NFT
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        nft.approve(address(treasury), 1);
        treasury.depositNFTs(tokenIds);

        // Withdraw NFT
        treasury.withdrawNFT(1, owner);
        assertEq(nft.ownerOf(1), owner);
        assertFalse(treasury.isInTreasury(1));
        assertEq(treasury.treasurySize(), 0);
    }

    function test_TransferOwnership() public {
        treasury.transferOwnership(user1);
        assertEq(treasury.owner(), user1);
    }

    function test_GetTreasuryTokenIds() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        for (uint256 i = 0; i < 3; i++) {
            nft.approve(address(treasury), tokenIds[i]);
        }
        treasury.depositNFTs(tokenIds);

        uint256[] memory treasuryIds = treasury.getTreasuryTokenIds();
        assertEq(treasuryIds.length, 3);
    }
}
