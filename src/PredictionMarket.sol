// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract OutcomeToken is ERC20, Ownable {
    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) Ownable(msg.sender) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

contract PredictionMarket is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public usdcToken;
    OutcomeToken[] public outcomeTokens;
    // Index of OutcomeToken corresponding to event winner
    uint256 public winningOutcome;
    bool public winnerSet = false;

    constructor(
        IERC20 _usdcToken,
        uint256 _numberOfOutcomes
    ) Ownable(msg.sender) {
        require(
            _numberOfOutcomes > 1,
            "Number of outcomes should be greater than 1"
        );
        usdcToken = _usdcToken;

        for (uint256 i = 0; i < _numberOfOutcomes; i++) {
            string memory strI = Strings.toString(i);
            OutcomeToken newToken = new OutcomeToken(
                string.concat("Outcome Token", strI),
                string.concat("OT", strI)
            );
            outcomeTokens.push(newToken);
        }
    }

    function mint(uint256 amount) external {
        usdcToken.safeTransferFrom(msg.sender, address(this), amount);

        for (uint256 i = 0; i < outcomeTokens.length; i++) {
            outcomeTokens[i].mint(msg.sender, amount);
        }
    }

    function setWinner(uint256 _winningOutcome) external onlyOwner {
        require(
            _winningOutcome < outcomeTokens.length,
            "Invalid outcome index"
        );
        require(!winnerSet, "Winner already set");
        winningOutcome = _winningOutcome;
        winnerSet = true;
    }

    function claim(uint256 amount) external {
        require(winnerSet, "Winner not set yet");
        OutcomeToken winningToken = outcomeTokens[winningOutcome];
        winningToken.transferFrom(msg.sender, address(this), amount);
        usdcToken.safeTransfer(msg.sender, amount);
    }
}
