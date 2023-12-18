// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

/**
 * @title IBridgeSender
 * @dev Interface for sending funds from the bridge to another contract or address.
 */
interface IBridgeSender {
    /**
     * @dev Callback function that can be invoked after
     * @param token The address of the token being transferred.
     * @param amount The amount of tokens being transferred.
     * @param data Additional call data for the transfer operation.
     * @return The result of the transfer operation.
     */
    function onFundsRequested(
        address token,
        uint amount,
        bytes calldata data
    ) external returns (uint);
}
