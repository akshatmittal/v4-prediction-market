pragma solidity ^0.8.20;

import "./OutcomeToken.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "forge-std/console.sol";

contract EventData {
    /*
     *  Events
     */
    event OutcomeTokenCreation(OutcomeToken outcomeToken, uint8 index);
    event OutcomeTokenSetIssuance(address indexed buyer, uint256 collateralTokenCount);
    event OutcomeTokenSetRevocation(address indexed seller, uint256 outcomeTokenCount);
    event OutcomeAssignment(int256 outcome);
    event WinningsRedemption(address indexed receiver, uint256 winnings);

    /*
     *  Storage
     */
    ERC20 public collateralToken;
    // Oracle public oracle;
    bool public isOutcomeSet;
    int256 public outcome;
    OutcomeToken[] public outcomeTokens;
}

/// @title Event contract - Provide basic functionality required by different event types
abstract contract Event is EventData {
    /*
     *  Public functions
     */
    /// @dev Buys equal number of tokens of all outcomes, exchanging collateral tokens and sets of outcome tokens 1:1
    /// @param collateralTokenCount Number of collateral tokens
    function buyAllOutcomes(uint256 collateralTokenCount) public {
        // Transfer collateral tokens to events contract
        require(collateralToken.transferFrom(msg.sender, address(this), collateralTokenCount));
        // Issue new outcome tokens to sender
        for (uint8 i = 0; i < outcomeTokens.length; i++) {
            outcomeTokens[i].issue(msg.sender, collateralTokenCount);
        }
        emit OutcomeTokenSetIssuance(msg.sender, collateralTokenCount);
    }

    /// @dev Sells equal number of tokens of all outcomes, exchanging collateral tokens and sets of outcome tokens 1:1
    /// @param outcomeTokenCount Number of outcome tokens
    function sellAllOutcomes(uint256 outcomeTokenCount) public {
        // Revoke sender's outcome tokens of all outcomes
        for (uint8 i = 0; i < outcomeTokens.length; i++) {
            outcomeTokens[i].revoke(msg.sender, outcomeTokenCount);
        }
        // Transfer collateral tokens to sender
        require(collateralToken.transfer(msg.sender, outcomeTokenCount));
        emit OutcomeTokenSetRevocation(msg.sender, outcomeTokenCount);
    }

    /// @dev Sets winning event outcome
    function setOutcome() public {
        // Winning outcome is not set yet in event contract but in oracle contract
        /*
        require(!isOutcomeSet && oracle.isOutcomeSet());
        // Set winning outcome
        outcome = oracle.getOutcome();
        isOutcomeSet = true;
        emit OutcomeAssignment(outcome);
        */
    }

    /// @dev Returns outcome count
    /// @return Outcome count
    function getOutcomeCount() public view returns (uint8) {
        return uint8(outcomeTokens.length);
    }

    /// @dev Returns outcome tokens array
    /// @return Outcome tokens
    function getOutcomeTokens() public view returns (OutcomeToken[] memory) {
        return outcomeTokens;
    }

    function getOutcomeTokenDistribution(address owner)
        public
        view
        returns (uint256[] memory outcomeTokenDistribution)
    {
        outcomeTokenDistribution = new uint256[](outcomeTokens.length);
        for (uint8 i = 0; i < outcomeTokenDistribution.length; i++) {
            outcomeTokenDistribution[i] = outcomeTokens[i].balanceOf(owner);
        }
    }

    /// @dev Calculates and returns event hash
    /// @return Event hash
    function getEventHash() public view virtual returns (bytes32);

    /// @dev Exchanges sender's winning outcome tokens for collateral tokens
    /// @return Sender's winnings
    function redeemWinnings() public virtual returns (uint256);
}

/// @title Categorical event contract - Categorical events resolve to an outcome from a set of outcomes
contract CategoricalEvent is Event {
    constructor(
        // address outcomeTokenMasterCopy,
        ERC20 _collateralToken,
        // Oracle _oracle,
        uint8 outcomeCount
    ) {
        // Validate input
        require(
            address(_collateralToken) != address(0)
            // address(_oracle) != address(0) &&
            && outcomeCount >= 2
        );
        collateralToken = _collateralToken;
        // oracle = _oracle;
        // Create an outcome token for each outcome
        for (uint8 i = 0; i < outcomeCount; i++) {
            // OutcomeToken outcomeToken = OutcomeToken(
            //     address(new OutcomeTokenProxy(outcomeTokenMasterCopy))
            // );
            OutcomeToken outcomeToken = new OutcomeToken("OUTCOMETOKEN", "OT");
            outcomeTokens.push(outcomeToken);
            emit OutcomeTokenCreation(outcomeToken, i);
        }
    }

    /*
     *  Public functions
     */
    /// @dev Exchanges sender's winning outcome tokens for collateral tokens
    /// @return winnings Sender's winnings
    function redeemWinnings() public override returns (uint256 winnings) {
        // Winning outcome has to be set
        require(isOutcomeSet);
        // Calculate winnings
        winnings = outcomeTokens[uint256(outcome)].balanceOf(msg.sender);
        // Revoke tokens from winning outcome
        outcomeTokens[uint256(outcome)].revoke(msg.sender, winnings);
        // Payout winnings
        require(collateralToken.transfer(msg.sender, winnings));
        emit WinningsRedemption(msg.sender, winnings);
    }

    /// @dev Calculates and returns event hash
    /// @return Event hash
    function getEventHash() public view override returns (bytes32) {
        return
        // keccak256(
        //     abi.encodePacked(collateralToken, oracle, outcomeTokens.length)
        // );
        keccak256(abi.encodePacked(collateralToken, outcomeTokens.length));
    }
}
