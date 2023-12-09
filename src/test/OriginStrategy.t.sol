// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";
import "forge-std/console.sol";

contract OriginStrategy is Setup {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_deposit() public {
        require(originStrategy.bridgedAssets() == 0, "initial bridged assets are 0");
        uint256 _amount = 1000000;
        uint256 bridgeFees = 123;
        // Deposit into strategy
        mintAndDepositIntoStrategy(originStrategy, user, _amount);
        // TODO: Deposit everything to vault
        checkStrategyTotals(
            originStrategy,
            _amount,
            800000 + bridgeFees,
            200000 - bridgeFees
        );

        require(
            originStrategy.bridgedAssets() == 800000,
            "assets havent been bridged"
        );
    }

    function test_ape() public {
        require(originStrategy.bridgedAssets() == 0, "initial bridged assets are 0");
        uint256 _amount = 1000000;
        uint256 depositFees = 123;
        uint256 withdrawlFees = 456;

        uint balanceDestiny = 800000;
        uint balanceSource = 200000;
        // Deposit into strategy
        mintAndDepositIntoStrategy(originStrategy, user, _amount);
        // TODO: Deposit everything to vault
        checkStrategyTotals(
            originStrategy,
            _amount,
            balanceDestiny + depositFees,
            balanceSource - depositFees
        );

        require(originStrategy.staging() == 0, "staging is empty");

        uint expectedProfit = 100000;
        uint withdrawAmount = 20000;
        //L1 Strategy make profits and holds 900000 now
        //Keeper calcs that in order to maintain ratio 200000 has to be removed

        //Grant bridge allowance
        vm.prank(eoa);
        asset.transfer(address(originBridge), withdrawAmount);

        uint beforeHarvest = asset.balanceOf(address(originStrategy));
        vm.prank(keeper);
        originStrategy.preHarvest(withdrawAmount);

        require(
            originStrategy.staging() == withdrawAmount,
            "withdraw amount is staged"
        );

        uint leftInDestiny = balanceDestiny + expectedProfit - withdrawAmount;

        originBridge.triggerFundsReceivedCallback(
            address(asset),
            withdrawAmount,
            leftInDestiny
        );

        require(originStrategy.staging() == 0, "staking should be 0");
        uint afterHarvest = asset.balanceOf(address(originStrategy));

        //Dai that has been withdrawn has reached the strat
        assertEq(
            beforeHarvest + withdrawAmount - withdrawlFees,
            afterHarvest,
            "Dai has not been withdrawn"
        );

        vm.prank(keeper);
        (uint256 profit, uint256 loss) = originStrategy.report();

        uint totalAssetsExpected = leftInDestiny +
            balanceSource +
            withdrawAmount -
            depositFees -
            withdrawlFees;

        //Profit has been reported
        assertEq(
            expectedProfit - depositFees - withdrawlFees,
            profit,
            "false profit"
        );
        assertEq(
            originStrategy.totalAssets(),
            totalAssetsExpected,
            "false totalAsset"
        );
        assertEq(loss, 0, "loss");
    }
}
