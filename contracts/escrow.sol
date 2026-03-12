// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import './errors.sol';
import './helper.sol';


contract Escrow is Ownable{

    IERC20 public immutable i_token;
    uint256 public jobId;

    struct Job {
        uint256 id;
        address clients;
        address freelancer;
        MileStone [] milestones;
        uint256 totalAmount;
        Status status;
        
    }

    struct MileStone{
        uint256 amount;
        // bool completed;
        bool paid;
        MileStoneStatus mileStoneStatus;
    }

    enum Status {Open, Accepted, Cancelled, Completed}

    enum MileStoneStatus {Open, InReview, Accepted}


    mapping (uint256 => Job) public jobs;

    mapping (address => uint256[]) public freelancerJobs;

     constructor(address _token) Ownable(tx.origin){
        i_token = IERC20(_token);
    }

    function getjob(uint256 _jobid) public view returns (MileStone [] memory){
        return  jobs[_jobid].milestones;
    }


    function createJob(address _freelancer, uint256[] memory _amount) external onlyOwner {

        if(_freelancer == address(0)) revert ZeroAddressError();
        if(_amount.length == 0)       revert NoMilestonesProvided();

        uint256 count = _amount.length;

        uint256 total;
        Job storage _job = jobs[jobId];

        _job.id = jobId;
        _job.clients = msg.sender;
        _job.freelancer = _freelancer;

        for(uint256 i =0; i < count;){
            uint256 amountWei = Helper.toWei(_amount[i]);

            _job.milestones.push(MileStone({
                amount: amountWei,
                // completed: false,
                paid: false,
                mileStoneStatus: MileStoneStatus.Open
            }));
            total += amountWei;

            unchecked{ i++;}
        }

        _job.totalAmount = total;
        _job.status = Status.Open;

        require(i_token.transferFrom(msg.sender, address(this), total), 'Transfer failed');

        freelancerJobs[_freelancer].push(jobId);
        jobId++;

    }


    function acceptJob(uint256 id, address _freelancer ) external {
        Job storage _job = jobs[id];

        if(_freelancer == address(0)) revert ZeroAddressError();
        if(_job.freelancer != _freelancer) revert InvalidFreelancer();
        if(_job.status != Status.Open) revert JobNotOpen();

        _job.status = Status.Accepted;
    }

    function submitMilestone(uint256 _jobId, uint256 _milestoneId, address _freelancer) external {
        Job storage _job = jobs[_jobId];

        if(_freelancer == address(0)) revert ZeroAddressError();
        if(_job.freelancer != _freelancer) revert InvalidFreelancer();
        if(_milestoneId > _job.milestones.length) revert InvalidIndex();

        MileStone storage _m = _job.milestones[_milestoneId];

        if(_m.mileStoneStatus != MileStoneStatus.Open) revert InvalidMileStoneStatus();

        _m.mileStoneStatus = MileStoneStatus.InReview;

    }

    function approveJob(uint256 _jobId,uint256 _milestoneId) external onlyOwner{
        Job storage _job = jobs[_jobId];
        if(_milestoneId > _job.milestones.length) revert InvalidIndex();

        MileStone storage _m = _job.milestones[_milestoneId];
        if(_m.mileStoneStatus != MileStoneStatus.InReview) revert InvalidMileStoneStatus();

        _m.mileStoneStatus = MileStoneStatus.Accepted;

        i_token.transfer(_job.freelancer, _m.amount);

        _m.paid = true;
    }

}