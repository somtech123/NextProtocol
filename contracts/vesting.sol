// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import './errors.sol';

contract VestingToken{
    IERC20 public immutable token;
    address public immutable owner;

    uint256 public immutable startTime;  // Vesting start
    uint256 public immutable duration;   // Total vesting duration in seconds
    uint256 public immutable cliff;      // cliff duration in second
    
    uint256 public totalAllocation;      // Total promised token

    mapping(address => uint256) public allocation;
    mapping(address => uint256) public claimed;

    modifier onlyOwner(){
        require(msg.sender == owner, 'Not Owner');
        
        _;
    }

    constructor(address _nxtAddress, uint256 _duration, uint256 _cliff, uint8 _unit){
        require(_unit >= 1 && _unit <= 4, "Invalid time unit");
        require(_duration > 0, "Duration must be greater than 0");
        require(_cliff <= _duration, "Cliff cannot exceed duration");


        token = IERC20(_nxtAddress);
        owner = msg.sender;
        startTime = block.timestamp;

        uint256  mutiplier = 
            _unit == 1 ? 1 :         //seconds
            _unit == 2 ? 60 :        //minutes
            _unit == 3 ? 3600 :      // hours
            86400;                   // days (_unit == 4)

            
        duration = _duration * mutiplier;
        cliff = _cliff * mutiplier;
        
    }

    function addBeneficiary(address recipient, uint256 amount) public onlyOwner{
        uint256 amountInWei = amount * 1e18;
        if(totalAllocation + amountInWei > IERC20(token).balanceOf(address(this))) revert NotEnoughContractToken();
        allocation[recipient] = amountInWei; // ← store in wei ✅
        totalAllocation      += amountInWei;
    }

    function vestedAmount(address beneficiary) internal view returns (uint256){
        /* Check if vesting has started
           if currentTime is before startTime return 0
           
        */
        if(block.timestamp < startTime + cliff){
            return 0;
        }
        uint256 total = allocation[beneficiary];
        uint256 elapsed = block.timestamp - startTime;

        /* Check if vesting has finished
           all token allocation are vested
           
        */
        if(elapsed >= duration){
            return total;
        }

        /* Check if vesting is still ongoing
           it calculate the portion based on the time
        */

        return (total * elapsed) / duration;
    }


    function claim() public {

        uint256 vested = vestedAmount(msg.sender);

        // prevent someone from claiming more
        uint256  claimable = vested - claimed[msg.sender];

        require(claimable > 0, "Nothing to claim");

        //ensure the contract has enough token to claim
        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        if(claimable > contractBalance){
            claimable = contractBalance;
        }

        claimed[msg.sender] += claimable;

        token.transfer(msg.sender, claimable);

    }

    function diagnose(address user) public view returns (
    uint256 currentTime,
    uint256 cliffEndsAt,
    uint256 cliffRemaining,
    uint256 userAllocation,
    uint256 vestedNow,
    uint256 alreadyClaimed,
    uint256 claimableNow, uint256 balance
) {
    currentTime    = block.timestamp;
    balance = IERC20(token).balanceOf(address(this));
    cliffEndsAt    = startTime + cliff;
    cliffRemaining = block.timestamp < startTime + cliff 
                     ? (startTime + cliff) - block.timestamp 
                     : 0;
    userAllocation = allocation[user];
    vestedNow      = vestedAmount(user);
    alreadyClaimed = claimed[user];
    claimableNow   = vestedNow > alreadyClaimed 
                     ? vestedNow - alreadyClaimed 
                     : 0;
}

}

//0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db