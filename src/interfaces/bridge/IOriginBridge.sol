// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

/**
 * @title IOriginBridge
 * @dev Interface for interacting with the origin bridge to deposit and withdraw funds.
 */
interface IOriginBridge {
    /**
     * @dev Deposits funds to the bridge for transfer to the destination chain.
     * @param receiver The address of the receiver on the destination chain.
     * @param token The address of the token to be deposited.
     * @param _amount The amount of tokens to be deposited.
     */
    function deposit(
        address receiver,
        address token,
        uint256 _amount
    ) external payable;

    /**
     * @dev Initiates the withdrawal of tokens from the bridge.
     * @param token The address of the token to be withdrawn.
     * @param _amount The amount of tokens to be withdrawn.
     */
    function withdraw(address token, uint256 _amount) external payable;

    /**
     * @dev Retrieves the deposit fee for a given token and amount.
     * @param token The address of the token.
     * @param _amount The amount of tokens to be deposited.
     * @return The address and amount of the deposit fee.
     */
    function getDepositFee(
        address token,
        uint256 _amount
    ) external returns (address, uint256);

    /**
     * @dev Retrieves the withdrawal fee for a given token and amount.
     * @param token The address of the token.
     * @param _amount The amount of tokens to be withdrawn.
     * @return The address and amount of the withdrawal fee.
     */
    function getWithdrawlFee(
        address token,
        uint256 _amount
    ) external returns (address, uint256);
}
