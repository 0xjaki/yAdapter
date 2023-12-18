// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IXReceiver} from "src/interfaces/connext/IXReceiver.sol";
import {IConnext} from "src/interfaces/connext/IConnext.sol";
import {IOriginBridge} from "src/interfaces/bridge/IOriginBridge.sol";
import {IDestinationAdapter} from "src/DestinationAdapter.sol";
import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";
import {ConnextBase} from "./ConnextBase.sol";

/**
 * @title ConnextDestinationBridge Contract
 * @dev This contract facilitates the bridging of assets from the Connext protocol to a destination chain.
 */
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

    //Connext router
    IConnext public connext;
    //Domain of the origin the bridge receives funds from
    uint32 public originDomain;
    //Origin bridge the bridge receives funds from
    address public originBridge;
    //Destination the bridge sends funds too
    IDestinationAdapter public destinationAdapter;
    //Admin can change the origin bridge and eventually manage trasnfers offchain at connext
    address public admin;

    /**
     * @dev Modifier to restrict function access to calls originating from the Connext protocol on the specified origin domain.
     * @param _originSender The address of the original sender from the origin domain.
     * @param _origin The domain ID of the origin chain.
     */
    modifier onlySource(address _originSender, uint32 _origin) {
        require(
            _origin == originDomain &&
                _originSender == originBridge &&
                msg.sender == address(connext),
            "Expected original caller to be source contract on origin domain and this to be called by Connext"
        );
        _;
    }

    /**
     * @dev Modifier to restrict function access to the contract admin.
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }

    /**
     * @notice Sets the address of the origin bridge contract.
     * @param _originBridge The address of the origin bridge contract.
     */
    function setOriginBridge(address _originBridge) external onlyAdmin {
        originBridge = _originBridge;
    }

    /**
     * @notice Handles the receipt of assets from the Connext protocol and processes the transfer based on the provided call data.
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
        //When calling the bridge the Origin Strategy has to add a function seelctor to the calldata so the bridge know the
        //Intention of the strategy
        bytes4 selector = bytes4(_callData);

        //Only Deposit and Withdraw is supported
        require(
            selector == DEPOST_SELECTOR || selector == WITHDRAW_SELECTOR,
            "invalid operation"
        );

        //We're sending funds to the adapter
        if (selector == DEPOST_SELECTOR) {
            depositFundsToAdapter(_asset, _amount);
        }
        if (selector == WITHDRAW_SELECTOR) {
            //Withdraw selector contains asset and amount as args
            (address asset, uint amount) = abi.decode(
                _callData[4:],
                (address, uint)
            );
            //Request funds from adapter
            withdrawFundsFromAdapter(asset, amount);
        }
    }

    /**
     * @dev Transfers the specified amount of tokens to the destination adapter and triggers the onFundsReceivedCallback.
     * @param _asset The address of the token to be transferred.
     * @param _amount The amount of tokens to be transferred.
     */
    function depositFundsToAdapter(address _asset, uint _amount) internal {
        //Transfer funds to destination Adapter
        require(
            ERC20(_asset).transfer(address(destinationAdapter), _amount),
            "Transfer failed"
        );
        //invoke callback at the destination adapter
        destinationAdapter.onFundsReceivedCallback(
            _asset,
            _amount,
            new bytes(0)
        );
    }

    /**
     * @dev Initiates the withdrawal of funds from the destination adapter and triggers the transfer to the Connext protocol.
     * @param _asset The address of the token to be withdrawn.
     * @param _amount The amount of tokens to be withdrawn.
     */
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
        //Submit the remaining balance of the destination adapter so the origin strategy can account them
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
