// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/PredictionMarket.sol";

contract MockUSDC is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PredictionMarketTest is Test {
    PredictionMarket predictionMarket;
    IERC20 usdcToken;
    address user1;
    address user2;

    function setUp() public {
        user1 = address(0x1);
        user2 = address(0x2);

        usdcToken = new MockUSDC("USDC", "USDC", 6);
        MockUSDC(address(usdcToken)).mint(user1, 1000 * 10 ** 6);
        MockUSDC(address(usdcToken)).mint(user2, 1000 * 10 ** 6);

        predictionMarket = new PredictionMarket(usdcToken, 4);
    }

    function testMint() public {
        uint256 mintAmount = 100 * 10 ** 6;

        vm.startPrank(user1);
        IERC20(usdcToken).approve(address(predictionMarket), mintAmount);
        predictionMarket.mint(mintAmount);
        vm.stopPrank();

        for (uint256 i = 0; i < 4; i++) {
            ERC20 outcomeToken = predictionMarket.outcomeTokens(i);
            assertEq(outcomeToken.balanceOf(user1), mintAmount);
        }
    }

    function testSetWinner() public {
        predictionMarket.setWinner(2);
        assertEq(predictionMarket.winningOutcome(), 2);
    }

    function testClaim() public {
        uint256 mintAmount = 100 * 10 ** 6;

        // Mint tokens to user1
        vm.startPrank(user1);
        IERC20(usdcToken).approve(address(predictionMarket), mintAmount);
        predictionMarket.mint(mintAmount);
        vm.stopPrank();

        // Set the winner
        predictionMarket.setWinner(2);

        // Claim with the winning token
        vm.startPrank(user1);
        ERC20 winningToken = predictionMarket.outcomeTokens(2);
        winningToken.approve(address(predictionMarket), mintAmount);
        predictionMarket.claim(mintAmount);
        vm.stopPrank();

        // User1 should get back the minted USDC and winning token should be burned
        assertEq(usdcToken.balanceOf(user1), 1000 * 10 ** 6);
        assertEq(winningToken.balanceOf(user1), 0);
    }
}
