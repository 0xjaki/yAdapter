// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

/**
 * @title IDestinationBridge
 * @dev Interface for receiving funds from the bridge and processing the transfer.
 */
interface IDestinationBridge {
    /**
     * @dev Initiates the redemption of tokens received from the bridge.
     * @param receiver The address of the receiver.
     * @param token The address of the token to be redeemed.
     * @param _amount The amount of tokens to be redeemed.
     * @return The result of the redemption operation.
     */
    function redeem(
        address receiver,
        address token,
        uint256 _amount
    ) external payable returns (uint);

    /**
     * @dev Retrieves the redemption fee for a given token and amount.
     * @param token The address of the token.
     * @param _amount The amount of tokens to be redeemed.
     * @return The address and amount of the redemption fee.
     */
    function getRedeemFee(
        address token,
        uint256 _amount
    ) external returns (address, uint256);
}
