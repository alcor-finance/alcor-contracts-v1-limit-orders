// SPDX-License-Identifier: None
pragma solidity =0.7.6;

import "./interfaces/IAlcorFactory.sol";

import "./AlcorPoolDeployer.sol";
import "./NoDelegateCall.sol";

import "hardhat/console.sol";

/// @title AlcorFactory
contract AlcorFactory is IAlcorFactory, AlcorPoolDeployer, NoDelegateCall {
    address public override owner;

    mapping(uint24 => int24) public override feeAmountTickSpacing;
    // /// @inheritdoc IAlcorFactory
    // mapping(address => mapping(address => mapping(uint24 => address)))
    //     public
    //     override getPool;

    // token0 => token1 => optionExpiration => isCall => optionStrikePrice => pool
    // token1 => token0 => optionExpiration => isCall => optionStrikePrice => pool
    mapping(address => mapping(address => mapping(uint256 => mapping(bool => mapping(uint160 => address)))))
        public getPool;
    mapping(address => bool) public isPool;

    // the info about all pools for the token pair and expiration
    // token0 => token1 => optionExpiration => isCall => strikes[]
    mapping(address => mapping(address => mapping(uint256 => mapping(bool => uint160[]))))
        internal _getStrikesForPairAndExpiration;

    function getStrikesForPairAndExpiration(
        address token0,
        address token1,
        uint256 optionExpiration,
        bool isCall
    ) public view returns (uint160[] memory strikes) {
        strikes = _getStrikesForPairAndExpiration[token0][token1][
            optionExpiration
        ][isCall];
    }

    function getAddressesForPairAndExpiration(
        address token0,
        address token1,
        uint256 optionExpiration,
        bool isCall
    ) public view returns (address[] memory poolsAddresses) {
        uint160[] memory strikes = _getStrikesForPairAndExpiration[token0][
            token1
        ][optionExpiration][isCall];
        poolsAddresses = new address[](strikes.length);
        for (uint32 i = 0; i < strikes.length; i++) {
            poolsAddresses[i] = getPool[token0][token1][optionExpiration][
                isCall
            ][strikes[i]];
        }
    }

    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);

        // kirrya:
        feeAmountTickSpacing[0] = 10;
        emit FeeAmountEnabled(0, 10);

        // feeAmountTickSpacing[500] = 10;
        // emit FeeAmountEnabled(500, 10);
        // feeAmountTickSpacing[3000] = 60;
        // emit FeeAmountEnabled(3000, 60);
        // feeAmountTickSpacing[10000] = 200;
        // emit FeeAmountEnabled(10000, 200);
    }

    function createPoolCallOption(
        address tokenA,
        address tokenB,
        uint256 optionExpiration,
        uint160 optionStrikePrice
    ) external virtual noDelegateCall returns (address pool) {
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

    /// @inheritdoc IAlcorFactory
    function setOwner(address _owner) external override {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @inheritdoc IAlcorFactory
    function enableFeeAmount(uint24 fee, int24 tickSpacing) public override {
        require(msg.sender == owner);
        require(fee < 1000000);
        // tick spacing is capped at 16384 to prevent the situation where tickSpacing is so large that
        // TickBitmap#nextInitializedTickWithinOneWord overflows int24 container from a valid tick
        // 16384 ticks represents a >5x price change with ticks of 1 bips
        require(tickSpacing > 0 && tickSpacing < 16384);
        require(feeAmountTickSpacing[fee] == 0);

        feeAmountTickSpacing[fee] = tickSpacing;
        emit FeeAmountEnabled(fee, tickSpacing);
    }

    // function getPoolsInfo(
    //     address tokenA,
    //     address tokenB,
    //     uint256 optionExpiration,
    //     bool isCall
    // ) external view {
    //     // address[] memory pools = getPoolForPairAndExpiration[tokenA][tokenB][optionExpiration];
    //     for (uint256 i = 0; i < getPool.length; i++) {
    //         // console.log("pool: %s", pools[i]);
    //         // IAlcorPoolCallOption(pools[i]).optionMainInfo();
    //     }
    // }
}
