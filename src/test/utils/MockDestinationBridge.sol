// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import "../../interfaces/bridge/IDestinationBridge.sol";
import "../../interfaces/bridge/IBridgeReceiver.sol";
import "../../DestinationAdapter.sol";

import "forge-std/console.sol";
import {IWETH9} from "./../../interfaces/IWETH9.sol";

import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";
import {UniswapV2Swapper} from "lib/tokenized-strategy-periphery/src/swappers/UniswapV2Swapper.sol";

contract MockDestinationBridge is IDestinationBridge, UniswapV2Swapper {
    DestinationAdapter adapter;
    address receiver;

    function setup(address _sender, address _receiver) public {
        adapter = DestinationAdapter(_sender);
        receiver = _receiver;
    }

    //Called by connext to reddem funds from the adapter
    function redeem(
        address token,
        address _receiver,
        uint256 _amount
    ) external payable returns (uint256) {
        uint received = adapter.onFundsRequested(token, _amount, new bytes(0));

        //Get withdrawl fee
        (address feeToken, uint256 feeAmount) = getRedeemFee(
            address(token),
            _amount
        );
        //Swap to WETH
        swapForEthBridgeFee(token, feeAmount);

        uint toBeBridged = received - feeAmount;

        uint remainingBalance = ERC20(token).balanceOf(address(this));

        require(
            ERC20(token).transfer(_receiver, remainingBalance),
            "Transfeor failed"
        );

        return remainingBalance;
    }

    function getRedeemFee(
        address token,
        uint256 _amount
    ) public override returns (address, uint256) {
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
            ERC20(token).transfer(address(adapter), _amount),
            "Transfeor failed"
        );

        adapter.onFundsReceivedCallback(token, _amount, abi.encode(_left));
    }

    function swapForEthBridgeFee(address token, uint feeAmount) internal {
        router = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
        base = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

        IWETH9 weth = IWETH9(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
        //Swap assets to WETH
        _swapFrom(address(token), address(weth), feeAmount, feeAmount);
        require(weth.balanceOf(address(this)) >= feeAmount, "cant pay bridge");
        weth.withdraw(feeAmount);
    }

    // Fallback function must be declared as external.
    fallback() external payable {
        // send / transfer (forwards 2300 gas to this fallback function)
        // call (forwards all of the gas)
    }

    receive() external payable {}
}
