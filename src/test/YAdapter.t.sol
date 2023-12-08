import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";
import "forge-std/console.sol";

contract Adapter is Setup {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_deposit() public {
        require(strategy.bridgedAssets() == 0, "initial bridged assets are 0");
        uint256 _amount = 1000000;
        uint256 bridgeFees = 123;
        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);
        // TODO: Deposit everything to vault
        checkStrategyTotals(
            strategy,
            _amount,
            800000 + bridgeFees,
            200000 - bridgeFees
        );

        require(
            strategy.bridgedAssets() == 800000,
            "assets havent been bridged"
        );
    }

    function test_ape() public {
        require(strategy.bridgedAssets() == 0, "initial bridged assets are 0");
        uint256 _amount = 1000000;
        uint256 depositFees = 123;
        uint256 withdrawlFees = 456;

        uint balanceDestiny = 800000;
        uint balanceSource = 200000;
        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);
        // TODO: Deposit everything to vault
        checkStrategyTotals(
            strategy,
            _amount,
            balanceDestiny + depositFees,
            balanceSource - depositFees
        );

        require(strategy.staging() == 0, "staging is empty");

        uint expectedProfit = 100000;
        uint withdrawAmount = 20000;
        //L1 Strategy make profits and holds 900000 now
        //Keeper calcs that in order to maintain ratio 200000 has to be removed

        //Grant bridge allowance
        vm.prank(receiver);
        asset.increaseAllowance(address(mockBridge), withdrawAmount);
        console.log(strategy.pricePerShare());

        uint beforeHarvest = asset.balanceOf(address(strategy));
        vm.prank(keeper);
        strategy.preHarvest(withdrawAmount);

        require(
            strategy.staging() == withdrawAmount,
            "withdraw amount is staged"
        );

        uint leftInDestiny = balanceDestiny + expectedProfit - withdrawAmount;

        mockBridge.triggerFundsReceivedCallback(
            address(asset),
            withdrawAmount,
            leftInDestiny
        );

        require(strategy.staging() == 0, "staking should be 0");
        uint afterHarvest = asset.balanceOf(address(strategy));

        //Dai that has been withdrawn has reached the strat
        assertEq(
            beforeHarvest + withdrawAmount - withdrawlFees,
            afterHarvest,
            "Dai has not been withdrawn"
        );

        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

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
            strategy.totalAssets(),
            totalAssetsExpected,
            "false totalAsset"
        );
        assertEq(loss, 0, "loss");
    }
}
