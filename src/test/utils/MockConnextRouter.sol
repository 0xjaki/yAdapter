// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.0;

import {IXReceiver} from "src/interfaces/connext/IXReceiver.sol";
import {ConnextBase} from "src/bridge/connext/ConnextBase.sol";

import {ERC20} from "@tokenized-strategy/BaseStrategy.sol";

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

        ERC20(_asset).transferFrom(
            address(this),
            address(destinationBridge),
            toBridge
        );

        destinationBridge.xReceive(
            bytes32(0),
            toBridge,
            _asset,
            address(originBridge),
            TEST_ORIGIN_DOMAIN,
            abi.encodeWithSelector(WITHDRAW_SELECTOR)
        );
    }
}
