// SPDX-License-Identifier: None
pragma solidity >=0.5.0;

import "./alcor_pool/IAlcorPoolImmutables.sol";
import "./alcor_pool/IAlcorPoolState.sol";
import "./alcor_pool/IAlcorPoolDerivedState.sol";
import "./alcor_pool/IAlcorPoolActions.sol";
import "./alcor_pool/IAlcorPoolOwnerActions.sol";
import "./alcor_pool/IAlcorPoolEvents.sol";

/// @title The interface for a Alcor Pool
/// @notice An Alcor Pool Call Option contract
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IAlcorPoolCallOption is
    IAlcorPoolImmutables,
    IAlcorPoolState,
    IAlcorPoolDerivedState,
    IAlcorPoolActions,
    IAlcorPoolOwnerActions,
    IAlcorPoolEvents
{
    struct OptionInfo {
        // TOKEN0 must be STABLECOIN
        address token0;
        // TOKEN1 must be RISKY ASSET (WETH)
        address token1;
        uint8 token0Decimals;
        uint8 token1Decimals;
        uint256 expiration;
        uint160 strikePriceX96;
        bool isCallOption;
        int24 tickSpacing;
        // uint24 protocolFee;
        bool isExpired;
        uint256 payoff_token1;
        uint256 openInterest;
    }
}
