// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import './errors.sol';

/// @title NexToken — ERC20 Payment & Incentive Token
/// @author Oscar Onyenacho
/// @notice NexToken (NXT) is a deflationary ERC20 token with a 20% burn rate
///         on every transfer. It supports role-based access control for
///         distribution, pausing, and emergency burns.
/// @dev    Inherits ERC20, AccessControl, and ERC20Pausable from OpenZeppelin.
///         All tokens are minted to the contract on deployment.
///         Uses three custom roles: DISTRIBUTOR_ROLE, PAUSER_ROLE, BURNER_ROLE.


contract NexToken is ERC20, AccessControl, ERC20Pausable{
    // ==================================================================
    //                  STATE VARIABLES  
    // ===================================================================

    /// @notice The maximum token supply - fixed at 21,000,000 NXT
    /// @dev    Set once in constructor and stored as immutable in bytecode
    uint256 private immutable i_max_supply;
    
    /// @dev for burn rate calculation (200/1000 = 20%)
    uint256 private constant BURN_RATE = 200;

    /// @dev Denominator for burn rate calculation  
    uint256 private constant BURN_DENOMINATOR = 1000;
    
    /// @notice Role identifier for account allowed to distribute token
    /// @dev    Computed at compile time via keccak256 and stored in bytecode

    bytes32 internal  constant DISTRIBUTOR_ROLE = keccak256('DISTRIBUTOR ROLE');

    /// @notice Role identifier for account allowed to burn token
    /// @dev    Can only burn when contract is paused via emergencyBurn()
    bytes32 internal constant BURNER_ROLE = keccak256('BURNER_ROLE');

    /// @notice Role identifier for account allowed to pause the contract 
    bytes32 internal constant PAUSER_ROLE = keccak256('PAUSER_ROLE');
    
    /// @notice Tracks whether the vesting allocation has been distributed
    /// @dev    Once set to true cannot be reset — vesting can only happen once
    bool internal vestingAllocated;


    // ==================================================================
    //                  CONSTRUCTOR 
    // ===================================================================

    /// @notice Deploys NexToken and mints full supply to the contract itself
    /// @dev    Grants all roles to deployer (msg.sender).
    ///         Tokens are held by contract and distributed via distribute()
    ///         All roles can be transferred or revoked by DEFAULT_ADMIN_ROLE

    constructor() ERC20('NexToken', 'NXT') {
        i_max_supply = 21_000_000 * 1e18;
        _mint(address(this), i_max_supply);

        address sender = msg.sender;

        _grantRole(DEFAULT_ADMIN_ROLE, sender);
        _grantRole(DISTRIBUTOR_ROLE, sender);
        _grantRole(PAUSER_ROLE, sender);
        _grantRole(BURNER_ROLE, sender);
    }

    // ==================================================================
    //                  INTERNAL FUNCTIONS 
    // ===================================================================

    /// @notice Core token movement hook — applies burn on every transfer
    /// @dev    Called internally by transfer(), transferFrom(), mint(), burn()
    ///         Four execution paths:
    ///         1. Emergency burn while paused → bypasses ERC20Pausable
    ///         2. Mint (from == address(0)) → no burn fee
    ///         3. Burn (to == address(0)) → no burn fee
    ///         4. Contract distributing → no burn fee
    ///         5. Regular transfer → 20% burn applied
    ///         unchecked math is safe: BURN_RATE < BURN_DENOMINATOR
    ///         so burnt_value always < value — no underflow possible
    /// @param from   Address sending tokens (address(0) for mint)
    /// @param to     Address receiving tokens (address(0) for burn)
    /// @param value  Amount of tokens in wei
    function _update(address from, address to, uint256 value) internal  override (ERC20, ERC20Pausable){

        // PATH 1 — emergency burn bypass
        if(paused() && to == address(0) && from == address(this) && hasRole(BURNER_ROLE, msg.sender)){
            ERC20._update(from, to, value);
            return;
        }

        // PATH 2 & 3 — mint or burn path, no fee
        if(to == address(0) || from == address(this)){
            super._update(from, to, value);
        }

        // PATH 4 — regular transfer, apply 20% burn
        uint256  burnt_value;
        uint256 value_sent;

        unchecked{
            burnt_value = (value * BURN_RATE) / BURN_DENOMINATOR;
            value_sent = value -burnt_value;
        }

        super._update(from, address(0), burnt_value); //  burn
        super._update(from, to, value_sent); //  send
    }

    // ==================================================================
    //                  PAUSE FUNCTIONS 
    // ===================================================================

    /// @notice Pauses all token transfers
    /// @dev    Only callable by accounts with PAUSER_ROLE
    ///         While paused only emergencyBurn() is executable
    function pause() public onlyRole(PAUSER_ROLE){
        _pause();
    }


    /// @notice Unpauses token transfers — resumes normal operation
    /// @dev    Only callable by accounts with PAUSER_ROLE
    function unPause() public onlyRole(PAUSER_ROLE){
        _unpause();
    }

    // ==================================================================
    //                  DISTRIBUTE FUNCTIONS 
    // ===================================================================

    /// @notice Transfers tokens from contract balance to a recipient
    /// @dev    Only callable by DISTRIBUTOR_ROLE
    ///         Value is passed as whole tokens and converted to wei internally
    ///         Uses _transfer() not transferFrom() as contract owns the tokens
    /// @param to     Recipient address — cannot be zero address
    /// @param value  Amount in whole tokens (e.g. 100 = 100 NXT)
    function distribute(address to, uint256 value) public onlyRole(DISTRIBUTOR_ROLE){
        if(to == address(0)) revert ZeroAddressError();

        uint256 valueInWei = value * 1e18;

        if(valueInWei > balanceOf(address(this))) revert NotEnoughContractToken();

        _transfer(address(this), to, valueInWei);
    }

    /// @notice Calculates the vesting allocation — 20% of total supply
    /// @dev    Private — only used internally by allocateVesting()
    ///         Based on totalSupply() at time of call
    /// @return Amount of tokens reserved for vesting in wei
    function getVestingAmount() private view returns(uint256){
        return (totalSupply() * 20 )/ 100;
    }

    /// @notice Allocates 20% of total supply to the vesting contract
    /// @dev    Can only be called ONCE — vestingAllocated flag prevents repeat
    ///         Flag is set BEFORE transfer to prevent reentrancy
    ///         Only callable by DISTRIBUTOR_ROLE
    /// @param to  Address of the vesting contract — cannot be zero address
    function allocateVesting(address to) public onlyRole(DISTRIBUTOR_ROLE) {
        if(vestingAllocated) revert VestingAlreadyAllocated();
        if(to == address(0)) revert ZeroAddressError();

        uint256 vestedAmount = getVestingAmount();

        // set flag BEFORE transfer — reentrancy protection
        vestingAllocated = true;

        _transfer(address(this), to, vestedAmount);    
    }

    /// @notice Sends equal token amounts to multiple recipients in one call
    /// @dev    Only callable by DISTRIBUTOR_ROLE
    ///         Skips zero addresses silently rather than reverting
    ///         Checks total balance before loop to fail fast
    ///         Uses unchecked ++i for gas efficiency
    /// @param recipients  Array of recipient addresses (calldata for gas savings)
    /// @param value       Amount per recipient in whole tokens (e.g. 10 = 10 NXT)

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

    /// @notice Burns tokens from contract balance during emergency
    /// @dev    Only callable by BURNER_ROLE and only when contract is paused
    ///         Contract must be paused first via pause()
    ///         Burns from contract balance only — not from user wallets
    ///         Value converted from whole tokens to wei internally
    /// @param value  Amount to burn in whole tokens (e.g. 100 = 100 NXT)
    function emergencyBurn(uint256 value) public onlyRole(BURNER_ROLE) whenPaused{
        if(value == 0) revert ZeroAmountError();

        uint256 valueInWei = value * 1e18;
        if(balanceOf(address(this)) < valueInWei) revert NotEnoughContractToken();
        _burn(address(this), valueInWei);

    }

    // ==================================================================
    //                  VIEW FUNCTIONS 
    // ===================================================================


    /// @notice Returns the maximum token supply
    /// @dev    Reads from immutable — costs ~3 gas (bytecode not storage)
    /// @return Maximum supply in wei (21,000,000 * 1e18)
     function maxSupply() public view returns (uint256) {
        return i_max_supply;
    }

    
    /// @notice Returns whether vesting tokens have been allocated
    /// @dev    Once true — can never be reset to false
    /// @return true if vesting has been allocated, false otherwise
     function isVestingAllocated() public view returns (bool) {
        return vestingAllocated;
    }

     /// @notice Returns the current token balance held by this contract
    /// @dev    Decreases as tokens are distributed, airdropped or burned
    /// @return Contract token balance in wei
    function contractBalance() public view returns (uint256) {
        return balanceOf(address(this));
    }

    
}