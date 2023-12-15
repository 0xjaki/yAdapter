// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;
import {IBridgeReceiver} from "./interfaces/bridge/IBridgeReceiver.sol";
import {IBridgeSender} from "./interfaces/bridge/IBridgeSender.sol";
import {IDestinationBridge} from "./interfaces/bridge/IDestinationBridge.sol";
import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";
import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";

import "forge-std/console.sol";

interface IDestinationAdapter is IBridgeReceiver, IBridgeSender {}

contract DestinationAdapter is IDestinationAdapter {
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
        bytes calldata
    ) external override {
        ERC20(token).increaseAllowance(address(vault), amount);
        uint deposited = vault.deposit(amount, address(this));
        uint p = vault.pricePerShare();
        depositors[msg.sender] += p * deposited;
    }

    function onFundsRequested(
        address,
        uint amount,
        bytes calldata
    ) external returns (uint) {
        //Figure out how to deal with maxLoss
        uint maxLoss = 0;
        //convert to shares

        uint balanceBefore = ERC20(vault.asset()).balanceOf(address(this));
        vault.withdraw(
            vault.convertToShares(amount),
            address(this),
            address(this),
            maxLoss
        );
        uint balanceAfter = ERC20(vault.asset()).balanceOf(address(this));

        console.log("---");
        console.log("balance adapter");
        console.log(balanceBefore);
        console.log(balanceAfter);
        console.log("---");

        depositors[msg.sender] -= balanceAfter;
        ERC20(vault.asset()).transfer(msg.sender, balanceAfter);
        //Todo deal with withdrawl limit
        return balanceAfter;
    }
}
