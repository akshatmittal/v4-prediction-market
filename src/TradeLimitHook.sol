// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseHook } from "v4-periphery/BaseHook.sol";

import { Hooks } from "v4-core/src/libraries/Hooks.sol";
import { IPoolManager } from "v4-core/src/interfaces/IPoolManager.sol";
import { PoolKey } from "v4-core/src/types/PoolKey.sol";
import { PoolId, PoolIdLibrary } from "v4-core/src/types/PoolId.sol";
import { CurrencySettleTake } from "v4-core/src/libraries/CurrencySettleTake.sol";
import { BalanceDelta } from "v4-core/src/types/BalanceDelta.sol";
import { BeforeSwapDelta, BeforeSwapDeltaLibrary } from "v4-core/src/types/BeforeSwapDelta.sol";
import { Constants } from "v4-core/test/utils/Constants.sol";
import { TickMath } from "v4-core/src/libraries/TickMath.sol";

// import "forge-std/console2.sol";

contract TradeLimitHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    // using CurrencySettleTake for Currency;

    error NotAllowed();

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) { }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeInitialize(address, PoolKey calldata key, uint160 sqrtPriceX96, bytes calldata hookData)
        external
        override
        returns (bytes4)
    {
        // Require starting price to be 1:1
        require(sqrtPriceX96 == Constants.SQRT_PRICE_1_1, "TradeLimitHook: Invalid sqrtPriceX96");

        return BaseHook.beforeInitialize.selector;
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        // TODO: Add check here.

        return (BaseHook.afterSwap.selector, 0);
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata
    ) external override returns (bytes4) {
        // Bound liquidity provision to a specific price range
        // These can theoretically be any tick range, these are just known good values
        require(params.tickLower >= TickMath.getTickAtSqrtPrice(Constants.SQRT_PRICE_1_2));
        require(params.tickUpper <= TickMath.getTickAtSqrtPrice(Constants.SQRT_PRICE_2_1));

        return BaseHook.beforeAddLiquidity.selector;
    }
}
