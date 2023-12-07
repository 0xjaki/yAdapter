pragma solidity ^0.8.0;

import "../../interfaces/IBridge.sol";
import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";

contract MockBridge is IBridge {
    address sender;
    address receiver;

    function setup(address _sender, address _receiver) public {
        sender = _sender;
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
        require(
            ERC20(token).transferFrom(receiver, sender, _amount),
            "Transfer failed"
        );
    }

    function getFee(
        address token,
        uint256 _amount
    ) external override returns (address, uint256) {
        // Mock implementation
        return (address(0), 123);
    }

    // Fallback function must be declared as external.
    fallback() external payable {
        // send / transfer (forwards 2300 gas to this fallback function)
        // call (forwards all of the gas)
    }

    receive() external payable {}
}
