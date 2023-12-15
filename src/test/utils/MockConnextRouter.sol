// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.0;

import {IXReceiver} from "src/interfaces/connext/IXReceiver.sol";
import {ConnextBase} from "src/bridge/connext/ConnextBase.sol";
import {ERC20} from "@tokenized-strategy/BaseStrategy.sol";

import "forge-std/console.sol";

contract MockConnextRouter is ConnextBase {
    IXReceiver public originBridge;
    IXReceiver public destinationBridge;

    address public originStrategy;
    address public destinationAdapter;

    uint32 public constant TEST_ORIGIN_DOMAIN = 1;
    uint32 public constant TEST_DESTINATION_DOMAIN = 2;

    function setup(
        IXReceiver _originBridge,
        IXReceiver _destinationBridge,
        address _originStrategy,
        address _destinationAdapter
    ) external {
        originBridge = _originBridge;
        destinationBridge = _destinationBridge;
        originStrategy = _originStrategy;
        destinationAdapter = _destinationAdapter;
    }

    function xcall(
        uint32 _destination,
        address _to,
        address _asset,
        address _delegate,
        uint256 _amount,
        uint256 _slippage,
        bytes calldata _callData
    ) external payable returns (bytes32) {
        ERC20(_asset).transferFrom(msg.sender, address(this), _amount);
    }

    //Can be called with in the test suite to mock a reddem bridge call
    function callReddem(
        address _asset,
        uint _amount,
        uint remainingBalance
    ) public {
        ERC20(_asset).transferFrom(
            address(this),
            address(originBridge),
            _amount
        );

        originBridge.xReceive(
            bytes32(0),
            _amount,
            _asset,
            address(destinationBridge),
            TEST_DESTINATION_DOMAIN,
            abi.encodeWithSelector(REDEEM_SELECTOR, remainingBalance)
        );
    }

    //Can be called with in the test suite to mock a withdraw bridge call
    function callWithdraw(address _asset, uint _amount) public {
        destinationBridge.xReceive(
            bytes32(0),
            0,
            address(0),
            address(originBridge),
            TEST_ORIGIN_DOMAIN,
            abi.encodeWithSelector(WITHDRAW_SELECTOR, _asset, _amount)
        );
    }

    //Can be called with in the test suite to mock a deposit bridge call
    function callDeposit(address _asset, uint _amount) public {
        (, uint fee) = getConnextRouterFee(_asset, _amount);
        uint toBridge = _amount - fee;

        console.log(ERC20(_asset).balanceOf(address(this)));
        console.log(toBridge);

        ERC20(_asset).transfer(address(destinationBridge), toBridge);

        destinationBridge.xReceive(
            bytes32(0),
            toBridge,
            _asset,
            address(originBridge),
            TEST_ORIGIN_DOMAIN,
            abi.encodeWithSelector(DEPOST_SELECTOR)
        );
    }
}
