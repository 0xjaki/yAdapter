// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "forge-std/console.sol";

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

    address public destinationBridge;
    IOriginBridge public bridge;
    uint public bridgedAssets;

    //TODO add getter and setter;
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

    /*//////////////////////////////////////////////////////////////
                Bridge related logic
    //////////////////////////////////////////////////////////////*/

    function calcWithdrawlAmount() public view returns (uint) {
        // Explain what this calculation is doing
        uint idleAssets = TokenizedStrategy.totalIdle();

        uint adjustedIdleAssets = ratio.mul(idleAssets).div(1000);

        require(bridgedAssets >= adjustedIdleAssets, "Underflow protection");
        uint netBridgedAssets = bridgedAssets.sub(adjustedIdleAssets);

        uint denominator = ratio.add(1000);
        require(denominator != 0, "Division by zero protection");

        uint withdrawalAmount = netBridgedAssets.mul(1000).div(denominator);

        return withdrawalAmount;
    }

    function calcDepositAmount() public view returns (uint) {
        uint idleAssets = TokenizedStrategy.totalIdle();
        uint depositAmount = idleAssets.mul(ratio).div(1000);
        return depositAmount;
    }

    //When the bridge has received the funds it calls the callback to transfer it back to the strat
    function onFundsReceivedCallback(
        address,
        uint,
        bytes calldata data
    ) external onlyBridge {
        bridgedAssets = abi.decode(data, (uint256));
    }

    //Keeper can tend to request additional funds
    function requestWithdrawl() external payable onlyKeepers {
        uint withDrawlAmount = calcWithdrawlAmount();
        bridge.withdraw{value: msg.value}(address(asset), withDrawlAmount);
    }

    /**
     * @dev Bridge funds to the destination chain
     * @param _amount The amount of 'asset' that should be bridged
     */
    function depositFunds(uint256 _amount) external payable onlyKeepers {
        require(destinationBridge != address(0), "adapter is zero");

        //swap part of the asset to cover fees
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
        //TODO subtract min costs of briding from totalAssets
        _totalAssets = asset.balanceOf(address(this)) + bridgedAssets;
    }

    function availableWithdrawLimit(
        address
    ) public view override returns (uint256) {
        //Only idle funds can be withdrawn
        return TokenizedStrategy.totalIdle();
    }
}
