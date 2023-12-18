// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

/**
 * @title ConnextBase Contract
 * @dev This abstract contract provides base functionality for interacting with the Connext protocol.
 * It includes constants for Connext function selectors and a method for calculating Connext router fees.
 */
abstract contract ConnextBase {
    bytes4 internal constant DEPOST_SELECTOR = bytes4(keccak256("deposit()"));

    bytes4 internal constant WITHDRAW_SELECTOR =
        bytes4(keccak256("withdraw(address,uint256)"));

    bytes4 internal constant REDEEM_SELECTOR =
        bytes4(keccak256("redeem(uint256)"));

    uint public slippage = 30;

    /**
     * @notice Calculates the Connext router fee for a given token and amount.
     * @param token The address of the token contract.
     * @param _amount The amount of tokens to be transferred.
     * @return The address of the token and the calculated fee.
     */
    function getConnextRouterFee(
        address token,
        uint256 _amount
    ) public pure virtual returns (address, uint) {
        //See https://docs.connext.network/developers/guides/estimating-fees
        //Connext charges 0.05% of the transferred amount
        uint relayerFee = (_amount * 5) / 10000;
        return (token, relayerFee);
    }
}
