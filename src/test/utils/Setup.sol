// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import "forge-std/console.sol";
import {ExtendedTest} from "./ExtendedTest.sol";

import {OriginStrategy, ERC20} from "../../OriginStrategy.sol";
import {IStrategyInterface} from "../../interfaces/IStrategyInterface.sol";
import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";

// Inherit the events so they can be checked if desired.
import {IEvents} from "@tokenized-strategy/interfaces/IEvents.sol";

import {DestinationAdapter} from "../../DestinationAdapter.sol";

import {ConnextOriginBridge} from "src/bridge/connext/ConnextOriginBridge.sol";
import {ConnextDestinationBridge} from "src/bridge/connext/ConnextDestinationBridge.sol";
import {MockStrategy} from "./MockStrategy.sol";
import {IXReceiver} from "src/interfaces/connext/IXReceiver.sol";

import {MockConnextRouter} from "src/test/utils/MockConnextRouter.sol";

import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";


interface IFactory {
    function governance() external view returns (address);

    function set_protocol_fee_bps(uint16) external;

    function set_protocol_fee_recipient(address) external;
}

contract Setup is ExtendedTest, IEvents {
    // Contract instances that we will use repeatedly.
    ERC20 public asset;
    IStrategyInterface public originStrategy;
    DestinationAdapter public destinationAdapter;

    mapping(string => address) public tokenAddrs;

    // Addresses for different roles we will use repeatedly.
    address public user = address(10);
    address public keeper = address(4);
    address public management = address(1);
    address public performanceFeeRecipient = address(3);

    address public connextOperator = address(1234);

    MockConnextRouter connext;

    // Address of the real deployed Factory
    address public factory;

    ConnextOriginBridge originBridge;
    ConnextDestinationBridge destinationBridge;

    IStrategyInterface mockYieldSource;

    // Integer variables that will be used repeatedly.
    uint256 public decimals;
    uint256 public MAX_BPS = 10_000;

    // Fuzz from $0.01 of 1e6 stable coins up to 1 trillion of a 1e18 coin
    uint256 public maxFuzzAmount = 1e30;
    uint256 public minFuzzAmount = 10_000;

    // Default profit max unlock time is set for 10 days
    uint256 public profitMaxUnlockTime = 10 days;

    //Origin domain i.E Polygon Mainnet
    uint32 originDomain = 1;

    //Destination domain i.E Optimism Mainnet
    uint32 destinationDomain = 2;

    function setUp() public virtual {
        _setTokenAddrs();

        // Set asset
        asset = ERC20(tokenAddrs["DAI"]);

        // Set decimals
        decimals = asset.decimals();

        //Dummy start the destiantionSTrat deploys their capital too
        mockYieldSource = IStrategyInterface(setupMockStrategy());

        connext = new MockConnextRouter();

        destinationAdapter = new DestinationAdapter(
            ERC4626(address(mockYieldSource))
        );

        originBridge = new ConnextOriginBridge(
            destinationDomain,
            address(connext),
            keeper
        );
        destinationBridge = new ConnextDestinationBridge(
            originDomain,
            address(destinationAdapter),
            address(connext),
            keeper
        );
        originStrategy = IStrategyInterface(setupOriginStrategy());

        vm.prank(keeper);
        originBridge.setDestinationBridge(address(destinationBridge));
        
        vm.prank(keeper);
        originBridge.setOriginStrategy(address(originStrategy));

        vm.prank(keeper);
        destinationBridge.setOriginBridge(address(originBridge));

        connext.setup(
            IXReceiver(address(originBridge)),
            IXReceiver(address(destinationBridge)),
            address(originStrategy),
            address(destinationAdapter)
        );

        factory = originStrategy.FACTORY();

        // label all the used addresses for traces
        vm.label(keeper, "keeper");
        vm.label(factory, "factory");
        vm.label(connextOperator, "connext operator");
        vm.label(address(asset), "asset");
        vm.label(management, "management");
        vm.label(address(originStrategy), "originStrategy");
        vm.label(address(destinationAdapter), "destinationAdapter");
        vm.label(performanceFeeRecipient, "performanceFeeRecipient");
        vm.label(address(originBridge), "origin bridge");
        vm.label(address(destinationBridge), "destination bridge");
        vm.label(address(connext), "connext router");
    }

    function setupOriginStrategy() public returns (address) {
        // we save the sOriginStrategyas a IStrategyInterface to give it the needed interface

        IStrategyInterface _strategy = IStrategyInterface(
            address(
                new OriginStrategy(
                    address(asset),
                    "Origin Strategy",
                    originBridge
                )
            )
        );
        // set keeper
        _strategy.setKeeper(keeper);
        // set treasury
        _strategy.setPerformanceFeeRecipient(performanceFeeRecipient);
        // set management of the strategy
        _strategy.setPendingManagement(management);

        vm.prank(management);
        _strategy.acceptManagement();

        vm.prank(management);
        _strategy.setDestinationBridge(address(destinationBridge));

        return address(_strategy);
    }

    function setupMockStrategy() public returns (address) {
        IStrategyInterface _strategy = IStrategyInterface(
            address(new MockStrategy(address(asset), "MockStrategy"))
        );

        // set keeper
        _strategy.setKeeper(keeper);
        // set treasury
        _strategy.setPerformanceFeeRecipient(performanceFeeRecipient);
        // set management of the strategy
        _strategy.setPendingManagement(management);

        vm.prank(management);
        _strategy.acceptManagement();

        return address(_strategy);
    }

    function depositIntoStrategy(
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public {
        vm.prank(_user);
        asset.approve(address(_strategy), _amount);

        vm.prank(_user);
        _strategy.deposit(_amount, _user);
    }

    function mintAndDepositIntoStrategy(
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public {
        airdrop(asset, _user, _amount);
        depositIntoStrategy(_strategy, _user, _amount);
    }

    // For checking the amounts in the strategy
    function checkStrategyTotals(
        IStrategyInterface _strategy,
        uint256 _totalAssets,
        uint256 _totalDebt,
        uint256 _totalIdle
    ) public {
        assertEq(_strategy.totalAssets(), _totalAssets, "!totalAssets");
        assertEq(_strategy.totalDebt(), _totalDebt, "!totalDebt");
        assertEq(_strategy.totalIdle(), _totalIdle, "!totalIdle");
        assertEq(_totalAssets, _totalDebt + _totalIdle, "!Added");
    }

    function airdrop(ERC20 _asset, address _to, uint256 _amount) public {
        uint256 balanceBefore = _asset.balanceOf(_to);
        deal(address(_asset), _to, balanceBefore + _amount);
    }

    function setFees(
        IStrategyInterface target,
        uint16 _protocolFee,
        uint16 _performanceFee
    ) public {
        // address gov = IFactory(factory).governance();

        // Need to make sure there is a protocol fee recipient to set the fee.
        // vm.prank(gov);
        // IFactory(factory).set_protocol_fee_recipient(gov);

        // vm.prank(gov);
        // IFactory(factory).set_protocol_fee_bps(_protocolFee);

        vm.prank(management);
        target.setPerformanceFee(_performanceFee);
    }

    function _setTokenAddrs() internal {
        tokenAddrs["WBTC"] = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
        tokenAddrs["YFI"] = 0xDA537104D6A5edd53c6fBba9A898708E465260b6;
        tokenAddrs["WETH"] = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
        tokenAddrs["LINK"] = 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39;
        tokenAddrs["USDT"] = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
        tokenAddrs["DAI"] = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        tokenAddrs["USDC"] = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    }
}
