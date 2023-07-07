// SPDX-License-Identifier: None
pragma solidity =0.7.6;
pragma abicoder v2;

import "./dependencies/ReentrancyGuard.sol";

import "./libraries/LowGasSafeMath.sol";
import "./libraries/SafeCast.sol";
import "./libraries/TransferHelper.sol";

import "./libraries/AlcorLibs/UserInfoCallOption.sol";
import "./libraries/AlcorLibs/Cryptography.sol";
import "./libraries/AlcorLibs/TickLibrary.sol";

import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IUniswapV3Factory.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/IAlcorPoolDeployer.sol";
import "./interfaces/IAlcorFactory.sol";

import "hardhat/console.sol";

contract AlcorPoolCallOption is ReentrancyGuard {
    using FullMath for uint256;
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;

    using TickLibrary for int24;

    using Cryptography for Cryptography.SellingLimitOrder;
    using Cryptography for Cryptography.BuyingLimitOrder;
    using Cryptography for bytes32;

    address public immutable factory;
    uint24 public immutable protocolFee;

    uint256 public token0_unclaimedProtocolFees;
    uint256 public token1_unclaimedProtocolFees;

    struct OptionInfo {
        // TOKEN0 must be STABLECOIN
        address token0;
        // TOKEN1 must be RISKY ASSET (WETH)
        address token1;
        uint8 token0Decimals;
        uint8 token1Decimals;
        uint256 expiration;
        uint160 strikePrice;
        bool isCallOption;
        int24 tickSpacing;
        // uint24 protocolFee;
        bool isExpired;
        uint256 payoff_token0;
        uint256 openInterest;
        uint256 priceAtExpiry;
    }

    address public constant UNISWAP_V3_FACTORY =
        0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public constant ISWAP_ROUTER =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;
    uint24 public constant UNISWAP_POOL_FEE = 500;

    OptionInfo public optionMainInfo;

    mapping(address => UserInfoCallOption.Info) public usersInfo;

    using UserInfoCallOption for mapping(address => UserInfoCallOption.Info);

    struct limitOrderFulfilment {
        uint256 fulfilledAmount;
        bool isFulfilled;
    }
    // keccak256(signature of the limit order)
    mapping(bytes32 => limitOrderFulfilment) public limitOrdersFulfilments;

    /// @dev Prevents calling a function from anyone except the address returned by IAlcorFactory#owner()
    modifier onlyFactoryOwner() {
        require(msg.sender == IAlcorFactory(factory).owner());
        _;
    }

    modifier optionNotExpired() {
        console.log(block.timestamp, optionMainInfo.expiration);
        require(
            block.timestamp < optionMainInfo.expiration,
            "option is expired"
        );
        _;
    }

    constructor() {
        (
            factory,
            optionMainInfo.token0,
            optionMainInfo.token1,
            optionMainInfo.token0Decimals,
            optionMainInfo.token1Decimals,
            optionMainInfo.expiration,
            optionMainInfo.strikePrice,
            optionMainInfo.tickSpacing
        ) = IAlcorPoolDeployer(msg.sender).parameters();

        optionMainInfo.isCallOption = true;
        protocolFee = 500; // 0.05%
    }

    function claimProtocolFees(
        address token,
        uint256 amount
    ) external nonReentrant onlyFactoryOwner {
        require(
            token == optionMainInfo.token0 || token == optionMainInfo.token1,
            "Invalid token"
        );

        if (token == optionMainInfo.token0) {
            require(amount <= token0_unclaimedProtocolFees, "amount too big");
            token0_unclaimedProtocolFees -= amount;
            TransferHelper.safeTransfer(token, msg.sender, amount);
        } else {
            require(amount <= token1_unclaimedProtocolFees, "amount too big");
            token1_unclaimedProtocolFees -= amount;
            TransferHelper.safeTransfer(token, msg.sender, amount);
        }
    }

    // when option is expired, users can claim their funds: collaterals, payouts
    // function claim(address token, uint256 amount) public nonReentrant {}

    function getPayout() public nonReentrant {
        require(optionMainInfo.isExpired, "option is not expired");
        require(
            usersInfo[msg.sender].soldContractsAmount < 0,
            "this method is only for buyes"
        );
        if (optionMainInfo.payoff_token0 > 0) {
            usersInfo[msg.sender].soldContractsAmount = 0;
            uint256 amount = uint256(usersInfo[msg.sender].soldContractsAmount)
                .mul(optionMainInfo.payoff_token0);
            TransferHelper.safeTransfer(
                optionMainInfo.token0,
                msg.sender,
                amount
            );
        }
    }

    function withdrawCollateral() public nonReentrant {
        require(optionMainInfo.isExpired, "option is not expired");
        require(
            usersInfo[msg.sender].soldContractsAmount > 0,
            "this method is only for sellers"
        );
        if (optionMainInfo.payoff_token0 < 0) {
            usersInfo[msg.sender].soldContractsAmount = 0;
            uint256 amount = uint256(usersInfo[msg.sender].soldContractsAmount)
                .mul(optionMainInfo.priceAtExpiry);
            TransferHelper.safeTransfer(
                optionMainInfo.token0,
                msg.sender,
                amount
            );
        } else {
            usersInfo[msg.sender].soldContractsAmount = 0;
            uint256 amount = uint256(usersInfo[msg.sender].soldContractsAmount)
                .mul(optionMainInfo.strikePrice);
            TransferHelper.safeTransfer(
                optionMainInfo.token0,
                msg.sender,
                amount
            );
        }
    }

    function ToExpiredState() public {
        require(block.timestamp >= optionMainInfo.expiration, "too early");
        optionMainInfo.isExpired = true;

        address uniswap_pool = IUniswapV3Factory(UNISWAP_V3_FACTORY).getPool(
            optionMainInfo.token0,
            optionMainInfo.token1,
            UNISWAP_POOL_FEE
        );
        ISwapRouter router = ISwapRouter(ISWAP_ROUTER);

        address tokenIn = optionMainInfo.token1;
        address tokenOut = optionMainInfo.token0;

        uint256 tokenIn_balance = IERC20(tokenIn).balanceOf(address(this));
        // aprove tokenIn
        IERC20(optionMainInfo.token1).approve(address(router), tokenIn_balance);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: UNISWAP_POOL_FEE,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: tokenIn_balance,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // execute swap
        router.exactInputSingle(params);

        (, int24 tick, , , , , ) = IUniswapV3Pool(uniswap_pool).slot0();
        optionMainInfo.priceAtExpiry = tick.getPriceAtTick();

        // out of the money call option
        if (optionMainInfo.priceAtExpiry <= optionMainInfo.strikePrice) {
            optionMainInfo.payoff_token0 = 0;
        }
        // in the money call option
        else {
            optionMainInfo.payoff_token0 = (optionMainInfo.priceAtExpiry -
                uint256(optionMainInfo.strikePrice));
        }
    }

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the amount remaining to be swapped in/out of the input/output asset
        uint256 contractsAmountRemaining;
        // the amount already swapped out/in of the output/input asset
        uint256 cost_token0;
        // amount of input token paid as protocol fee
        uint256 protocolFee_token0;
    }

    struct StepComputations {
        uint256 contractPrice;
        address signer;
        uint256 contractsDelta;
        uint256 step_cost_token0;
    }

    function buyOption(
        uint256 amountToBuy,
        bytes[] memory signatures,
        Cryptography.SellingLimitOrder[] memory sellingLimitOrders
    )
        public
        // Cryptography.BaseLimitOrder[] memory BaseLimitOrders
        nonReentrant
        optionNotExpired
    {
        SwapState memory swapState = SwapState({
            contractsAmountRemaining: amountToBuy,
            cost_token0: 0,
            protocolFee_token0: 0
        });

        StepComputations memory step;

        for (uint8 i = 0; i < signatures.length; i++) {
            // important for security: we put option params, calculate hash and then check the signature
            sellingLimitOrders[i].isCallOption = optionMainInfo.isCallOption;
            sellingLimitOrders[i].expiration = optionMainInfo.expiration;
            sellingLimitOrders[i].for_buying = false;
            sellingLimitOrders[i].strikePrice = optionMainInfo.strikePrice;

            step.signer = Cryptography.recoverSigner(
                Cryptography.getEthSignedMessageHash(
                    Cryptography.getSellingLimitOrderHash(sellingLimitOrders[i])
                ),
                signatures[i]
            );

            console.log("signer:");
            console.log(step.signer);
            require(
                step.signer == sellingLimitOrders[i].owner,
                "Invalid owner"
            );
            require(
                sellingLimitOrders[i].deadline > block.timestamp,
                "Deadline is reached"
            );

            step.contractPrice = sellingLimitOrders[i]
                .premiumTick
                .getPriceAtTick();
            console.log("contractPrice at the step:");
            console.log(step.contractPrice);

            // the amount of contracts that can be bought from this limit order
            uint256 limitOrderFulfilledContractsAmount = limitOrdersFulfilments[
                keccak256(signatures[i])
            ].fulfilledAmount;

            // uint256 _seller_available_delta = usersInfo[step.signer]
            //     .token1_totalDeposits
            //     .sub(usersInfo[step.signer].token1_lockedAmount);

            // require(
            //     _seller_available_delta >=
            //         sellingLimitOrders[i].contracts_amount.sub(
            //             limitOrderFulfilledContractsAmount
            //         ),
            //     "seller's token1 balance is not enough to cover the limit order"
            // );

            // console.log(_seller_available_delta);
            console.log(
                sellingLimitOrders[i].contracts_amount.sub(
                    limitOrderFulfilledContractsAmount
                )
            );

            if (
                swapState.contractsAmountRemaining >=
                sellingLimitOrders[i].contracts_amount.sub(
                    limitOrderFulfilledContractsAmount
                )
            ) {
                console.log("here");
                // the selling order becomes fully fulfilled, i.e. amount that can be bought is the entire available amount
                step.contractsDelta = sellingLimitOrders[i]
                    .contracts_amount
                    .sub(limitOrderFulfilledContractsAmount);
                // set limit order as fulfilled
                limitOrdersFulfilments[keccak256(signatures[i])]
                    .isFulfilled = true;
            } else {
                step.contractsDelta = swapState.contractsAmountRemaining;
            }

            limitOrdersFulfilments[keccak256(signatures[i])]
                .fulfilledAmount += step.contractsDelta;
            // update remaining contracts amount
            swapState.contractsAmountRemaining -= step.contractsDelta;

            // update seller's sold contracts amount and locked contracts amount
            usersInfo.updateSoldContractsAmount(
                step.signer,
                step.contractsDelta.toInt256()
            );
            // update buyer's bought contracts amount and locked contracts amount
            usersInfo.updateSoldContractsAmount(
                msg.sender,
                -step.contractsDelta.toInt256()
            );

            step.step_cost_token0 = step.contractPrice.mulDiv(
                step.contractsDelta,
                1 ether
            );

            // add protocol fee
            step.step_cost_token0 += step.step_cost_token0.mulDiv(
                protocolFee,
                1e6
            );
            swapState.cost_token0 += step.step_cost_token0;

            token0_unclaimedProtocolFees = swapState.cost_token0.mulDiv(
                protocolFee,
                1e6
            );

            console.log("step.step_cost_token0:");
            console.log(step.step_cost_token0);

            // safe transfer from buyer to seller
            TransferHelper.safeTransferFrom(
                optionMainInfo.token0,
                msg.sender,
                step.signer,
                swapState.cost_token0 // TODO: take into account the decimals of token0
            );

            // safe transfer from seller to the contract
            TransferHelper.safeTransferFrom(
                optionMainInfo.token1,
                step.signer,
                address(this),
                step.contractsDelta // TODO: take into account the decimals of token0
            );

            if (swapState.contractsAmountRemaining == 0) {
                break;
            }
        }
        console.log("swapState.cost_token0:");
        console.log(swapState.cost_token0);
    }

    function sellOption(
        uint256 amountToSell,
        bytes[] memory signatures,
        Cryptography.BuyingLimitOrder[] memory buyingLimitOrders
    ) public nonReentrant optionNotExpired {
        SwapState memory swapState = SwapState({
            contractsAmountRemaining: amountToSell,
            cost_token0: 0,
            protocolFee_token0: 0
        });

        StepComputations memory step;

        for (uint8 i = 0; i < signatures.length; i++) {
            // important for security: we put option params, calculate hash and then check the signature
            buyingLimitOrders[i].isCallOption = optionMainInfo.isCallOption;
            buyingLimitOrders[i].expiration = optionMainInfo.expiration;
            buyingLimitOrders[i].for_buying = true;
            buyingLimitOrders[i].strikePrice = optionMainInfo.strikePrice;

            step.signer = Cryptography.recoverSigner(
                Cryptography.getEthSignedMessageHash(
                    Cryptography.getBuyingLimitOrderHash(buyingLimitOrders[i])
                ),
                signatures[i]
            );
            console.log("signer:");
            console.log(step.signer);

            require(step.signer == buyingLimitOrders[i].owner, "Invalid owner");
            require(
                buyingLimitOrders[i].deadline > block.timestamp,
                "Deadline is reached"
            );

            step.contractPrice = buyingLimitOrders[i]
                .premiumTick
                .getPriceAtTick();
            console.log("contractPrice at the step:");
            console.log(step.contractPrice);

            // the amount of contracts that has been already sold to i-th limit order
            uint256 limitOrderFulfilledContractsAmount = limitOrdersFulfilments[
                keccak256(signatures[i])
            ].fulfilledAmount;

            console.log(
                "the cost of i-th buying limit order: ",
                buyingLimitOrders[i]
                    .contracts_amount
                    .sub(limitOrderFulfilledContractsAmount)
                    .mulDiv(step.contractPrice, 1 ether)
            );

            // uint256 _buyer_available_delta = usersInfo[step.signer]
            //     .token0_totalDeposits;

            // usersInfo[step.signer].token0_totalDeposits;

            // require(
            //     usersInfo[step.signer].token0_totalDeposits >=
            //         buyingLimitOrders[i]
            //             .contracts_amount
            //             .sub(limitOrderFulfilledContractsAmount)
            //             .mulDiv(step.contractPrice, 1 ether),
            //     "buyer's token0 balance is not enough"
            // );

            if (
                swapState.contractsAmountRemaining >=
                buyingLimitOrders[i].contracts_amount.sub(
                    limitOrderFulfilledContractsAmount
                )
            ) {
                console.log("here");
                // the buying limit order becomes fully fulfilled
                step.contractsDelta = buyingLimitOrders[i].contracts_amount.sub(
                    limitOrderFulfilledContractsAmount
                );
                // set limit order as fulfilled
                limitOrdersFulfilments[keccak256(signatures[i])]
                    .isFulfilled = true;
            } else {
                step.contractsDelta = swapState.contractsAmountRemaining;
            }

            limitOrdersFulfilments[keccak256(signatures[i])]
                .fulfilledAmount += step.contractsDelta;
            // update remaining contracts amount
            swapState.contractsAmountRemaining -= step.contractsDelta;

            // update buyer's sold contracts amount and locked contracts amount
            usersInfo.updateSoldContractsAmount(
                step.signer,
                -step.contractsDelta.toInt256()
            );

            step.step_cost_token0 = step.contractPrice.mulDiv(
                step.contractsDelta,
                1 ether
            );

            // add protocol fee
            step.step_cost_token0 += step.step_cost_token0.mulDiv(
                protocolFee,
                1e6
            );
            swapState.cost_token0 += step.step_cost_token0;

            token0_unclaimedProtocolFees = swapState.cost_token0.mulDiv(
                protocolFee,
                1e6
            );

            // decrease buyer's token0 total deposits as he buys option
            // usersInfo.decreaseToken0TotalDeposits(
            //     step.signer,
            //     step.step_cost_token0
            // );

            console.log("step.step_cost_token0: ", step.step_cost_token0);
            // TransferHelper.safeTransfer(
            //     optionMainInfo.token0,
            //     msg.sender,
            //     step.step_cost_token0 // TODO: take into account the decimals of token0
            // );

            // safe transfer from buyer to seller
            TransferHelper.safeTransferFrom(
                optionMainInfo.token0,
                step.signer,
                msg.sender,
                swapState.cost_token0 // TODO: take into account the decimals of token0
            );

            if (swapState.contractsAmountRemaining == 0) {
                break;
            }
        }

        console.log("transfer collateral");
        console.log(
            "amountToSell - swapState.contractsAmountRemaining: ",
            amountToSell - swapState.contractsAmountRemaining
        );
        // transfer collateral
        TransferHelper.safeTransferFrom(
            optionMainInfo.token1,
            msg.sender,
            address(this),
            amountToSell - swapState.contractsAmountRemaining
        );
        // update seller's sold contracts amount
        // usersInfo[msg.sender].token1_totalDeposits += (amountToSell -
        //     swapState.contractsAmountRemaining);
        usersInfo.updateSoldContractsAmount(
            msg.sender,
            (amountToSell - swapState.contractsAmountRemaining).toInt256()
        );

        console.log("swapState.cost_token0: ", swapState.cost_token0);
    }

    function getSellingLimitOrderHash(
        Cryptography.BaseLimitOrder memory limitOrder
    ) public view returns (bytes32) {
        Cryptography.SellingLimitOrder memory sellingLimitOrder = Cryptography
            .SellingLimitOrder({
                owner: limitOrder.owner,
                contracts_amount: limitOrder.contracts_amount,
                premiumTick: limitOrder.premiumTick,
                deadline: limitOrder.deadline,
                // we add extra option params to stick the hash to this option
                isCallOption: optionMainInfo.isCallOption,
                for_buying: limitOrder.for_buying,
                expiration: optionMainInfo.expiration,
                strikePrice: optionMainInfo.strikePrice
            });

        return sellingLimitOrder.getSellingLimitOrderHash();
    }

    function getBuyingLimitOrderHash(
        Cryptography.BaseLimitOrder memory limitOrder
    ) public view returns (bytes32) {
        Cryptography.BuyingLimitOrder memory buyingLimitOrder = Cryptography
            .BuyingLimitOrder({
                owner: limitOrder.owner,
                contracts_amount: limitOrder.contracts_amount,
                premiumTick: limitOrder.premiumTick,
                deadline: limitOrder.deadline,
                // we add extra option params to stick the hash to this option
                isCallOption: optionMainInfo.isCallOption,
                for_buying: limitOrder.for_buying,
                expiration: optionMainInfo.expiration,
                strikePrice: optionMainInfo.strikePrice
            });

        return buyingLimitOrder.getBuyingLimitOrderHash();
    }
}
