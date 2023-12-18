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

    function test_deposit_to_bridge() public {
        //To be deposited into strat
        uint256 _amount = 1000000;
        uint toBeBridged = 800000;

        //Since the ratio is 80/20 800000 should be bridged
        mintAndDepositIntoStrategy(originStrategy, user, _amount);

        uint depositAmount = originStrategy.calcDepositAmount();
        require(depositAmount == toBeBridged, "wrong deposit amount");
        vm.prank(keeper);
        originStrategy.depositFunds(toBeBridged);

        vm.prank(keeper);
        originStrategy.tend();
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
            _amount,
            toBeBridged,
            _amount - toBeBridged
        );
    }

    function test_withdraw_from_bridge() public {
        //To be deposited into strat
        uint256 _amount = 1000000;
        uint deposited = 800000;

        //10% of the depositet funds
        uint256 yield = 80000;

        //Since the ratio is 80/20 800000 should be bridged
        mintAndDepositIntoStrategy(originStrategy, user, _amount);

        uint depositAmount = originStrategy.calcDepositAmount();
        vm.prank(keeper);
        originStrategy.depositFunds(depositAmount);

        vm.prank(keeper);
        originStrategy.tend();

        //Connext internally bridges the assets
        connext.callDeposit(address(asset), deposited);

        //Destination Strategy earns yield
        airdrop(asset, address(mockYieldSource), yield);
        //keeper of the destination strategy has to report the yield so it can be withdrawn by the depositors
        vm.prank(keeper);
        mockYieldSource.report();
        //skip the unlock time
        skip(mockYieldSource.profitMaxUnlockTime());

        uint beforeWithdrawl = ERC20(asset).balanceOf(address(originStrategy));

        //Keeper request that balance to even out the 80/20 balance
        uint256 toWithdraw = 20000;
        vm.prank(keeper);
        originStrategy.requestWithdrawl(toWithdraw);

        //Connext internally bridges the assets
        connext.callWithdraw(address(asset), toWithdraw);

        vm.prank(keeper);
        originStrategy.tend();

        vm.prank(keeper);
        originStrategy.report();

        uint afterWithdrawl = ERC20(asset).balanceOf(address(originStrategy));

        assertGt(afterWithdrawl, beforeWithdrawl, "no yield");
    }
}
