// SPDX-License-Identifier: None
pragma solidity =0.7.6;
pragma abicoder v2;

import "../AlcorPoolCallOption.sol";

contract MockAlcorPoolCallOption is AlcorPoolCallOption {
    using Cryptography for Cryptography.SellingLimitOrder;
    using Cryptography for Cryptography.BuyingLimitOrder;

    using Cryptography for bytes32;

    constructor() AlcorPoolCallOption() {}

    function getHash(
        bytes memory _hash
    ) public pure returns (bytes32 hashedHash) {
        hashedHash = keccak256(_hash);
    }

    function getEthSignedMessageHash(
        bytes32 _rawMessageHash
    ) public pure returns (bytes32) {
        return _rawMessageHash.getEthSignedMessageHash();
    }

    function recoverSigner(
        bytes32 _rawMessageHash,
        bytes memory _signature
    ) public pure returns (address) {
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(_rawMessageHash);
        return ethSignedMessageHash.recoverSigner(_signature);
    }
}
