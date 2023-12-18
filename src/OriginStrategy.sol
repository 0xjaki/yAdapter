// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IOriginBridge} from "./interfaces/bridge/IOriginBridge.sol";
import {IBridgeReceiver} from "./interfaces/bridge/IBridgeReceiver.sol";

contract OriginStrategy is BaseStrategy, IBridgeReceiver {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;
    using Math for uint256;

    constructor(
        address _asset,
        string memory _name,
        IOriginBridge _iBridge
    ) BaseStrategy(_asset, _name) {
        bridge = _iBridge;
    }

    //The destination bridge. Only used for reddem funds
    address public destinationBridge;
    //The origin bridge funds are send to
    IOriginBridge public bridge;
    //the amount of assets currently bridged
    uint public bridgedAssets;

    //the ration idle and bridged assets should maintain. Keeper should deposit/withdraw frequenly to maintain that ratio
    uint public ratio = 800;

    /**
     * @dev Modifier to make a function callable only when it is called by the bridge.
     */
    modifier onlyBridge() {
        require(msg.sender == address(bridge), "only bridge");
        _;
    }

    /**
     * @dev Sets the address of the destination adapter.
     * Can only be called by an account with the `onlyManagement` modifier.
     * @param _bridge The address of the new destination bridge.
     */
    function setDestinationBridge(address _bridge) external onlyManagement {
        require(_bridge != address(0), "adapter is zero address");
        destinationBridge = _bridge;
    }

    /**
     * @dev Sets the new ratio for maintaining idle and bridged assets.
     * Can only be called by an account with the `onlyManagement` modifier.
     * @param _newRatio The new ratio value.
     */
    function setRatio(uint _newRatio) external onlyManagement {
        ratio = _newRatio;
    }

    /*//////////////////////////////////////////////////////////////
                Bridge related logic
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Calculates the withdrawal amount based on the current ratio and asset balances.
     * @return The calculated withdrawal amount.
     */
    function calcWithdrawlAmount() public view returns (uint) {
        //First get idle assets
        uint idleAssets = TokenizedStrategy.totalIdle();
        //Adjust them so we can divide them later
        uint adjustedIdleAssets = ratio.mul(idleAssets).div(1000);
        //protect underflow
        require(bridgedAssets >= adjustedIdleAssets, "Underflow protection");
        //remove idle from bridged
        uint netBridgedAssets = bridgedAssets.sub(adjustedIdleAssets);
        //get demonitor we use to divide bridge assets
        uint denominator = ratio.add(1000);
        require(denominator != 0, "Division by zero protection");
        //Get the withdrawl amount by divide bridged asset / denominator
        return netBridgedAssets.mul(1000).div(denominator);
    }

    /**
     * @dev Calculates the deposit amount based on the current ratio and asset balances.
     * @return The calculated deposit amount.
     */
    function calcDepositAmount() public view returns (uint) {
        //First get idle assets
        uint idleAssets = TokenizedStrategy.totalIdle();
        //simply deposit 80% of idle assets
        return idleAssets.mul(ratio).div(1000);
    }

    /**
     * @dev Callback function to handle the receipt of funds from the bridge and update the bridged assets.
     * @param _asset The address of the token being transferred.
     * @param _amount The amount of tokens being transferred.
     * @param _callData Additional call data for the transfer operation.
     */
    function onFundsReceivedCallback(
        address _asset,
        uint _amount,
        bytes calldata _callData
    ) external onlyBridge {
        bridgedAssets = abi.decode(_callData, (uint256));
    }

    /**
     * @dev Requests a withdrawal of funds from the bridge.
     * @param _amount The amount of tokens to be withdrawn.
     */
    function requestWithdrawl(uint256 _amount) external payable onlyKeepers {
        bridge.withdraw{value: msg.value}(address(asset), _amount);
    }

    /**
     * @dev Bridge funds to the destination chain
     * @param _amount The amount of 'asset' that should be bridged
     */
    function depositFunds(uint256 _amount) external payable onlyKeepers {
        require(destinationBridge != address(0), "adapter is zero");
        //grant bridge the allowance to take asset from strat
        asset.increaseAllowance(address(bridge), _amount);
        //send fund to bridge
        //Keeper has to provide suffiecnt ETH via msg.sender to cover the relayer fee
        //The current rate can be requested offchain by using the SDK of the bridge
        bridge.deposit{value: msg.value}(
            destinationBridge,
            address(asset),
            _amount
        );
        //reset allowance
        asset.increaseAllowance(address(bridge), 0);
        //account bridge asssets
        bridgedAssets += _amount;
    }

    /*//////////////////////////////////////////////////////////////
                NEEDED TO BE OVERRIDDEN BY STRATEGIST
    //////////////////////////////////////////////////////////////*/

    function _deployFunds(uint256 _amount) internal override {
        //Funds become idle at first
        //Keeper has to bridge them to deploy them
    }

    ///Free funds is empty since funds can be only request from the keeper using the bridge
    function _freeFunds(uint256 _amount) internal override {
        //Do nothing
    }

    ///Total assets are simply idle + bridged
    function _harvestAndReport()
        internal
        view
        override
        returns (uint256 _totalAssets)
    {
        _totalAssets = asset.balanceOf(address(this)) + bridgedAssets;
    }

    function availableWithdrawLimit(
        address
    ) public view override returns (uint256) {
        //Only idle funds can be withdrawn
        return TokenizedStrategy.totalIdle();
    }
}
