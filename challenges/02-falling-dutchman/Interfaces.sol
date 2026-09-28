// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IUniswapV1Factory {
    function getExchange(address token) external view returns (address exchange);
}

interface IUniswapV1Exchange {
    function ethToTokenSwapInput(uint256 minTokens, uint256 deadline) external payable returns (uint256 tokensBought);
}

interface IDutchX {
    function getAuctionIndex(address sellToken, address buyToken) external view returns (uint256);
    function deposit(address token, uint256 amount) external returns (uint256 newBalance);
    function postBuyOrder(address sellToken, address buyToken, uint256 auctionIndex, uint256 amount)
        external
        returns (uint256 newBuyerBalance);
    function claimBuyerFunds(address sellToken, address buyToken, address user, uint256 auctionIndex)
        external
        returns (uint256 returned, uint256 frtsIssued);
    function withdraw(address token, uint256 amount) external returns (uint256 newBalance);
}
