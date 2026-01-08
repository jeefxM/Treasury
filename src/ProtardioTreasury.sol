// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC721, IERC721TokenReceiver} from "forge-std/interfaces/IERC721.sol";

contract ProtardioTreasury is IERC721TokenReceiver {
    address public owner;
    IERC721 public immutable protardioNFT;
    uint256 public swapPrice; // Price in wei (e.g., $5 worth of ETH)

    uint256[] public treasuryTokenIds;
    mapping(uint256 => uint256) private tokenIdToIndex; // tokenId => index + 1 (0 means not in treasury)

    event NFTDeposited(uint256 indexed tokenId);
    event NFTSwapped(address indexed user, uint256 sentTokenId, uint256 receivedTokenId, uint256 paidAmount);
    event SwapPriceUpdated(uint256 newPrice);
    event ETHWithdrawn(address indexed to, uint256 amount);
    event NFTWithdrawn(uint256 indexed tokenId, address indexed to);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _protardioNFT, uint256 _swapPrice) {
        owner = msg.sender;
        protardioNFT = IERC721(_protardioNFT);
        swapPrice = _swapPrice;
    }

    /// @notice Deposit NFTs into the treasury (owner only)
    /// @param tokenIds Array of token IDs to deposit
    function depositNFTs(uint256[] calldata tokenIds) external onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            protardioNFT.transferFrom(msg.sender, address(this), tokenId);
            _addToTreasury(tokenId);
            emit NFTDeposited(tokenId);
        }
    }

    /// @notice Swap user's NFT for one from the treasury
    /// @param userTokenId The token ID the user is sending
    /// @param desiredTokenId The token ID the user wants from treasury
    function swap(uint256 userTokenId, uint256 desiredTokenId) external payable {
        require(msg.value >= swapPrice, "Insufficient ETH sent");
        require(treasuryTokenIds.length > 0, "Treasury empty");
        require(tokenIdToIndex[desiredTokenId] > 0, "Token not in treasury");

        // Remove desired token from treasury
        _removeFromTreasury(desiredTokenId);

        // Transfer user's NFT to treasury
        protardioNFT.transferFrom(msg.sender, address(this), userTokenId);
        _addToTreasury(userTokenId);

        // Transfer treasury NFT to user
        protardioNFT.transferFrom(address(this), msg.sender, desiredTokenId);

        // Refund excess ETH
        if (msg.value > swapPrice) {
            (bool success,) = msg.sender.call{value: msg.value - swapPrice}("");
            require(success, "Refund failed");
        }

        emit NFTSwapped(msg.sender, userTokenId, desiredTokenId, swapPrice);
    }

    /// @notice Update the swap price (owner only)
    function setSwapPrice(uint256 _newPrice) external onlyOwner {
        swapPrice = _newPrice;
        emit SwapPriceUpdated(_newPrice);
    }

    /// @notice Withdraw accumulated ETH fees (owner only)
    function withdrawETH(address to) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        (bool success,) = to.call{value: balance}("");
        require(success, "Transfer failed");
        emit ETHWithdrawn(to, balance);
    }

    /// @notice Emergency withdraw NFT from treasury (owner only)
    function withdrawNFT(uint256 tokenId, address to) external onlyOwner {
        require(tokenIdToIndex[tokenId] > 0, "Token not in treasury");
        _removeFromTreasury(tokenId);
        protardioNFT.transferFrom(address(this), to, tokenId);
        emit NFTWithdrawn(tokenId, to);
    }

    /// @notice Transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }

    /// @notice Get all token IDs in treasury
    function getTreasuryTokenIds() external view returns (uint256[] memory) {
        return treasuryTokenIds;
    }

    /// @notice Get treasury size
    function treasurySize() external view returns (uint256) {
        return treasuryTokenIds.length;
    }

    /// @notice Check if a token is in the treasury
    function isInTreasury(uint256 tokenId) external view returns (bool) {
        return tokenIdToIndex[tokenId] > 0;
    }

    function _addToTreasury(uint256 tokenId) private {
        treasuryTokenIds.push(tokenId);
        tokenIdToIndex[tokenId] = treasuryTokenIds.length; // index + 1
    }

    function _removeFromTreasury(uint256 tokenId) private {
        uint256 index = tokenIdToIndex[tokenId] - 1;
        uint256 lastIndex = treasuryTokenIds.length - 1;

        if (index != lastIndex) {
            uint256 lastTokenId = treasuryTokenIds[lastIndex];
            treasuryTokenIds[index] = lastTokenId;
            tokenIdToIndex[lastTokenId] = index + 1;
        }

        treasuryTokenIds.pop();
        delete tokenIdToIndex[tokenId];
    }

    /// @notice Required for receiving ERC721 tokens
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721TokenReceiver.onERC721Received.selector;
    }

    receive() external payable {}
}
