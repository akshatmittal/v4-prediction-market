pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title Outcome token contract - Issuing and revoking outcome tokens
contract OutcomeToken is ERC20 {
    /*
     *  Events
     */
    event Issuance(address indexed owner, uint256 amount);
    event Revocation(address indexed owner, uint256 amount);

    /*
     *  Storage
     */
    address public eventContract;

    /*
     *  Modifiers
     */
    modifier isEventContract() {
        // Only event contract is allowed to proceed
        require(msg.sender == eventContract);
        _;
    }

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        eventContract = msg.sender;
    }

    /*
     *  Public functions
     */
    /// @dev Events contract issues new tokens for address. Returns success
    /// @param _for Address of receiver
    /// @param outcomeTokenCount Number of tokens to issue
    function issue(address _for, uint256 outcomeTokenCount) public isEventContract {
        _mint(_for, outcomeTokenCount);
        emit Issuance(_for, outcomeTokenCount);
    }

    /// @dev Events contract revokes tokens for address. Returns success
    /// @param _for Address of token holder
    /// @param outcomeTokenCount Number of tokens to revoke
    function revoke(address _for, uint256 outcomeTokenCount) public isEventContract {
        _burn(_for, outcomeTokenCount);
        emit Revocation(_for, outcomeTokenCount);
    }
}
