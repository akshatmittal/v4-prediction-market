// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/gnosispm/Market.sol";
import "../src/gnosispm/MarketMaker.sol";
import "../src/gnosispm/Event.sol";
import "../src/gnosispm/MockERC20.sol"; // MockERC20 is a mock contract for ERC20

contract MarketTest is Test {
    Market public market;
    MarketMaker marketMaker;
    //MockEvent public eventContract;
    Event public eventContract;
    MockERC20 public collateralToken;
    address public creator = address(1);
    address public buyer = address(2);
    address public seller = address(3);
    uint public fundingAmount = 1000;

    function setUp() public {
        // Deploy the mock ERC20 token
        collateralToken = new MockERC20("Mock Token", "MTK", 18, 1000000);
        collateralToken.mint(creator, 10 ** 18);
        collateralToken.mint(buyer, 10 ** 18);
        collateralToken.mint(seller, 10 ** 18);

        // Deploy the mock Event contract
        // eventContract = new MockEvent(address(collateralToken));
        eventContract = new CategoricalEvent(collateralToken, 2);

        marketMaker = new MarketMaker();

        // Deploy the Market contract
        market = new Market(creator, eventContract, marketMaker, 10000);

        // Initialize the Market contract
        // market.initialize(address(eventContract), creator);

        // Set initial state for the Market contract
        // market.setCreator(creator);
        // market.setStage(Market.Stages.MarketCreated);
        // market.setFee(10000); // 1% fee
    }

    function testFundMarket() public {
        vm.startPrank(creator);
        // collateralToken.approve(address(eventContract), fundingAmount);
        collateralToken.approve(address(market), fundingAmount);
        market.fund(fundingAmount);
        vm.stopPrank();

        assertEq(market.funding(), fundingAmount);
        assertEq(uint(market.stage()), uint(MarketData.Stages.MarketFunded));
    }

    function testCloseMarket() public {
        vm.startPrank(creator);
        collateralToken.approve(address(market), fundingAmount);
        market.fund(fundingAmount);
        market.close();
        vm.stopPrank();

        assertEq(uint(market.stage()), uint(MarketData.Stages.MarketClosed));
    }

    function testWithdrawFees() public {
        vm.startPrank(creator);
        collateralToken.approve(address(market), fundingAmount);
        market.fund(fundingAmount);
        uint fees = market.withdrawFees();
        vm.stopPrank();

        // No fees?
        assertEq(fees, 0);
    }

    function testBuyOutcomeTokens() public {
        vm.startPrank(creator);
        collateralToken.approve(address(market), fundingAmount);
        market.fund(fundingAmount);
        vm.stopPrank();

        vm.startPrank(buyer);
        collateralToken.approve(address(market), fundingAmount);
        uint cost = market.buy(0, 10, 100);
        vm.stopPrank();

        // TODO - is this right?
        assertGt(cost, 0);
    }

    function testSellOutcomeTokens() public {
        vm.startPrank(creator);
        collateralToken.approve(address(market), fundingAmount);
        market.fund(fundingAmount);
        vm.stopPrank();

        vm.startPrank(buyer);
        collateralToken.approve(address(market), fundingAmount * 2);
        uint cost = market.buy(0, 10, 100);

        OutcomeToken[] memory ots = eventContract.getOutcomeTokens();
        ots[0].approve(address(market), fundingAmount);
        // collateralToken.approve(address(market), fundingAmount);
        uint profit = market.sell(0, 5, 1);
        vm.stopPrank();
        assertGt(profit, 0);
    }

    function testShortSellOutcomeTokens() public {
        vm.startPrank(creator);
        collateralToken.approve(address(market), fundingAmount);
        market.fund(fundingAmount);
        vm.stopPrank();

        vm.startPrank(seller);
        // tradeImpl tries to transfer 115792089237316195423570985008687907853269984665640564039457584007913129639934
        collateralToken.approve(address(market), fundingAmount);
        uint profit = market.shortSell(0, 10, 1);
        vm.stopPrank();
        assertGt(profit, 0);
    }
}
