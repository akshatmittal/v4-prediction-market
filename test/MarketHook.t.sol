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
import { Deployers } from "v4-core/test/utils/Deployers.sol";
import { HookMiner } from "./utils/HookMiner.sol";

import { MarketHook } from "../src/MarketHook.sol";

contract MarketHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    MarketHook marketHook;
    PoolId poolId;

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        Deployers.deployFreshManagerAndRouters();
        Deployers.deployMintAndApprove2Currencies();

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_INITIALIZE_FLAG);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(address(this), flags, type(MarketHook).creationCode, abi.encode(address(manager)));
        marketHook = new MarketHook{ salt: salt }(IPoolManager(address(manager)));
        require(address(marketHook) == hookAddress, "MarketHookTest: hook address mismatch");

        // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(address(marketHook)));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);

        // Provide liquidity to the pool
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-60, 60, 10 ether, 0), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-120, 120, 10 ether, 0), ZERO_BYTES
        );
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 10 ether, 0),
            ZERO_BYTES
        );
    }
}
