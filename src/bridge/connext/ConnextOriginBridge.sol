// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IXReceiver} from "src/interfaces/connext/IXReceiver.sol";
import {IConnext} from "src/interfaces/connext/IConnext.sol";
import {IOriginBridge} from "src/interfaces/bridge/IOriginBridge.sol";
import {IBridgeReceiver} from "src/interfaces/bridge/IBridgeReceiver.sol";

import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";
import {ConnextBase} from "./ConnextBase.sol";

contract ConnextOriginBridge is ConnextBase, IXReceiver, IOriginBridge {
    constructor(
        uint32 _destinationDomain,
        address _originStrategy,
        address _destinationAdapter,
        address _connext,
        address _bridgeManager
    ) {
        //The domain of the destination chain
        destinationDomain = _destinationDomain;
        originStrategy = _originStrategy;
        destinationAdapter = _destinationAdapter;
        connext = IConnext(_connext);
        bridgeManager = _bridgeManager;
    }

    IConnext public connext;
    uint32 public destinationDomain;
    address public destinationAdapter;
    address public bridgeManager;
    address public originStrategy;

    modifier onlySource(address _originSender, uint32 _origin) {
        require(
            _origin == destinationDomain &&
                _originSender == destinationAdapter &&
                msg.sender == address(connext),
            "Expected original caller to be source contract on origin domain and this to be called by Connext"
        );
        _;
    }

    function getDepositFee(
        address _token,
        uint256 _amount
    ) external pure returns (address, uint256) {
        return getConnextRouterFee(_token, _amount);
    }

    function getWithdrawlFee(
        address _token,
        uint256 _amount
    ) external pure returns (address, uint256) {
        return getConnextRouterFee(_token, _amount);
    }

    function deposit(
        address receiver,
        address token,
        uint256 _amount
    ) external payable {
        ERC20 _token = ERC20(token);
        uint slippage = 30;

        require(receiver == destinationAdapter, "destination mismatch");

        require(
            _token.allowance(msg.sender, address(this)) >= _amount,
            "strategy must approve amount"
        );

        // User sends funds to this contract
        _token.transferFrom(msg.sender, address(this), _amount);

        // This contract approves transfer to Connext
        _token.approve(address(connext), _amount);

        connext.xcall{value: msg.value}(
            destinationDomain, // _destination: Domain ID of the destination chain
            destinationAdapter, // _to: address receiving the funds on the destination
            token, // _asset: address of the token contract
            bridgeManager, // _delegate: address that can revert or forceLocal on destination
            _amount, // _amount: amount of tokens to transfer
            slippage, // _slippage: the maximum amount of slippage the user will accept in BPS (e.g. 30 = 0.3%)
            abi.encodeWithSelector(DEPOST_SELECTOR) // _callData: encoded function call to deposit funds
        );
    }

    function withdraw(address token, uint256 _amount) external payable {
        connext.xcall{value: msg.value}(
            destinationDomain, // _destination: Domain ID of the destination chain
            destinationAdapter, // _to: address receiving the funds on the destination
            address(0), // _asset: address of the token contract
            bridgeManager, // _delegate: address that can revert or forceLocal on destination
            0, // _amount: amount of tokens to transfer
            0, // _slippage: the maximum amount of slippage the user will accept in BPS (e.g. 30 = 0.3%)
            abi.encodeWithSelector(WITHDRAW_SELECTOR, token, _amount) // _callData: encoded function call to withdraw funds
        );
    }

    function xReceive(
        bytes32 _transferId,
        uint256 _amount,
        address _asset,
        address _originSender,
        uint32 _origin,
        bytes calldata _callData
    ) external onlySource(_originSender, _origin) returns (bytes memory) {
        bytes4 selector = bytes4(_callData);
        require(selector == REDEEM_SELECTOR, "invalid operation");

        require(
            ERC20(_asset).transfer(address(this), _amount),
            "Transfer failed"
        );

        uint leftAtOrigin = abi.decode(_callData[4:], (uint));

        IBridgeReceiver(originStrategy).onFundsReceivedCallback(
            _asset,
            _amount,
            abi.encode(leftAtOrigin)
        );
    }
}
