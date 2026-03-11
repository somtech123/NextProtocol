// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import './errors.sol';
import './helper.sol';


contract Escrow{

    IERC20 public immutable i_token;
    uint256 public jobId;

    struct Job {
        uint256 id;
        address clients;
        address freelancer;
        MileStone [] milestones;
        uint256 totalAmount;
        
    }

    struct MileStone{
        uint256 amount;
        bool completed;
        bool paid;
    }


    mapping (uint256 => Job) public jobs;

    mapping (address => uint256[]) public freelancerJobs;

     constructor(address _token){
        i_token = IERC20(_token);
    }

    function getjob(uint256 _jobid) public view returns (Job  memory){
        return  jobs[_jobid];
    }


    function createJob(address _freelancer, uint256[] memory _amount) external {
        if(_freelancer == address(0)) revert ZeroAddressError();
        if(_amount.length == 0)       revert NoMilestonesProvided();
        
        uint256 count = _amount.length;
        uint256 total;
        Job storage job = jobs[jobId];

        job.id = jobId;
        job.clients = msg.sender;
        job.freelancer = _freelancer;

        for(uint256 i =0; i < count;){
            uint256 amountWei = Helper.toWei(_amount[i]);

            job.milestones.push(MileStone({
                amount: amountWei,
                completed: false,
                paid: false
            }));
            total += amountWei;

            unchecked{ i++;}
        }

        job.totalAmount = total;

        require(i_token.transferFrom(msg.sender, address(this), total), 'Transfer failed');

        freelancerJobs[_freelancer].push(jobId);
        jobId++;

    }


}