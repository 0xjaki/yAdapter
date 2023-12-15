// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IXReceiver} from "src/interfaces/connext/IXReceiver.sol";
import {IConnext} from "src/interfaces/connext/IConnext.sol";
import {IOriginBridge} from "src/interfaces/bridge/IOriginBridge.sol";
import {IDestinationAdapter} from "../../DestinationAdapter.sol";
import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";
import {ConnextBase} from "./ConnextBase.sol";

contract ConnextDestinationBridge is ConnextBase, IXReceiver {
    constructor(
        uint32 _originDomain,
        address _destinationAdapter,
        address _connext,
        address _admin
    ) {
        //The domain of the destination chain
        originDomain = _originDomain;

        destinationAdapter = IDestinationAdapter(_destinationAdapter);
        connext = IConnext(_connext);
        admin = _admin;
    }

    IConnext public connext;
    uint32 public originDomain;
    IDestinationAdapter public destinationAdapter;
    address public originBridge;
    address public admin;

    modifier onlySource(address _originSender, uint32 _origin) {
        require(
            _origin == originDomain &&
                _originSender == originBridge &&
                msg.sender == address(connext),
            "Expected original caller to be source contract on origin domain and this to be called by Connext"
        );
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }

    function setOriginBridge(address _originBridge) external onlyAdmin {
        originBridge = _originBridge;
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

        require(
            selector == DEPOST_SELECTOR || selector == WITHDRAW_SELECTOR,
            "invalid operation"
        );

        if (selector == DEPOST_SELECTOR) {
            depositFundsToAdapter(_asset, _amount);
        }
        if (selector == WITHDRAW_SELECTOR) {
            (address asset, uint amount) = abi.decode(
                _callData[4:],
                (address, uint)
            );
            withdrawFundsFromAdapter(asset, amount);
        }
    }

    function depositFundsToAdapter(address _asset, uint _amount) internal {
        require(
            ERC20(_asset).transfer(address(destinationAdapter), _amount),
            "Transfer failed"
        );

        destinationAdapter.onFundsReceivedCallback(
            _asset,
            _amount,
            new bytes(0)
        );
    }

    function withdrawFundsFromAdapter(address _asset, uint _amount) internal {
        //Funds have been already transfered to the Bride
        uint received = destinationAdapter.onFundsRequested(
            _asset,
            _amount,
            new bytes(0)
        );
        (, uint routerFee) = getConnextRouterFee(_asset, received);

        // This contract approves transfer to Connext
        ERC20(_asset).approve(address(connext), received);

        uint remainingBalance = ERC20(_asset).balanceOf(
            address(destinationAdapter)
        );

        connext.xcall{value: msg.value}(
            originDomain, // _destination: Domain ID of the destination chain
            originBridge, // _to: address receiving the funds on the destination
            _asset, // _asset: address of the token contract
            admin, // _delegate: address that can revert or forceLocal on destination
            received, // _amount: amount of tokens to transfer
            slippage, // _slippage: the maximum amount of slippage the user will accept in BPS (e.g. 30 = 0.3%)
            abi.encodeWithSelector(REDEEM_SELECTOR, remainingBalance) // _callData: encoded function call to deposit funds
        );
    }
}
