// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;
import {IBridgeReceiver} from "./interfaces/bridge/IBridgeReceiver.sol";
import {IBridgeSender} from "./interfaces/bridge/IBridgeSender.sol";
import {IDestinationBridge} from "./interfaces/bridge/IDestinationBridge.sol";
import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";
import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";

import "forge-std/console.sol";

contract DestinationAdapter is IBridgeReceiver, IBridgeSender {
    IStrategy vault;

    mapping(address => uint256) depositors;

    constructor(
        //TODO use 4668 interface
        IStrategy _vault
    ) {
        vault = _vault;
    }

    function onFundsReceivedCallback(
        address token,
        uint amount,
        bytes calldata data
    ) external override {
        ERC20(token).increaseAllowance(address(vault), amount);
        uint deposited = vault.deposit(amount, address(this));
        uint p = vault.pricePerShare();
        depositors[msg.sender] += p * deposited;
    }

    function onFundsRequested(
        address token,
        uint amount,
        bytes calldata data
    ) external returns (uint) {
        //Figure out how to deal with maxLoss
        uint maxLoss = 0;
        uint received = vault.withdraw(
            amount,
            address(this),
            address(this),
            maxLoss
        );
        depositors[msg.sender] -= received;
        ERC20(vault.asset()).transfer(msg.sender, received);
        //Todo deal with withdrawl limit
        return amount;
    }
}
