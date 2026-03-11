// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

error ZeroAddressError();
error NotEnoughContractToken();
error ZeroAmountError();
error VestingAlreadyAllocated();

error InvalidTimeUnit();
error CliffMustExceedDuration();
error DurationMustBeGreaterThanZero();

error ShareMustExceedZero();
error BeneficiaryAlreadyExist();
error TotalShareExceeded();
error InvalidRole();
error BeneficiaryNotFound();
error NoTokensToClaim();
error NotABeneficiary();

error NoMilestonesProvided();
