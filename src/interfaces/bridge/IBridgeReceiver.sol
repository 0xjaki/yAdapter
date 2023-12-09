// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

interface IBridgeReceiver {
    function onFundsReceivedCallback(
        address token,
        uint amount,
        uint left
    ) external;
}
