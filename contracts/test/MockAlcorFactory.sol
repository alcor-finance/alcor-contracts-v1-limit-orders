// SPDX-License-Identifier: None
pragma solidity =0.7.6;

import "../AlcorFactory.sol";
import "./MockAlcorPoolCallOption.sol";

import "hardhat/console.sol";

contract MockAlcorFactory is AlcorFactory {
    constructor() AlcorFactory() {}

    function deployCallOption(
        address factory,
        address token0,
        address token1,
        uint256 optionExpiration,
        uint160 optionStrikePriceX96,
        int24 tickSpacing
    ) internal override returns (address pool) {
        parameters = Parameters({
            factory: factory,
            token0: token0,
            token1: token1,
            token0Decimals: IERC20Minimal(token0).decimals(),
            token1Decimals: IERC20Minimal(token1).decimals(),
            expiration: optionExpiration,
            strikePrice: optionStrikePriceX96,
            tickSpacing: tickSpacing
        });
        pool = address(
            new MockAlcorPoolCallOption{
                salt: keccak256(
                    abi.encode(
                        token0,
                        token1,
                        optionStrikePriceX96,
                        optionExpiration
                    )
                )
            }()
        );
        delete parameters;
    }

    function createPoolCallOption(
        address tokenA,
        address tokenB,
        uint256 optionExpiration,
        uint160 optionStrikePrice
    ) external override noDelegateCall returns (address pool) {
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0));

        // int24 tickSpacing = feeAmountTickSpacing[fee];

        bool isCall = true;

        int24 tickSpacing = 10;
        require(tickSpacing != 0);
        require(
            getPool[token0][token1][optionExpiration][isCall][
                optionStrikePrice
            ] == address(0)
        );
        pool = deployCallOption(
            address(this),
            token0,
            token1,
            optionExpiration,
            optionStrikePrice,
            tickSpacing
        );
        getPool[token0][token1][optionExpiration][isCall][
            optionStrikePrice
        ] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPool[token1][token0][optionExpiration][isCall][
            optionStrikePrice
        ] = pool;
        // lookup table for pools
        isPool[pool] = true;

        _getStrikesForPairAndExpiration[token0][token1][optionExpiration][
            isCall
        ].push(optionStrikePrice);
        _getStrikesForPairAndExpiration[token1][token0][optionExpiration][
            isCall
        ].push(optionStrikePrice);

        emit PoolCreated(
            token0,
            token1,
            optionExpiration,
            isCall,
            optionStrikePrice,
            tickSpacing,
            pool
        );
    }
}
