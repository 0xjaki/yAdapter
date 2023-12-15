// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";

interface IStrategyInterface is IStrategy {
    //TODO: Add your specific implementation interface in here.
    function bridgedAssets() external returns (uint);

    function setDestinationBridge(address _bridge) external;

    function calcDepositAmount() external view returns (uint);

    function calcWithdrawlAmount() external view returns (uint);

    function depositFunds(uint256 _amount) external payable;

    function requestWithdrawl(uint256 _amount) external payable;
}
