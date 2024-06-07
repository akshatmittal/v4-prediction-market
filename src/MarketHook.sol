// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseHook } from "v4-periphery/BaseHook.sol";

import { Hooks } from "v4-core/src/libraries/Hooks.sol";
import { IPoolManager } from "v4-core/src/interfaces/IPoolManager.sol";
import { PoolKey } from "v4-core/src/types/PoolKey.sol";
import { PoolId, PoolIdLibrary } from "v4-core/src/types/PoolId.sol";
import { Currency, CurrencySettleTake } from "v4-core/src/libraries/CurrencySettleTake.sol";
import { BalanceDelta } from "v4-core/src/types/BalanceDelta.sol";
import { BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta } from "v4-core/src/types/BeforeSwapDelta.sol";
import { Market } from "./prediction-market/Market.sol";
import { Event } from "./prediction-market/Event.sol";

contract MarketHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using CurrencySettleTake for Currency;

    error NotAllowed();

    struct MarketInitialData {
        Market market;
        Event eventContract;
        address collateralToken;
    }

    mapping(PoolId poolId => MarketInitialData marketData) public marketData;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) { }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeInitialize(address, PoolKey calldata key, uint160, bytes calldata hookData)
        external
        override
        returns (bytes4)
    {
        MarketInitialData memory data = abi.decode(hookData, (MarketInitialData));
        marketData[key.toId()] = data;

        // TODO: Validate the tokens for outcome tokens

        return BaseHook.beforeInitialize.selector;
    }

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        uint256 amountInPositive =
            params.amountSpecified > 0 ? uint256(params.amountSpecified) : uint256(-params.amountSpecified);

        BeforeSwapDelta beforeSwapDelta = toBeforeSwapDelta(
            int128(-params.amountSpecified),
            int128(params.amountSpecified) // TODO: calculate this
        );

        // MarketInitialData memory data = marketData[key.toId()];
        // ERC20 collateralToken = data.eventContract.collateralToken();

        // if (params.zeroForOne) {
        //     key.currency0.take(poolManager, address(this), amountInPositive, false);
        //     if (address(key.currency0) == address(collateralToken)) {
        //         // We are buying the outcome token here.
        //         collateralToken.approve(data.market);
        //     }
        //     // TODO: Convert from token0 to token1 via Market
        //     key.currency1.settle(poolManager, address(this), amountInPositive, false);
        // } else {
        //     key.currency0.settle(poolManager, address(this), amountInPositive, false);
        //     // TODO: Convert from token1 to token0 via Market
        //     key.currency1.take(poolManager, address(this), amountInPositive, false);
        // }

        return (BaseHook.beforeSwap.selector, beforeSwapDelta, 0);
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        revert NotAllowed();
    }
}
