// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

abstract contract ConnextBase {
    bytes4 internal constant DEPOST_SELECTOR = bytes4(keccak256("deposit()"));

    bytes4 internal constant WITHDRAW_SELECTOR =
        bytes4(keccak256("withdraw(address,uint256)"));

    bytes4 internal constant REDEEM_SELECTOR =
        bytes4(keccak256("redeem(uint256)"));

    //TODO add getter and setter to adjust slippage
    uint public slippage = 30;

    function getConnextRouterFee(
        address token,
        uint256 _amount
    ) internal pure virtual returns (address, uint) {
        //See https://docs.connext.network/developers/guides/estimating-fees
        //Connext charges 0.05% of the transfered amount
        uint relayerFee = (_amount * 5) / 10000;
        return (token, relayerFee);
    }
}
