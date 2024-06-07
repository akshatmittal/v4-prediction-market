// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import { IHooks } from "v4-core/src/interfaces/IHooks.sol";
import { Hooks } from "v4-core/src/libraries/Hooks.sol";
import { TickMath } from "v4-core/src/libraries/TickMath.sol";
import { IPoolManager } from "v4-core/src/interfaces/IPoolManager.sol";
import { PoolKey } from "v4-core/src/types/PoolKey.sol";
import { BalanceDelta } from "v4-core/src/types/BalanceDelta.sol";
import { PoolId, PoolIdLibrary } from "v4-core/src/types/PoolId.sol";
import { CurrencyLibrary, Currency } from "v4-core/src/types/Currency.sol";
import { PoolSwapTest } from "v4-core/src/test/PoolSwapTest.sol";
import { Deployers, SortTokens } from "v4-core/test/utils/Deployers.sol";
import { HookMiner } from "./utils/HookMiner.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { Constants } from "v4-core/test/utils/Constants.sol";

import { TradeLimitHook } from "../src/TradeLimitHook.sol";
import { PredictionMarket, OutcomeToken } from "../src/PredictionMarket.sol";

contract TradeLimitHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    TradeLimitHook limitHook;
    PoolId poolId;

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        Deployers.deployFreshManagerAndRouters();
        Deployers.deployMintAndApprove2Currencies();

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_INITIALIZE_FLAG);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(address(this), flags, type(TradeLimitHook).creationCode, abi.encode(address(manager)));

        limitHook = new TradeLimitHook{ salt: salt }(IPoolManager(address(manager)));
        require(address(limitHook) == hookAddress, "MarketHookTest: hook address mismatch");

        // Create the pool
        // key = PoolKey(currency0, currency1, 3000, 60, IHooks(address(limitHook)));
        // poolId = key.toId();
        // manager.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);

        // // Provide liquidity to the pool
        // modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-60, 60, 10 ether, 0), ZERO_BYTES);
        // modifyLiquidityRouter.modifyLiquidity(
        //     key, IPoolManager.ModifyLiquidityParams(-120, 120, 10 ether, 0), ZERO_BYTES
        // );
        // modifyLiquidityRouter.modifyLiquidity(
        //     key,
        //     IPoolManager.ModifyLiquidityParams(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 10 ether, 0),
        //     ZERO_BYTES
        // );
    }

    function test_launchFull() public {
        address user = address(1);
        address creator = address(2);

        MockERC20 collateral = new MockERC20("USD Coin", "USDC", 6);

        vm.startPrank(creator);
        // Create Prediction Market
        PredictionMarket predictionMarket = new PredictionMarket(address(collateral), 2);
        collateral.mint(creator, 3000 * 10 ** 6);
        collateral.approve(address(predictionMarket), 1000 * 10 ** 6);
        predictionMarket.mint(1000 * 10 ** 6);
        for (uint256 i = 0; i < 2; ++i) {
            OutcomeToken outcomeToken = predictionMarket.outcomeTokens(i);
            assertEq(outcomeToken.balanceOf(creator), 1000 * 10 ** 6);
        }

        // Approvals
        address[8] memory toApprove = [
            address(swapRouter),
            address(swapRouterNoChecks),
            address(modifyLiquidityRouter),
            address(modifyLiquidityNoChecks),
            address(donateRouter),
            address(takeRouter),
            address(claimsRouter),
            address(nestedActionRouter.executor())
        ];

        for (uint256 i = 0; i < toApprove.length; i++) {
            collateral.approve(toApprove[i], Constants.MAX_UINT256);
            predictionMarket.outcomeTokens(0).approve(toApprove[i], Constants.MAX_UINT256);
            predictionMarket.outcomeTokens(1).approve(toApprove[i], Constants.MAX_UINT256);
        }

        // Add liquidity
        Currency currency0_;
        Currency currency1_;

        (currency0_, currency1_) =
            SortTokens.sort(MockERC20(address(predictionMarket.outcomeTokens(0))), MockERC20(address(collateral)));
        PoolKey memory keyP1 = PoolKey(currency0_, currency1_, 3000, 1, IHooks(address(limitHook)));
        (currency0_, currency1_) =
            SortTokens.sort(MockERC20(address(predictionMarket.outcomeTokens(1))), MockERC20(address(collateral)));
        PoolKey memory keyP2 = PoolKey(currency0_, currency1_, 3000, 1, IHooks(address(limitHook)));
        manager.initialize(keyP1, SQRT_PRICE_1_1, ZERO_BYTES);
        manager.initialize(keyP2, SQRT_PRICE_1_1, ZERO_BYTES);

        modifyLiquidityRouter.modifyLiquidity(
            keyP1,
            IPoolManager.ModifyLiquidityParams(
                TickMath.getTickAtSqrtPrice(Constants.SQRT_PRICE_1_2),
                TickMath.getTickAtSqrtPrice(Constants.SQRT_PRICE_2_1),
                1000 * 10 ** 6,
                0
            ),
            ZERO_BYTES
        );
        modifyLiquidityRouter.modifyLiquidity(
            keyP2,
            IPoolManager.ModifyLiquidityParams(
                TickMath.getTickAtSqrtPrice(Constants.SQRT_PRICE_1_2),
                TickMath.getTickAtSqrtPrice(Constants.SQRT_PRICE_2_1),
                1000 * 10 ** 6,
                0
            ),
            ZERO_BYTES
        );
        vm.stopPrank();

        vm.startPrank(user);
        // So here's the kicker, I can mint both and trade in the tokens via the pool
        // to get exactly the leverage I want on the outcome.
        collateral.mint(user, 100 * 10 ** 6);
        collateral.approve(address(predictionMarket), 100 * 10 ** 6);
        predictionMarket.mint(100 * 10 ** 6);
        for (uint256 i = 0; i < 2; ++i) {
            OutcomeToken outcomeToken = predictionMarket.outcomeTokens(i);
            assertEq(outcomeToken.balanceOf(user), 100 * 10 ** 6);
        }

        // Note: Swap Router currently does not support multi-hop swaps so we'll do it manually.
        predictionMarket.outcomeTokens(0).approve(address(swapRouter), 100 * 10 ** 6);
        swapRouter.swap(
            keyP1,
            IPoolManager.SwapParams({
                zeroForOne: keyP1.currency0 == Currency.wrap(address(predictionMarket.outcomeTokens(0))),
                amountSpecified: -100e6,
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ZERO_BYTES
        );
        collateral.approve(address(swapRouter), 100 * 10 ** 6);
        swapRouter.swap(
            keyP2,
            IPoolManager.SwapParams({
                zeroForOne: keyP2.currency0 == Currency.wrap(address(collateral)),
                amountSpecified: -1 * int256(collateral.balanceOf(user)),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ZERO_BYTES
        );

        for (uint256 i = 0; i < 2; ++i) {
            OutcomeToken outcomeToken = predictionMarket.outcomeTokens(i);
            console2.log(outcomeToken.balanceOf(user));
        }
        assertGt(predictionMarket.outcomeTokens(1).balanceOf(user), 100 * 10 ** 6);
        // ^ this is expected to be around 1.82x outcome
        // Math excluding fees: (1000+1000+200)/(1000+200)

        vm.stopPrank();
    }
}
