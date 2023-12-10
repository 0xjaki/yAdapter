// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import "../../interfaces/bridge/IOriginBridge.sol";
import "../../interfaces/bridge/IBridgeReceiver.sol";

import "forge-std/console.sol";

import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";

contract MockOriginBridge is IOriginBridge {
    IBridgeReceiver sender;
    address receiver;

    function setup(address _sender, address _receiver) public {
        sender = IBridgeReceiver(_sender);
        receiver = _receiver;
    }

    function deposit(
        address _receiver,
        address token,
        uint256 _amount
    ) external payable override {
        require(
            ERC20(token).transferFrom(msg.sender, receiver, _amount),
            "Transfer failed"
        );
    }

    function withdraw(address token, uint256 _amount) external payable {
        //Trigger Bridge
    }

    function getDepositFee(
        address token,
        uint256 _amount
    ) external override returns (address, uint256) {
        // Mock implementation
        return (address(0), 123);
    }

    function getWithdrawlFee(
        address token,
        uint256 _amount
    ) external override returns (address, uint256) {
        // Mock implementation
        return (address(0), 456);
    }

    //Connext xreceive
    function triggerFundsReceivedCallback(
        address token,
        uint256 _amount,
        uint256 _left
    ) external {
        require(
            ERC20(token).transfer(address(sender), _amount),
            "Transfeor failed"
        );
        sender.onFundsReceivedCallback(token, _amount, _left);
    }

    // Fallback function must be declared as external.
    fallback() external payable {
        // send / transfer (forwards 2300 gas to this fallback function)
        // call (forwards all of the gas)
    }

    receive() external payable {}
}
