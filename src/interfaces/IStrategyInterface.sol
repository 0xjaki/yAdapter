// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";

interface IStrategyInterface is IStrategy {
    //TODO: Add your specific implementation interface in here.
    function bridgedAssets() external returns (uint);

    function staging() external returns (uint);

    function preHarvest(uint _amount) external;

    function setDestinationAdapter(address _adapter) external;
}
