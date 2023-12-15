// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";
import "forge-std/console.sol";

contract OriginStrategy is Setup {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_deposit() public {
        require(
            originStrategy.bridgedAssets() == 0,
            "initial bridged assets are 0"
        );
        //To be deposited into strat
        uint256 _amount = 1000000;

        // Deposit into strategy
        mintAndDepositIntoStrategy(originStrategy, user, _amount);
        // TODO: Deposit everything to vault

        //TODO check how to test with totalAssets lacking bridge fees
        checkStrategyTotals(originStrategy, _amount, 0, _amount);

        require(originStrategy.bridgedAssets() == 0, "assets should be ide");

        //User can withdraw everything becaus it hasent been bridged yet
        require(
            originStrategy.maxWithdraw(user) == _amount,
            "wrong withdrawl limit"
        );
    }

    function test_ape() public {
        //To be deposited into strat
        uint256 _amount = 1000000;
        uint toBeBridged = 800000;

        //Since the ratio is 80/20 800000 should be bridged
        mintAndDepositIntoStrategy(originStrategy, user, _amount);

        uint depositAmount = originStrategy.calcDepositAmount();
        require(depositAmount == toBeBridged, "wrong deposit amount");
        vm.prank(keeper);

        originStrategy.depositFunds(depositAmount);

        assertEq(
            asset.balanceOf(address(connext)),
            toBeBridged,
            "conext has not received the funds"
        );

        connext.callDeposit(address(asset), toBeBridged);

        (, uint fee) = originBridge.getConnextRouterFee(
            address(asset),
            _amount
        );

        assertEq(
            mockYieldSource.convertToAssets(
                mockYieldSource.balanceOf(address(destinationAdapter))
            ),
            //100 -> rounding
            toBeBridged - fee + 100,
            "destination has not received the funds"
        );

        assertEq(
            mockYieldSource.convertToAssets(
                mockYieldSource.balanceOf(address(destinationAdapter))
            ),
            originStrategy.bridgedAssets() - fee + 100,
            "deposit assets mismatch"
        );

        checkStrategyTotals(
            originStrategy,
            _amount - toBeBridged,
            toBeBridged,
            _amount - toBeBridged
        );
    }

    // function test_a() public {
    //     require(
    //         originStrategy.bridgedAssets() == 0,
    //         "initial bridged assets are 0"
    //     );
    //     //To be deposited into strat
    //     uint256 _amount = 1000000;

    //     uint256 depositFees = 123;
    //     uint256 withdrawlFees = 456;
    //     uint256 redeemFees = 456;

    //     uint expectedBalanceDestiny = 800000;
    //     uint expectedBalanceOrigin = 200000;
    //     // Deposit into strategy
    //     mintAndDepositIntoStrategy(originStrategy, user, _amount);
    //     // TODO: Deposit everything to vault

    //     //TODO check how we could do this test
    //     /*   checkStrategyTotals(
    //         originStrategy,
    //         _amount,
    //         expectedBalanceDestiny + depositFees,
    //         expectedBalanceOrigin - depositFees
    //     ); */

    //     uint expectedProfit = 100000;

    //     //Funds have been dispatched to eoa that can now deal the funds to L2
    //     assertEq(
    //         ERC20(asset).balanceOf(connextOperator),
    //         expectedBalanceDestiny,
    //         "balance mismatch"
    //     );

    //     //This is an internal tx of the brdige to move the funds
    //     vm.prank(connextOperator);
    //     ERC20(asset).transfer(
    //         address(destinationBridge),
    //         expectedBalanceDestiny
    //     );
    //     //when funds have been moved successfully the bridge triggers funds received
    //     //Todo connext bridge
    //     /* destinationBridge.triggerFundsReceivedCallback(
    //         address(asset),
    //         expectedBalanceDestiny,
    //         0
    //     ); */

    //     assertEq(
    //         ERC20(address(mockYieldSource)).balanceOf(
    //             address(destinationAdapter)
    //         ),
    //         expectedBalanceDestiny,
    //         "yield source mismatch"
    //     );

    //     //Strat gains 10%
    //     uint preReportTotalAssets = mockYieldSource.totalAssets();
    //     uint preReportUserBalance = mockYieldSource.convertToAssets(
    //         mockYieldSource.balanceOf(address(destinationAdapter))
    //     );
    //     airdrop(asset, address(mockYieldSource), expectedProfit);

    //     vm.prank(keeper);
    //     mockYieldSource.report();
    //     skip(mockYieldSource.profitMaxUnlockTime());

    //     uint postReportTotalAssets = mockYieldSource.totalAssets();
    //     uint postReportUserBalance = mockYieldSource.convertToAssets(
    //         mockYieldSource.balanceOf(address(destinationAdapter))
    //     );

    //     assertGt(
    //         postReportTotalAssets,
    //         preReportTotalAssets,
    //         "total assets missmatch"
    //     );

    //     assertGt(
    //         postReportUserBalance,
    //         preReportUserBalance,
    //         "user balance missmatch"
    //     );

    //     assertEq(
    //         ERC20(address(mockYieldSource)).balanceOf(
    //             address(destinationAdapter)
    //         ),
    //         expectedBalanceDestiny,
    //         "yield source mismatch"
    //     );

    //     //L1 Strategy make profits and holds 888888 now

    //     uint balanceDestiny = postReportUserBalance;
    //     uint balanceSource = asset.balanceOf(address(originStrategy));

    //     //Keeper calc how much has to bee maintained to maintain the balance
    //     uint256 withdrawAmount = balanceDestiny -
    //         ((balanceDestiny + balanceSource) * 80) /
    //         100;

    //     //pre harvest start the bridge process to
    //     uint beforeHarvest = asset.balanceOf(address(originStrategy));
    //     vm.prank(keeper);
    //     originStrategy.preHarvest(withdrawAmount);

    //     //Grant bridge allowance
    //     vm.prank(connextOperator);
    //     //DestinationBrdige withdraws funds from adapter and send them to eoa
    //     //Todo connext bridge
    //     /*     uint bridged = destinationBridge.redeem(
    //         address(asset),
    //         connextOperator,
    //         withdrawAmount
    //     ); */
    //     uint bridged;

    //     vm.prank(connextOperator);
    //     //origin bridge receives funds that has been birdged all fees already subtracted
    //     asset.transfer(address(originBridge), bridged);

    //     uint leftInDestiny = mockYieldSource.convertToAssets(
    //         mockYieldSource.balanceOf(address(destinationAdapter))
    //     );
    //     //Origin receives requested funds
    //     vm.prank(connextOperator);
    //     //Todo connext bridge
    //     /*      originBridge.triggerFundsReceivedCallback(
    //         address(asset),
    //         bridged,
    //         leftInDestiny
    //     ); */

    //     //require(originStrategy.staging() == 0, "staking should be 0");
    //     uint afterHarvest = asset.balanceOf(address(originStrategy));

    //     //Dai that has been withdrawn has reached the strat
    //     assertGt(afterHarvest, beforeHarvest, "Dai has not been withdrawn");

    //     vm.prank(keeper);
    //     (uint256 profit, uint256 loss) = originStrategy.report();

    //     //Profit has been reported
    //     assertGt(
    //         profit,
    //         //ExpectedProfit- depositFee-withdrawlFee-redeemFee-protocolFee-performanceFee = ~13%
    //         85000,
    //         "false profit"
    //     );
    // }
}
