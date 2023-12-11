// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

interface IBridgeSender {
    function onFundsRequested(
        address token,
        uint amount,
        bytes calldata data
    ) external returns (uint);
}
