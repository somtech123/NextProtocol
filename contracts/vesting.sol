// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import './errors.sol';

contract VestingToken{
    IERC20 public immutable i_token;
    address public immutable i_owner;

    uint256 public immutable i_startTime;  // Vesting start
    uint256 public immutable i_duration;   // Total vesting duration in seconds
    uint256 public immutable i_cliff;      // cliff duration in second
    
    uint256 public percentShareAssign;      // Total promised token 

    struct Beneficiary {
        uint256 percentShare;   // % of vesting pool
        uint256 allocation;
        Role role;     // role Investor or Team
        uint256 claimed; // Token already claimed
        bool exists;     // check if beneficiary exists
    }

    enum Role {None, Team, Investors, Advisors}

    mapping (address => Beneficiary) public beneficiaries;
    address[] public allBeneficiaries;

    modifier onlyOwner(){
        require(msg.sender == i_owner, 'Not Owner');   
        _;
    }

    constructor(address _nxtAddress, uint256 _duration, uint256 _cliff, uint8 _unit){
        
        if(_duration == 0) revert DurationMustBeGreaterThanZero();

        if( _unit < 1 || _unit > 4)  revert InvalidTimeUnit();
        
        if(_cliff > _duration) revert CliffMustExceedDuration();
   
        i_token = IERC20(_nxtAddress);
        i_owner = msg.sender;
        i_startTime = block.timestamp;

        uint256  mutiplier = 
            _unit == 1 ? 1 :         //seconds
            _unit == 2 ? 60 :        //minutes
            _unit == 3 ? 3600 :      // hours
            86400;                   // days (_unit == 4)

            
        i_duration = _duration * mutiplier;
        i_cliff = _cliff * mutiplier;
        
    }


    // add Beneficiary to the vesting pool 

    function addBeneficiary(address _addr, uint256 _percentShare, Role _role) public onlyOwner{
        if(_percentShare == 0) revert ShareMustExceedZero();

        if(_role == Role.None) revert InvalidRole();
 
        if(_addr == address(0))         revert ZeroAddressError();
        
        if(beneficiaries[_addr].exists) revert BeneficiaryAlreadyExist();

        uint256 newTotalShare = percentShareAssign + _percentShare;
        if(newTotalShare > 100 ) revert TotalShareExceeded();

        uint256 contractBalance = IERC20(i_token).balanceOf(address(this));
        uint256 _allocation = (contractBalance * _percentShare) / 100;

        beneficiaries[_addr] = Beneficiary({
            percentShare: _percentShare,
            allocation: _allocation,
            role: _role,
            claimed: 0,
            exists: true  
        });

        percentShareAssign = newTotalShare;

        allBeneficiaries.push(_addr);
    }

    function getBeneficiary(address _addr) public view returns ( uint256, Role, uint256){
        Beneficiary storage beneficiary = beneficiaries[_addr];
        return (beneficiary.allocation, beneficiary.role, beneficiary.claimed);

    }

    function getBeneficiaryTotalAllocation(address _addr) public view returns (uint256){
        if(!beneficiaries[_addr].exists) revert BeneficiaryNotFound();

        uint256 percentShare   = beneficiaries[_addr].percentShare;
        uint256 contractBalance = IERC20(i_token).balanceOf(address(this));

        return (contractBalance * percentShare) / 100;
        
    }

    function getTotalVestedPercent() public view returns(uint256){
        return percentShareAssign;
    }

    /* Get the amount that is available to be claimed by that user 
       check if vesting has started and return o
       if vesting is still ongoing return amount based on the time elapsed
       totalAllocation * elapsedTime / duration
       if vesting has ended return full token

    */
    function getVestedAmount(address _addr) internal  view returns (uint256){

        uint256 cliffEnd = i_startTime + i_cliff;

        //  before cliff — nothing vested
        if(block.timestamp < cliffEnd){
            return 0;
        }

        //  vesting period = duration - cliff
        // time available for vesting after cliff passes

        uint256 vestingPeriod = i_duration - i_cliff;

        uint256 elapsed = block.timestamp - cliffEnd;
        uint256 total = beneficiaries[_addr].allocation;

        //  fully vested — return total

        if(elapsed >= vestingPeriod){
            return total;
        }

        // partially vested — proportional amount
       // multiply before divide — preserve precision

        return (total * elapsed) / vestingPeriod;

    }

    function claim() public  {
        Beneficiary storage beneficiary = beneficiaries[msg.sender];

        if(!beneficiary.exists) revert BeneficiaryNotFound();
        if(beneficiary.allocation == 0) revert BeneficiaryNotFound();
      
        uint256 vested = getVestedAmount(msg.sender);
        uint256 alreadyClaimed = beneficiary.claimed;

        // nothing new to claim

        if(vested <= alreadyClaimed) revert NoTokensToClaim();

        //prevent over spending my claiming more token
        //only claim newly vested tokens

        uint256 claimable = vested - alreadyClaimed;
        beneficiary.claimed += claimable;
        
        i_token.transfer(msg.sender, claimable);
    }

}