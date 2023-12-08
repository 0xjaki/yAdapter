pragma solidity ^0.8.0;

import "../../interfaces/IBridge.sol";
import "../../interfaces/IBridgeReceiver.sol";

import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";

contract MockBridge is IBridge {
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

    function withdraw(address token, uint256 _amount) external {
        //Trigger Bridge
    }

    function getFee(
        address token,
        uint256 _amount
    ) external override returns (address, uint256) {
        // Mock implementation
        return (address(0), 123);
    }

    //Connext xreceive
    function triggerFundsReceivedCallback(
        address token,
        uint256 _amount
    ) external {
        require(
            ERC20(token).transferFrom(receiver, address(sender), _amount),
            "Transfeor failed"
        );
        sender.onFundsReceivedCallback(token, _amount);
    }

    // Fallback function must be declared as external.
    fallback() external payable {
        // send / transfer (forwards 2300 gas to this fallback function)
        // call (forwards all of the gas)
    }

    receive() external payable {}
}
