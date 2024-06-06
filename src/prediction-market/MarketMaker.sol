pragma solidity ^0.8.20;

import "./Market.sol";
import "./Fixed192x64Math.sol";

/// @title LMSR market maker contract - Calculates share prices based on share distribution and initial funding
contract MarketMaker {
    /*
     *  Constants
     */
    uint256 constant ONE = 0x10000000000000000;
    int256 constant EXP_LIMIT = 3394200909562557497344;

    /*
     *  Public functions
     */
    /// @dev Calculates the net cost for executing a given trade.
    /// @param market Market contract
    /// @param outcomeTokenAmounts Amounts of outcome tokens to buy from the market. If an amount is negative, represents an amount to sell to the market.
    /// @return netCost Net cost of trade. If positive, represents amount of collateral which would be paid to the market for the trade. If negative, represents amount of collateral which would be received from the market for the trade.
    function calcNetCost(Market market, int256[] memory outcomeTokenAmounts) public view returns (int256 netCost) {
        require(market.eventContract().getOutcomeCount() > 1);
        int256[] memory netOutcomeTokensSold = getNetOutcomeTokensSold(market);

        // Calculate cost level based on net outcome token balances

        int256 log2N =
            Fixed192x64Math.binaryLog(netOutcomeTokensSold.length * ONE, Fixed192x64Math.EstimationMode.UpperBound);

        uint256 funding = market.funding();

        int256 costLevelBefore =
            calcCostLevel(log2N, netOutcomeTokensSold, funding, Fixed192x64Math.EstimationMode.LowerBound);

        // Change amounts based on outcomeTokenAmounts passed in
        require(netOutcomeTokensSold.length == outcomeTokenAmounts.length);
        for (uint8 i = 0; i < netOutcomeTokensSold.length; i++) {
            netOutcomeTokensSold[i] = netOutcomeTokensSold[i] + outcomeTokenAmounts[i];
        }

        // Calculate cost level after balance was updated
        int256 costLevelAfter =
            calcCostLevel(log2N, netOutcomeTokensSold, funding, Fixed192x64Math.EstimationMode.UpperBound);

        // Calculate net cost as cost level difference and use the ceil
        netCost = costLevelAfter - costLevelBefore;
        // Integer division for negative numbers already uses ceiling,
        // so only check boundary condition for positive numbers
        if (netCost <= 0 || (netCost / int256(ONE)) * int256(ONE) == netCost) {
            netCost /= int256(ONE);
        } else {
            netCost = netCost / int256(ONE) + 1;
        }
    }

    /// @dev Returns cost to buy given number of outcome tokens
    /// @param market Market contract
    /// @param outcomeTokenIndex Index of outcome to buy
    /// @param outcomeTokenCount Number of outcome tokens to buy
    /// @return cost
    function calcCost(Market market, uint8 outcomeTokenIndex, uint256 outcomeTokenCount)
        public
        view
        returns (uint256 cost)
    {
        require(market.eventContract().getOutcomeCount() > 1);
        int256[] memory netOutcomeTokensSold = getNetOutcomeTokensSold(market);
        // Calculate cost level based on net outcome token balances

        int256 log2N =
            Fixed192x64Math.binaryLog(netOutcomeTokensSold.length * ONE, Fixed192x64Math.EstimationMode.UpperBound);
        uint256 funding = market.funding();

        int256 costLevelBefore =
            calcCostLevel(log2N, netOutcomeTokensSold, funding, Fixed192x64Math.EstimationMode.LowerBound);
        // Add outcome token count to net outcome token balance
        require(int256(outcomeTokenCount) >= 0);
        netOutcomeTokensSold[outcomeTokenIndex] = netOutcomeTokensSold[outcomeTokenIndex] + (int256(outcomeTokenCount));
        // Calculate cost level after balance was updated

        int256 costLevelAfter =
            calcCostLevel(log2N, netOutcomeTokensSold, funding, Fixed192x64Math.EstimationMode.UpperBound);
        // Calculate cost as cost level difference
        if (costLevelAfter < costLevelBefore) costLevelAfter = costLevelBefore;
        cost = uint256(costLevelAfter - costLevelBefore);
        // Take the ceiling to account for rounding
        if ((cost / ONE) * ONE == cost) {
            cost /= ONE;
        }
        // Integer division by ONE ensures there is room to (+ 1)
        else {
            cost = cost / ONE + 1;
        }
        // Make sure cost is not bigger than 1 per share
        if (cost > outcomeTokenCount) cost = outcomeTokenCount;
    }

    /// @dev Returns profit for selling given number of outcome tokens
    /// @param market Market contract
    /// @param outcomeTokenIndex Index of outcome to sell
    /// @param outcomeTokenCount Number of outcome tokens to sell
    /// @return profit
    function calcProfit(Market market, uint8 outcomeTokenIndex, uint256 outcomeTokenCount)
        public
        view
        returns (uint256 profit)
    {
        require(market.eventContract().getOutcomeCount() > 1);
        int256[] memory netOutcomeTokensSold = getNetOutcomeTokensSold(market);
        // Calculate cost level based on net outcome token balances

        int256 log2N =
            Fixed192x64Math.binaryLog(netOutcomeTokensSold.length * ONE, Fixed192x64Math.EstimationMode.UpperBound);
        uint256 funding = market.funding();

        int256 costLevelBefore =
            calcCostLevel(log2N, netOutcomeTokensSold, funding, Fixed192x64Math.EstimationMode.LowerBound);
        // Subtract outcome token count from the net outcome token balance
        require(int256(outcomeTokenCount) >= 0);
        netOutcomeTokensSold[outcomeTokenIndex] = netOutcomeTokensSold[outcomeTokenIndex] - (int256(outcomeTokenCount));
        // Calculate cost level after balance was updated

        int256 costLevelAfter =
            calcCostLevel(log2N, netOutcomeTokensSold, funding, Fixed192x64Math.EstimationMode.UpperBound);
        // Calculate profit as cost level difference
        if (costLevelBefore <= costLevelAfter) costLevelBefore = costLevelAfter;
        // Take the floor
        profit = uint256(costLevelBefore - costLevelAfter) / ONE;
    }

    /// @dev Returns marginal price of an outcome
    /// @param market Market contract
    /// @param outcomeTokenIndex Index of outcome to determine marginal price of
    /// @return price Marginal price of an outcome as a fixed point number
    function calcMarginalPrice(Market market, uint8 outcomeTokenIndex) public view returns (uint256 price) {
        require(market.eventContract().getOutcomeCount() > 1);
        int256[] memory netOutcomeTokensSold = getNetOutcomeTokensSold(market);
        int256 logN =
            Fixed192x64Math.binaryLog(netOutcomeTokensSold.length * ONE, Fixed192x64Math.EstimationMode.Midpoint);
        uint256 funding = market.funding();
        // The price function is exp(quantities[i]/b) / sum(exp(q/b) for q in quantities)
        // To avoid overflow, calculate with
        // exp(quantities[i]/b - offset) / sum(exp(q/b - offset) for q in quantities)
        (uint256 sum,, uint256 outcomeExpTerm) = sumExpOffset(
            logN, netOutcomeTokensSold, funding, outcomeTokenIndex, Fixed192x64Math.EstimationMode.Midpoint
        );
        return outcomeExpTerm / (sum / ONE);
    }

    /*
     *  Private functions
     */
    /// @dev Calculates the result of the LMSR cost function which is used to
    ///      derive prices from the market state
    /// @param logN Logarithm of the number of outcomes
    /// @param netOutcomeTokensSold Net outcome tokens sold by market
    /// @param funding Initial funding for market
    /// @return costLevel
    function calcCostLevel(
        int256 logN,
        int256[] memory netOutcomeTokensSold,
        uint256 funding,
        Fixed192x64Math.EstimationMode estimationMode
    ) private pure returns (int256 costLevel) {
        // The cost function is C = b * log(sum(exp(q/b) for q in quantities)).
        // To avoid overflow, we need to calc with an exponent offset:
        // C = b * (offset + log(sum(exp(q/b - offset) for q in quantities)))
        (uint256 sum, int256 offset,) = sumExpOffset(logN, netOutcomeTokensSold, funding, 0, estimationMode);
        costLevel = Fixed192x64Math.binaryLog(sum, estimationMode);
        costLevel = costLevel + (offset);
        costLevel = ((costLevel * (int256(ONE))) / logN) * (int256(funding));
    }

    /// @dev Calculates sum(exp(q/b - offset) for q in quantities), where offset is set
    ///      so that the sum fits in 248-256 bits
    /// @param logN Logarithm of the number of outcomes
    /// @param netOutcomeTokensSold Net outcome tokens sold by market
    /// @param funding Initial funding for market
    /// @param outcomeIndex Index of exponential term to extract (for use by marginal price function)
    /// @return sum offset outcomeExpTerm A result structure composed of the sum, the offset used, and the summand associated with the supplied index
    function sumExpOffset(
        int256 logN,
        int256[] memory netOutcomeTokensSold,
        uint256 funding,
        uint8 outcomeIndex,
        Fixed192x64Math.EstimationMode estimationMode
    ) private pure returns (uint256 sum, int256 offset, uint256 outcomeExpTerm) {
        // Naive calculation of this causes an overflow
        // since anything above a bit over 133*ONE supplied to exp will explode
        // as exp(133) just about fits into 192 bits of whole number data.

        // The choice of this offset is subject to another limit:
        // computing the inner sum successfully.
        // Since the index is 8 bits, there has to be 8 bits of headroom for
        // each summand, meaning q/b - offset <= exponential_limit,
        // where that limit can be found with `mp.floor(mp.log((2**248 - 1) / ONE) * ONE)`
        // That is what EXP_LIMIT is set to: it is about 127.5

        // finally, if the distribution looks like [BIG, tiny, tiny...], using a
        // BIG offset will cause the tiny quantities to go really negative
        // causing the associated exponentials to vanish.

        require(logN >= 0 && int256(funding) >= 0);
        offset = Fixed192x64Math.max(netOutcomeTokensSold);
        offset = (offset * (logN)) / int256(funding);
        offset = offset - (EXP_LIMIT);
        uint256 term;
        for (uint8 i = 0; i < netOutcomeTokensSold.length; i++) {
            term =
                Fixed192x64Math.pow2(((netOutcomeTokensSold[i] * (logN)) / int256(funding)) - (offset), estimationMode);
            if (i == outcomeIndex) outcomeExpTerm = term;
            sum = sum + (term);
        }
    }

    /// @dev Gets net outcome tokens sold by market. Since all sets of outcome tokens are backed by
    ///      corresponding collateral tokens, the net quantity of a token sold by the market is the
    ///      number of collateral tokens (which is the same as the number of outcome tokens the
    ///      market created) subtracted by the quantity of that token held by the market.
    /// @param market Market contract
    /// @return quantities Net outcome tokens sold by market
    function getNetOutcomeTokensSold(Market market) private view returns (int256[] memory quantities) {
        quantities = new int256[](market.eventContract().getOutcomeCount());
        for (uint8 i = 0; i < quantities.length; i++) {
            quantities[i] = market.netOutcomeTokensSold(i);
        }
    }
}
