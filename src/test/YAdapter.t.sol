import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";
import "forge-std/console.sol";

contract Adapter is Setup {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_ape() public {
        require(strategy.bridgedAssets() == 0, "initial bridged assets are 0");
        uint256 _amount = 1000000;
        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        // TODO: Deposit everything to vault
        checkStrategyTotals(strategy, _amount, _amount, 0);

        require(strategy.bridgedAssets() > 0, "assets havent been bridged");

        // Earn Interest
        skip(1 days);
    }
}
