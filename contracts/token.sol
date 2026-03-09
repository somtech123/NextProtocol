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

    constructor() ERC20('NexToken', 'NXT') {
        i_max_supply = 21_000_000 * 1e18;
        _mint(address(this), i_max_supply);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    function _update(address from, address to, uint256 value) internal  override (ERC20, ERC20Pausable){
        uint256 valueInWei = value * 1e18;

        if(paused() && to == address(0) && from == address(this) && hasRole(BURNER_ROLE, msg.sender)){
            ERC20._update(from, to, valueInWei);
            return;
        }

        if(to == address(0) || from == address(this)){
            super._update(from, to, valueInWei);
        }

        uint256  burnt_value = (valueInWei * BURN_RATE) / BURN_DENOMINATOR;
        uint256 value_sent = valueInWei -burnt_value;
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
        if(value * 1e18 > balanceOf(address(this))) revert NotEnoughContractToken();

        _transfer(address(this), to, value * 1e18);
    }

    function transferToVesting(address to, uint256 value) public onlyRole(DISTRIBUTOR_ROLE) {
        _transfer(address(this), to, value * 1e18);
    }

    function airdrop(address[] calldata recipents, uint256 value )public  onlyRole(DISTRIBUTOR_ROLE){
        uint256 valueInWei = value * 1e18;
        require(balanceOf(address(this)) >= valueInWei * recipents.length, "Not Enough Token in Contract");

        for(uint256 i=0; i< recipents.length; i++){
            _transfer(address(this), recipents[i], valueInWei);
        }

    }

    function emergencyBurn(uint256 value) public onlyRole(BURNER_ROLE) whenPaused{
        if(value * 1e18 == 0) revert ZeroAmountError();
        if(balanceOf(address(this)) < value) revert ZeroAmountError();
        _burn(address(this), value * 1e18);

    }
}