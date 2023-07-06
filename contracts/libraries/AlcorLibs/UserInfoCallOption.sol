// SPDX-License-Identifier: None
pragma solidity >=0.5.0 <0.8.0;


/// @title CallOptionUserInfo
/// @notice
/// @dev
library UserInfoCallOption {
    struct Info {
        uint256 token0_totalDeposits;
        uint256 token1_totalDeposits;
        // amount of contracts that is sold (positive)
        // if user bought contracts, this value is negative
        int256 soldContractsAmount;
        // equals zero is soldContractsAmount not higher than zero
        uint256 token1_lockedAmount;
    }

    function updateSoldContractsAmount(
        mapping(address => Info) storage self,
        address owner,
        int256 amount
    ) internal returns (int256) {
        self[owner].soldContractsAmount += amount;
        if (self[owner].soldContractsAmount > 0) {
            self[owner].token1_lockedAmount = uint256(
                self[owner].soldContractsAmount
            );
        } else {
            self[owner].token1_lockedAmount = 0;
        }
        return self[owner].soldContractsAmount;
    }

    function increaseToken0TotalDeposits(
        mapping(address => Info) storage self,
        address owner,
        uint256 amount
    ) internal {
        self[owner].token0_totalDeposits += amount;
    }

    function decreaseToken0TotalDeposits(
        mapping(address => Info) storage self,
        address owner,
        uint256 amount
    ) internal {
        require(
            self[owner].token0_totalDeposits >= amount,
            "decreaseToken0TotalDeposits: amount exceeds total deposits"
        );
        self[owner].token0_totalDeposits -= amount;
    }

    /// @notice Returns the Info struct of a position
    function get(
        mapping(address => Info) storage self,
        address owner
    ) internal view returns (UserInfoCallOption.Info storage position) {
        position = self[owner];
    }
}
