// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

interface IWETH9 {
    function withdraw(uint wad) external;

    function balanceOf(address addr) external returns (uint);
}
