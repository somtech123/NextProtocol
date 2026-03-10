// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import './errors.sol';

contract NexToken is ERC20, AccessControl, ERC20Pausable{
    uint256 private immutable i_max_supply;

    uint256 private constant BURN_RATE = 200;
    uint256 private constant BURN_DENOMINATOR = 1000;

    bytes32 internal  constant DISTRIBUTOR_ROLE = keccak256('DISTRIBUTOR ROLE');
    bytes32 internal constant BURNER_ROLE = keccak256('BURNER_ROLE');
    bytes32 internal constant PAUSER_ROLE = keccak256('PAUSER_ROLE');

    bool internal vestingAllocated;

    constructor() ERC20('NexToken', 'NXT') {
        i_max_supply = 21_000_000 * 1e18;
        _mint(address(this), i_max_supply);

        address sender = msg.sender;

        _grantRole(DEFAULT_ADMIN_ROLE, sender);
        _grantRole(DISTRIBUTOR_ROLE, sender);
        _grantRole(PAUSER_ROLE, sender);
        _grantRole(BURNER_ROLE, sender);
    }

    function _update(address from, address to, uint256 value) internal  override (ERC20, ERC20Pausable){
      

        if(paused() && to == address(0) && from == address(this) && hasRole(BURNER_ROLE, msg.sender)){
            ERC20._update(from, to, value);
            return;
        }

        if(to == address(0) || from == address(this)){
            super._update(from, to, value);
        }

        uint256  burnt_value;
        uint256 value_sent;

        unchecked{
            burnt_value = (value * BURN_RATE) / BURN_DENOMINATOR;
            value_sent = value -burnt_value;
        }

        super._update(from, address(0), burnt_value);
        super._update(from, to, value_sent);
    }

    function pause() public onlyRole(PAUSER_ROLE){
        _pause();
    }

    function unPause() public onlyRole(PAUSER_ROLE){
        _unpause();
    }

    function distribute(address to, uint256 value) public onlyRole(DISTRIBUTOR_ROLE){
        if(to == address(0)) revert ZeroAddressError();

        uint256 valueInWei = value * 1e18;

        if(valueInWei > balanceOf(address(this))) revert NotEnoughContractToken();

        _transfer(address(this), to, valueInWei);
    }

    function getVestingAmount() public view returns(uint256){
        return (totalSupply() * 20 )/ 100;
    }

    function allocateVesting(address to) public onlyRole(DISTRIBUTOR_ROLE) {
        if(vestingAllocated) revert VestingAlreadyAllocated();
        if(to == address(0)) revert ZeroAddressError();


        uint256 vestedAmount = getVestingAmount();

        vestingAllocated = true;

        _transfer(address(this), to, vestedAmount);    
    }

    function airdrop(address[] calldata recipients, uint256 value )public  onlyRole(DISTRIBUTOR_ROLE){
        uint256 valueInWei = value * 1e18;

        uint256 len = recipients.length;

        if(balanceOf(address(this)) < valueInWei * len) revert NotEnoughContractToken();

        for(uint256 i=0; i < len;){
            address recipient = recipients[i];


            if(recipient != address(0)){
                _transfer(address(this), recipient, valueInWei);
            }

            unchecked { ++i; }
            
        }

    }

    function emergencyBurn(uint256 value) public onlyRole(BURNER_ROLE) whenPaused{
        if(value == 0) revert ZeroAmountError();

        uint256 valueInWei = value * 1e18;
        if(balanceOf(address(this)) < valueInWei) revert NotEnoughContractToken();
        _burn(address(this), valueInWei);

    }

     function maxSupply() public view returns (uint256) {
        return i_max_supply;
    }

     function isVestingAllocated() public view returns (bool) {
        return vestingAllocated;
    }

    function contractBalance() public view returns (uint256) {
        return balanceOf(address(this));
    }

    
}