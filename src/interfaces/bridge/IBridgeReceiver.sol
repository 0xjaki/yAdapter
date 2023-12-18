// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

/**
 * @title IBridgeReceiver Interface
 * @dev This interface defines the function that should be implemented by any contract 
 * that is intended to receive funds from a bridge contract.
 */
interface IBridgeReceiver {
    /**
     * @notice This function is called when funds are received from the bridge contract.
     * @param token The address of the token contract for the received funds.
     * @param amount The amount of tokens received.
     * @param data Additional data sent by the bridge contract.
     */
    function onFundsReceivedCallback(
        address token,
        uint amount,
        bytes calldata data
    ) external;
}
