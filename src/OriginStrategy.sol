// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "forge-std/console.sol";

import {IOriginBridge} from "./interfaces/bridge/IOriginBridge.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {IBridgeReceiver} from "./interfaces/bridge/IBridgeReceiver.sol";

import {UniswapV2Swapper} from "lib/tokenized-strategy-periphery/src/swappers/UniswapV2Swapper.sol";

contract OriginStrategy is BaseStrategy, UniswapV2Swapper, IBridgeReceiver {
    using SafeERC20 for ERC20;

    constructor(
        address _asset,
        string memory _name,
        IOriginBridge _iBridge
    ) BaseStrategy(_asset, _name) {
        bridge = _iBridge;
        router = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
        base = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    }

    address l2Contract;
    IOriginBridge bridge;

    uint public bridgedAssets;

    /*//////////////////////////////////////////////////////////////
                NEEDED TO BE OVERRIDDEN BY STRATEGIST
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Should deploy up to '_amount' of 'asset' in the yield source.
     * @param _amount The amount of 'asset' that the strategy should attempt
     * to deposit in the yield source.
     */
    function _deployFunds(uint256 _amount) internal override {
        _bridgeFunds(_amount);
    }

    /**
     * @dev Bridge funds to the destination chain
     * @param _amount The amount of 'asset' that should be bridged
     */
    function _bridgeFunds(uint256 _amount) internal {
        (address feeToken, uint256 feeAmount) = bridge.getDepositFee(
            address(asset),
            _amount
        );

        //We want to keep 20 idle
        uint toBeBridged = (_amount * 800) / 1000;

        //Fee token is native ETH
        if (feeToken == address(0)) {
            //swap part of the asset to cover fees
            swapForEthBridgeFee(feeAmount);
            //grant bridge the allowance to take asset from strat
            asset.increaseAllowance(address(bridge), _amount);
            //send fund to bridge
            bridge.deposit{value: feeAmount}(
                l2Contract,
                address(asset),
                toBeBridged
            );
        } else {
            //TODO add ERC20 fee token
        }
        //account bridge asssets
        bridgedAssets += toBeBridged;
    }

    //Request funds from the bridge. The keeper knows how much to request to maintain 80/20 balance
    function preHarvest(uint _amount) external onlyKeepers {
        (address feeToken, uint256 feeAmount) = bridge.getWithdrawlFee(
            address(asset),
            _amount
        );

        if (feeToken == address(0)) {
            swapForEthBridgeFee(feeAmount);
            bridge.withdraw{value: feeAmount}(address(asset), _amount);
        } else {
            //TODO add ERC20 fee token
        }
    }

    //When the bridge has received the funds it calls the callback to transfer it back to the strat
    function onFundsReceivedCallback(
        address token,
        uint amount,
        bytes calldata data
    ) external {
        bridgedAssets = abi.decode(data, (uint256));
    }

    //Swap to ETH to get bridge fees
    function swapForEthBridgeFee(uint feeAmount) internal {
        IWETH9 weth = IWETH9(base);
        //Swap assets to WETH
        _swapFrom(address(asset), address(weth), feeAmount, feeAmount);
        require(weth.balanceOf(address(this)) >= feeAmount, "cant pay bridge");
        weth.withdraw(feeAmount);
    }

    //TODO should revert if its not WETH
    receive() external payable {}

    /**
     * @dev Will attempt to free the '_amount' of 'asset'.
     * @param _amount, The amount of 'asset' to be freed.
     */
    function _freeFunds(uint256 _amount) internal override onlyKeepers {
        //Withdraws funds from the bridge. This is more kind of request that not retrun funds immitidatly
        bridge.withdraw(address(this), _amount);
    }

    /**
     * @dev Internal function to harvest all rewards, redeploy any idle
     * funds and return an accurate accounting of all funds currently
     * held by the Strategy.
     *
     * This should do any needed harvesting, rewards selling, accrual,
     * redepositing etc. to get the most accurate view of current assets.
     *
     * NOTE: All applicable assets including loose assets should be
     * accounted for in this function.
     *
     * Care should be taken when relying on oracles or swap values rather
     * than actual amounts as all Strategy profit/loss accounting will
     * be done based on this returned value.
     *
     * This can still be called post a shutdown, a strategist can check
     * `TokenizedStrategy.isShutdown()` to decide if funds should be
     * redeployed or simply realize any profits/losses.
     *
     * @return _totalAssets A trusted and accurate account for the total
     * amount of 'asset' the strategy currently holds including idle funds.
     */
    function _harvestAndReport()
        internal
        override
        returns (uint256 _totalAssets)
    {
        //Todo maybe bridge has to do report for bridge asssets too
        _totalAssets = asset.balanceOf(address(this)) + bridgedAssets;
    }

    /*//////////////////////////////////////////////////////////////
                    OPTIONAL TO OVERRIDE BY STRATEGIST
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Optional function for strategist to override that can
     *  be called in between reports.
     *
     * If '_tend' is used tendTrigger() will also need to be overridden.
     *
     * This call can only be called by a permissioned role so may be
     * through protected relays.
     *
     * This can be used to harvest and compound rewards, deposit idle funds,
     * perform needed position maintenance or anything else that doesn't need
     * a full report for.
     *
     *   EX: A strategy that can not deposit funds without getting
     *       sandwiched can use the tend when a certain threshold
     *       of idle to totalAssets has been reached.
     *
     * The TokenizedStrategy contract will do all needed debt and idle updates
     * after this has finished and will have no effect on PPS of the strategy
     * till report() is called.
     *
     * @param _totalIdle The current amount of idle funds that are available to deploy.
     *
    function _tend(uint256 _totalIdle) internal override {}
    */

    /**
     * @dev Optional trigger to override if tend() will be used by the strategy.
     * This must be implemented if the strategy hopes to invoke _tend().
     *
     * @return . Should return true if tend() should be called by keeper or false if not.
     *
    function _tendTrigger() internal view override returns (bool) {}
    */

    /**
     * @notice Gets the max amount of `asset` that an address can deposit.
     * @dev Defaults to an unlimited amount for any address. But can
     * be overridden by strategists.
     *
     * This function will be called before any deposit or mints to enforce
     * any limits desired by the strategist. This can be used for either a
     * traditional deposit limit or for implementing a whitelist etc.
     *
     *   EX:
     *      if(isAllowed[_owner]) return super.availableDepositLimit(_owner);
     *
     * This does not need to take into account any conversion rates
     * from shares to assets. But should know that any non max uint256
     * amounts may be converted to shares. So it is recommended to keep
     * custom amounts low enough as not to cause overflow when multiplied
     * by `totalSupply`.
     *
     * @param . The address that is depositing into the strategy.
     * @return . The available amount the `_owner` can deposit in terms of `asset`
     *
    function availableDepositLimit(
        address _owner
    ) public view override returns (uint256) {
        TODO: If desired Implement deposit limit logic and any needed state variables .
        
        EX:    
            uint256 totalAssets = TokenizedStrategy.totalAssets();
            return totalAssets >= depositLimit ? 0 : depositLimit - totalAssets;
    }
    */

    /**
     * @notice Gets the max amount of `asset` that can be withdrawn.
     * @dev Defaults to an unlimited amount for any address. But can
     * be overridden by strategists.
     *
     * This function will be called before any withdraw or redeem to enforce
     * any limits desired by the strategist. This can be used for illiquid
     * or sandwichable strategies. It should never be lower than `totalIdle`.
     *
     *   EX:
     *       return TokenIzedStrategy.totalIdle();
     *
     * This does not need to take into account the `_owner`'s share balance
     * or conversion rates from shares to assets.
     *
     * @param . The address that is withdrawing from the strategy.
     * @return . The available amount that can be withdrawn in terms of `asset`
     *
    function availableWithdrawLimit(
        address _owner
    ) public view override returns (uint256) {
        TODO: If desired Implement withdraw limit logic and any needed state variables.
        
        EX:    
            return TokenizedStrategy.totalIdle();
    }
    */

    /**
     * @dev Optional function for a strategist to override that will
     * allow management to manually withdraw deployed funds from the
     * yield source if a strategy is shutdown.
     *
     * This should attempt to free `_amount`, noting that `_amount` may
     * be more than is currently deployed.
     *
     * NOTE: This will not realize any profits or losses. A separate
     * {report} will be needed in order to record any profit/loss. If
     * a report may need to be called after a shutdown it is important
     * to check if the strategy is shutdown during {_harvestAndReport}
     * so that it does not simply re-deploy all funds that had been freed.
     *
     * EX:
     *   if(freeAsset > 0 && !TokenizedStrategy.isShutdown()) {
     *       depositFunds...
     *    }
     *
     * @param _amount The amount of asset to attempt to free.
     *
    function _emergencyWithdraw(uint256 _amount) internal override {
        TODO: If desired implement simple logic to free deployed funds.

        EX:
            _amount = min(_amount, aToken.balanceOf(address(this)));
            _freeFunds(_amount);
    }

    */
}
