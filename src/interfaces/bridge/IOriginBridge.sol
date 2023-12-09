// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

interface IOriginBridge {
    function deposit(
        address receiver,
        address token,
        uint256 _amount
    ) external payable;

    function withdraw(address token, uint256 _amount) external payable;

    function getDepositFee(
        address token,
        uint256 _amount
    ) external returns (address, uint256);

    function getWithdrawlFee(
        address token,
        uint256 _amount
    ) external returns (address, uint256);
}
 