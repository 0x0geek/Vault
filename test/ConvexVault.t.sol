// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ConvexVault.sol";

contract ConvexVaultTest is Test {
    ConvexVault public vault;

    address private constant WBTC_LP_TOKEN_ADDRESS =
        0xc4AD29ba4B3c580e6D59105FFf484999997675Ff;
    address private constant CONVEX_BOOSTER_ADDRESS =
        0xF403C135812408BFbE8713b5A23a04b3D48AAE31;

    function setUp() public {
        vault = new ConvexVault(
            WBTC_LP_TOKEN_ADDRESS,
            CONVEX_BOOSTER_ADDRESS,
            38
        );
    }
}
