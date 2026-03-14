// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import './errors.sol';
import './helper.sol';


contract Escrow is Ownable, AccessControl{

    IERC20 public immutable i_token;
    uint256 public jobId;

    bytes32 internal constant RESOLVER = keccak256('RESOLVER');

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
        bool paid;
        MileStoneStatus mileStoneStatus;
    }

    struct Disputes {
        uint256 milestoneId;
        address raisedBy;
        string reason;
        address resolver;
        bool resolved;
        string outcome;
    }

    enum Status {Open, Accepted, Cancelled, Completed}

    enum MileStoneStatus {Open, InReview, Accepted, Disputed, Settled}


    mapping (uint256 => Job) public jobs;

    mapping (address => uint256[]) public freelancerJobs;

    mapping(uint256 => mapping (uint256 => Disputes)) public disputes;

     constructor(address _token, address _resolver) Ownable(tx.origin){
        i_token = IERC20(_token);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RESOLVER, _resolver);

    }

    modifier onlyFreelancer(uint256 id){
        if(msg.sender != jobs[id].freelancer) revert NotFreelancer();
        _;
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


    function acceptJob(uint256 id, address _freelancer ) external onlyFreelancer(id) {
        Job storage _job = jobs[id];

        if(_freelancer == address(0)) revert ZeroAddressError();
        if(_job.freelancer != _freelancer) revert InvalidFreelancer();
        if(_job.status != Status.Open) revert JobNotOpen();

        _job.status = Status.Accepted;
    }

    function submitMilestone(uint256 _jobId, uint256 _milestoneId, address _freelancer) external onlyFreelancer(_jobId) {
        Job storage _job = jobs[_jobId];

        if(_freelancer == address(0)) revert ZeroAddressError();
        if(_job.freelancer != _freelancer) revert InvalidFreelancer();
        if(_milestoneId > _job.milestones.length) revert InvalidIndex();

        MileStone storage _m = _job.milestones[_milestoneId];

        if(_m.mileStoneStatus != MileStoneStatus.Open) revert InvalidMileStoneStatus();

        _m.mileStoneStatus = MileStoneStatus.InReview;

    }

    function approveMilestone(uint256 _jobId,uint256 _milestoneId) external onlyOwner{
        Job storage _job = jobs[_jobId];
        if(_milestoneId > _job.milestones.length) revert InvalidIndex();

        MileStone storage _m = _job.milestones[_milestoneId];
        if(_m.mileStoneStatus != MileStoneStatus.InReview) revert InvalidMileStoneStatus();

        _m.mileStoneStatus = MileStoneStatus.Accepted;

        i_token.transfer(_job.freelancer, _m.amount);

        _m.paid = true;
    }

    function raiseDispute(uint256 _jobId,uint256 _milestoneId, string calldata _reason) external{
        Job storage _job = jobs[_jobId];
        if(_milestoneId > _job.milestones.length) revert InvalidIndex();

        MileStone storage _m = _job.milestones[_milestoneId];

        if(msg.sender != _job.clients && msg.sender != _job.freelancer) revert NotParticipant();
        if(_m.mileStoneStatus != MileStoneStatus.InReview) revert MileStoneNotInReview();

        _m.mileStoneStatus = MileStoneStatus.Disputed;
      
        disputes[_jobId][_milestoneId] = Disputes({
            milestoneId: _milestoneId,
            raisedBy: msg.sender,
            reason: _reason,
            resolver: address(0),
            resolved: false,
            outcome: ''
        });
    }


    function resolveDispute(uint256 _jobId,uint256 _milestoneId, bool approve, string calldata _outcome) external onlyRole(RESOLVER){
        MileStone storage _m = jobs[_jobId].milestones[_milestoneId];
        Disputes storage _dispute = disputes[_jobId][_milestoneId];

        if(_m.mileStoneStatus != MileStoneStatus.Disputed) revert MileStoneNotDisputed();

        _dispute.resolved = true;
        _dispute.resolver = msg.sender;
        _dispute.outcome = _outcome;

        if(approve){
        _m.mileStoneStatus = MileStoneStatus.Accepted;

        i_token.transfer(jobs[_jobId].freelancer, _m.amount);

        }else {
            _m.mileStoneStatus = MileStoneStatus.Settled;
            i_token.transfer(jobs[_jobId].clients, _m.amount);

        }

    }

}