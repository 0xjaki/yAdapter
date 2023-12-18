// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;
import {IBridgeReceiver} from "./interfaces/bridge/IBridgeReceiver.sol";
import {IBridgeSender} from "./interfaces/bridge/IBridgeSender.sol";
import {IDestinationBridge} from "./interfaces/bridge/IDestinationBridge.sol";
import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";
import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";
import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

interface IDestinationAdapter is IBridgeReceiver, IBridgeSender {}

contract DestinationAdapter is IDestinationAdapter {
    //The vault the adapter deposits its funds to
    ERC4626 public vault;

    //Destination adapter can be used by more than one adapter. That might be usefull to have different Origin strategies from
    //several chains depositing to the same destination
    mapping(address => uint256) depositors;

    constructor(ERC4626 _vault) {
        vault = _vault;
    }

    /**
     * @dev Callback function to handle the receipt of funds from the bridge and update the bridged assets.
     * @param _asset The address of the token being transferred.
     * @param _amount The amount of tokens being transferred.
     */
    function onFundsReceivedCallback(
        address _asset,
        uint _amount,
        bytes calldata
    ) external override {
        //Grant vault allowance
        ERC20(_asset).increaseAllowance(address(vault), _amount);
        //deposit asset to vault
        uint deposited = vault.deposit(_amount, address(this));
        //Add to deposited balance
        uint depositedAsset = vault.convertToAssets(deposited);
        depositors[msg.sender] += depositedAsset;
    }

    function onFundsRequested(
        address,
        uint amount,
        bytes calldata
    ) external returns (uint) {
        //Reverts if more funds are requested than previously deposited
        uint withdrawlAmount = depositors[msg.sender] - amount;
        //Withdraw from vault
        vault.withdraw(withdrawlAmount, address(this), address(this));

        uint balanceAfter = ERC20(vault.asset()).balanceOf(address(this));
        //set remaining balance
        depositors[msg.sender] -= withdrawlAmount;

        //send assets to bridge
        ERC20(vault.asset()).transfer(msg.sender, balanceAfter);
        //Todo deal with withdrawl limit
        return balanceAfter;
    }
}
