// SPDX-License-Identifier: None
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

/// @title Cryptography
/// @notice
/// @dev
library Cryptography {
    struct BaseLimitOrder {
        address owner;
        bool for_buying;
        uint256 contracts_amount;
        int24 premiumTick;
        uint256 deadline;
    }

    struct SellingLimitOrder {
        // these fields are necessary to stick order to one option contract
        bool isCallOption;
        bool for_buying;
        // uint32 chainId;

        uint256 expiration;
        uint160 strikePrice;
        //
        address owner;
        uint256 contracts_amount;
        int24 premiumTick;
        uint256 deadline;
    }

    struct BuyingLimitOrder {
        // these fields are necessary to stick order to only one option contract
        bool isCallOption;
        bool for_buying;
        // uint32 chainId;

        uint256 expiration;
        uint160 strikePrice;
        //
        address owner;
        uint256 contracts_amount;
        int24 premiumTick;
        uint256 deadline;
    }

    bytes32 internal constant _SELLING_LIMIT_ORDER_TYPEHASH =
        keccak256(
            "SellingLimitOrder(bool isCallOption,bool for_buying,uint256 expiration,uint160 strikePrice,address owner,uint256 contracts_amount,uint256 premiumTick,uint256 deadline)"
        );

    bytes32 internal constant _BUYING_LIMIT_ORDER_TYPEHASH =
        keccak256(
            "BuyingLimitOrder(bool isCallOption,bool for_buying,uint256 expiration,uint160 strikePrice,address owner,uint256 contracts_amount,uint256 premiumTick,uint256 deadline)"
        );

    function getSellingLimitOrderHash(
        SellingLimitOrder memory sellingLimitOrder
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _SELLING_LIMIT_ORDER_TYPEHASH,
                    sellingLimitOrder.isCallOption,
                    sellingLimitOrder.for_buying,
                    sellingLimitOrder.expiration,
                    sellingLimitOrder.strikePrice,
                    sellingLimitOrder.owner,
                    sellingLimitOrder.contracts_amount,
                    sellingLimitOrder.premiumTick,
                    sellingLimitOrder.deadline
                )
            );
    }

    function getBuyingLimitOrderHash(
        BuyingLimitOrder memory buyingLimitOrder
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _BUYING_LIMIT_ORDER_TYPEHASH,
                    buyingLimitOrder.isCallOption,
                    buyingLimitOrder.for_buying,
                    buyingLimitOrder.expiration,
                    buyingLimitOrder.strikePrice,
                    buyingLimitOrder.owner,
                    buyingLimitOrder.contracts_amount,
                    buyingLimitOrder.premiumTick,
                    buyingLimitOrder.deadline
                )
            );
    }

    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) internal pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }
}
