// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IXReceiver} from "src/interfaces/connext/IXReceiver.sol";
import {IConnext} from "src/interfaces/connext/IConnext.sol";
import {IOriginBridge} from "src/interfaces/bridge/IOriginBridge.sol";
import {IBridgeReceiver} from "src/interfaces/bridge/IBridgeReceiver.sol";

import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";
import {ConnextBase} from "./ConnextBase.sol";
import "forge-std/console.sol";

/**
 * @title ConnextOriginBridge
 * @dev Contract for bridging assets from the origin chain to the Connext protocol.
 */
contract ConnextOriginBridge is ConnextBase, IXReceiver, IOriginBridge {
    constructor(uint32 _destinationDomain, address _connext, address _admin) {
        //The domain of the destination chain
        destinationDomain = _destinationDomain;

        connext = IConnext(_connext);
        admin = _admin;
    }

    //Connect Router
    IConnext public connext;
    //Domain the bridge sends funds to
    uint32 public destinationDomain;
    //Destination bridge funds are sent to
    address public destinationBridge;
    //Origin strategy the bridge receives funds from
    address public originStrategy;
    //Admin change origin strategy and destinationBridge
    address public admin;

    modifier onlySource(address _originSender, uint32 _origin) {
        require(
            _origin == destinationDomain &&
                _originSender == destinationBridge &&
                msg.sender == address(connext),
            "Expected original caller to be source contract on origin domain and this to be called by Connext"
        );
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }

    /**
     * @dev Sets the address of the destination bridge contract.
     * @param _destinationBridge The address of the destination bridge contract.
     */
    function setDestinationBridge(
        address _destinationBridge
    ) external onlyAdmin {
        destinationBridge = _destinationBridge;
    }

    /**
     * @dev Sets the address of the origin strategy contract.
     * @param _originStrategy The address of the origin strategy contract.
     */
    function setOriginStrategy(address _originStrategy) external onlyAdmin {
        originStrategy = _originStrategy;
    }

    /**
     * @dev Retrieves the deposit fee for a given token and amount.
     * @param _token The address of the token.
     * @param _amount The amount of tokens to be deposited.
     * @return The address and amount of the deposit fee.
     */
    function getDepositFee(
        address _token,
        uint256 _amount
    ) external pure returns (address, uint256) {
        return getConnextRouterFee(_token, _amount);
    }

    /**
     * @dev Retrieves the withdrawal fee for a given token and amount.
     * @param _token The address of the token.
     * @param _amount The amount of tokens to be withdrawn.
     * @return The address and amount of the withdrawal fee.
     */
    function getWithdrawlFee(
        address _token,
        uint256 _amount
    ) external pure returns (address, uint256) {
        return getConnextRouterFee(_token, _amount);
    }

    /**
     * @dev Initiates the deposit of tokens to the Connext protocol.
     * @param receiver The address of the receiver on the destination chain.
     * @param token The address of the token to be deposited.
     * @param _amount The amount of tokens to be deposited.
     */
    function deposit(
        address receiver,
        address token,
        uint256 _amount
    ) external payable {
        ERC20 _token = ERC20(token);
        //max acceptable slippage. Maybe make it a state var so it can be adjusted by management
        uint slippage = 30;

        //Funds can only be depostet to the destination bridge
        require(receiver == destinationBridge, "destination mismatch");

        //Before calling the bridge the strategy has to give allowance
        require(
            _token.allowance(msg.sender, address(this)) >= _amount,
            "strategy must approve amount"
        );

        //sends funds from strategy to origin bridge, so connext can transfer them later
        _token.transferFrom(msg.sender, address(this), _amount);

        // approve ammount to connext
        _token.approve(address(connext), _amount);

        connext.xcall{value: msg.value}(
            destinationDomain, // _destination: Domain ID of the destination chain
            destinationBridge, // _to: address receiving the funds on the destination
            token, // _asset: address of the token contract
            admin, // _delegate: address that can revert or forceLocal on destination
            _amount, // _amount: amount of tokens to transfer
            slippage, // _slippage: the maximum amount of slippage the user will accept in BPS (e.g. 30 = 0.3%)
            abi.encodeWithSelector(DEPOST_SELECTOR) // _callData: encoded function call to deposit funds
        );
    }

    function withdraw(address token, uint256 _amount) external payable {
        connext.xcall{value: msg.value}(
            destinationDomain, // _destination: Domain ID of the destination chain
            destinationBridge, // _to: address receiving the funds on the destination
            address(0), // _asset: address of the token contract
            admin, // _delegate: address that can revert or forceLocal on destination
            0, // _amount: amount of tokens to transfer
            0, // _slippage: the maximum amount of slippage the user will accept in BPS (e.g. 30 = 0.3%)
            abi.encodeWithSelector(WITHDRAW_SELECTOR, token, _amount) // _callData: encoded function call to withdraw funds
        );
    }

    /**
     * @dev Handles the receipt of assets from the Connext protocol and processes the transfer based on the provided call data.
     * @param _transferId The unique identifier of the transfer.
     * @param _amount The amount of tokens being transferred.
     * @param _asset The address of the token being transferred.
     * @param _originSender The address of the original sender from the origin domain.
     * @param _origin The domain ID of the origin chain.
     * @param _callData The encoded call data specifying the transfer operation.
     * @return The result of the transfer operation.
     */
    function xReceive(
        bytes32 _transferId,
        uint256 _amount,
        address _asset,
        address _originSender,
        uint32 _origin,
        bytes calldata _callData
    ) external onlySource(_originSender, _origin) returns (bytes memory) {
        //When the withdrawl was processes the destination bridge calls redeem to send the funds back to origin
        bytes4 selector = bytes4(_callData);
        require(selector == REDEEM_SELECTOR, "invalid operation");

        //send funds to strat
        require(
            ERC20(_asset).transfer(originStrategy, _amount),
            "Transfer failed"
        );

        //destination bridges provides whats left at the destination via callback
        uint leftAtOrigin = abi.decode(_callData[4:], (uint));
        
        //use the callback to let the strat know that funds have been received
        IBridgeReceiver(originStrategy).onFundsReceivedCallback(
            _asset,
            _amount,
            abi.encode(leftAtOrigin)
        );
    }
}
