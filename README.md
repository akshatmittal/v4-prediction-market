# Prediction Market using Uniswap V4 & EigenLayer AVS

Prediction Markets are the core to speculation on real world events onchain. They are used to predict the outcome of future events, and based on research data they are often extremely accurate in reflecting the probability of an event occurring.

All current Prediction Markets built onchain are based on outcome balancing via Order Book Market Makers. This is especially visible on platforms like Polymarket where the two prices closest to the current ratio are incentivized in order to promote liquidity in a market making environment.

AMMs are inherently superior to order book based markets in terms of liquidity and ease of use. This is why we are proposing a new type of Prediction Market that uses Uniswap V4 as the core liquidity provider.

Links: [Google Doc](https://docs.google.com/document/d/15qUy6l46U3SvTLFDROUJ4Olyd00WRl2oIMNsjYOLz50/edit?usp=sharing) | [YouTube Video](https://www.youtube.com/watch?v=dcGOpjjed8I) | [GitHub Repo](https://github.com/akshatmittal/v4-prediction-market)

## How does the market work?

The Prediction Market is designed to operate with a collateral token, each market/question can have its own collateral token. The market then creates `n` outcome tokens each representing a different outcome of the event. The market creator then seeds the initial liquidity which can be as little as 1 token per outcome, the great thing about using bonded markets is that the liquidity _always_ sums up to 1 in the end, so anyone can effectively enter a market with no loss based on outcome while still earning liquidity fees.

For each outcome token, a separate pool is initialized against the collateral token with a 1:1 ratio, while the liquidity bounds are set to two known values which are equidistant from tick `0`. This ensures that the pool impact in either direction is matched across all pools.

The core Prediction Market contract is able to mint all outcome tokens in a balanced ratio per collateral token deposited, which can then be traded in the pools to go long or short on any one outcome. The final result of trades represent the _exact_ number you'd expect in a prediction market. (See math in tests)

TODO: Write MEV considerations for pool rebalancing. (minor)

## Uniswap V4

With hooks in Uniswap V4, it is now possible to create bonded pools. Essentially pools that share at least one token and are (effectively) bonded together based on ratio of outcome tokens in the Prediction Market.

The hook is used for specific actions related to the market. It is initially used to ensure the market is created at the right price, along with the right tokens and with valid prediction market relation. Second, it is used to ensure all liquidity is always added to _all_ available range (note, this is not full range, just known range), and finally to ensure that trading stops once an outcome is available and the market is resolved.

## EigenLayer AVS

One of the core requirements for a Prediction Market is the ability to resolve the market. This is done via EigenLayer AVS, which given it's decentralized nature is able to provide a reliable and secure resolution for the market. The operators stake on the `Manager` contract which is then able to accept resolutions and run `DisputeGameFactory` based on attestations.

## Features

1. Fully Featured Prediction Market
2. Bonded Liquidity Pools (Follows Market Ratio Method)
3. Uniswap V4 Integration - Every market interaction happens entirely via Uniswap V4 for users.
4. EigenLayer AVS Integration - Secure and reliable market resolution.
5. Support for `2` to `n` possible outcomes.
6. Built in `Manager` for AVS resolution.
