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

    function test_withdraw_origin() public {
        require(
            originStrategy.bridgedAssets() == 0,
            "initial bridged assets are 0"
        );
        uint256 _amount = 1000000;
        uint256 depositFees = 123;
        uint256 withdrawlFees = 456;
        uint256 reddemFee = 456;

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

    function test_ape() public {
        require(
            originStrategy.bridgedAssets() == 0,
            "initial bridged assets are 0"
        );
        //To be deposited into strat
        uint256 _amount = 1000000;

        uint256 depositFees = 123;
        uint256 withdrawlFees = 456;
        uint256 redeemFees = 456;

        uint expectedBalanceDestiny = 800000;
        uint expectedBalanceOrigin = 200000;
        // Deposit into strategy
        mintAndDepositIntoStrategy(originStrategy, user, _amount);
        // TODO: Deposit everything to vault
        checkStrategyTotals(
            originStrategy,
            _amount,
            expectedBalanceDestiny + depositFees,
            expectedBalanceOrigin - depositFees
        );

        uint expectedProfit = 100000;

        //Funds have been dispatched to eoa that can now deal the funds to L2
        assertEq(
            ERC20(asset).balanceOf(eoa),
            expectedBalanceDestiny,
            "balance mismatch"
        );

        //This is an internal tx of the brdige to move the funds
        vm.prank(eoa);
        ERC20(asset).transfer(
            address(destinationBridge),
            expectedBalanceDestiny
        );
        //when funds have been moved successfully the bridge triggers funds received
        destinationBridge.triggerFundsReceivedCallback(
            address(asset),
            expectedBalanceDestiny,
            0
        );

        assertEq(
            ERC20(address(mockYieldSource)).balanceOf(
                address(destinationAdapter)
            ),
            expectedBalanceDestiny,
            "yield source mismatch"
        );

        //Strat gains 10%

        uint preReportTotalAssets = mockYieldSource.totalAssets();
        uint preReportUserBalance = mockYieldSource.convertToAssets(
            mockYieldSource.balanceOf(address(destinationAdapter))
        );
        airdrop(asset, address(mockYieldSource), expectedProfit);

        vm.prank(keeper);
        mockYieldSource.report();
        skip(mockYieldSource.profitMaxUnlockTime());

        uint postReportTotalAssets = mockYieldSource.totalAssets();
        uint postReportUserBalance = mockYieldSource.convertToAssets(
            mockYieldSource.balanceOf(address(destinationAdapter))
        );

        assertGt(
            postReportTotalAssets,
            preReportTotalAssets,
            "total assets missmatch"
        );

        assertGt(
            postReportUserBalance,
            preReportUserBalance,
            "user balance missmatch"
        );

        assertEq(
            ERC20(address(mockYieldSource)).balanceOf(
                address(destinationAdapter)
            ),
            expectedBalanceDestiny,
            "yield source mismatch"
        );

        //L1 Strategy make profits and holds 888888 now

        uint balanceDestiny = postReportUserBalance;
        uint balanceSource = asset.balanceOf(address(originStrategy));

        //Keeper calc how much has to bee maintained to maintain the balance
        uint256 withdrawAmount = balanceDestiny -
            ((balanceDestiny + balanceSource) * 80) /
            100;

        //pre harvest start the bridge process to
        uint beforeHarvest = asset.balanceOf(address(originStrategy));
        vm.prank(keeper);
        originStrategy.preHarvest(withdrawAmount);

    
        //Grant bridge allowance
        vm.prank(eoa);
        //DestinationBrdige withdraws funds from adapter and send them to eoa
        uint bridged = destinationBridge.redeem(
            address(asset),
            eoa,
            withdrawAmount
        );

        vm.prank(eoa);
        //origin bridge receives funds that has been birdged all fees already subtracted
        asset.transfer(address(originBridge), bridged);

        uint leftInDestiny = mockYieldSource.convertToAssets(
            mockYieldSource.balanceOf(address(destinationAdapter))
        );
        //Origin receives requested funds
        vm.prank(eoa);
        originBridge.triggerFundsReceivedCallback(
            address(asset),
            bridged,
            leftInDestiny
        );

        //require(originStrategy.staging() == 0, "staking should be 0");
        uint afterHarvest = asset.balanceOf(address(originStrategy));

        //Dai that has been withdrawn has reached the strat
        assertGt(afterHarvest, beforeHarvest, "Dai has not been withdrawn");

        vm.prank(keeper);
        (uint256 profit, uint256 loss) = originStrategy.report();

        console.log(profit);
        console.log(loss);

        //Profit has been reported
        assertEq(
            //ExpectedProfit- depositFee-withdrawlFee-redeemFee-protocolFee-performanceFee = ~13%
            86066,
            profit,
            "false profit"
        );
    }
}
