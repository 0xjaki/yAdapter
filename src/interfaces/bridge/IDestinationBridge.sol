// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

interface IDestinationBridge {
    function redeem(
        address receiver,
        address token,
        uint256 _amount
    ) external payable returns (uint);

    function getRedeemFee(
        address token,
        uint256 _amount
    ) external returns (address, uint256);
}
