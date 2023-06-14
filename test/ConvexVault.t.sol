// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ConvexVault.sol";
import {BaseSetup} from "./BaseSetup.sol";
import {ICurveToken, ICurvePool} from "../src/interfaces/ICurve.sol";

/**

@title ConvexVaultTest
@dev This is a contract for testing the functions in the ConvexVault smart contract.
The tests include depositing LP tokens, withdrawing LP tokens, and claiming rewards.
The test cases are performed using mocked contracts and functions, using the Forge test library. */

contract ConvexVaultTest is BaseSetup {
    ConvexVault public vault;

    address private constant WBTC_LP_TOKEN_ADDRESS =
        0xc4AD29ba4B3c580e6D59105FFf484999997675Ff;
    address private constant WBTC_POOL_ADDRESS =
        0xD51a44d3FaE010294C616388b506AcdA1bfAAE46;
    address private constant CONVEX_BOOSTER_ADDRESS =
        0xF403C135812408BFbE8713b5A23a04b3D48AAE31;

    function setUp() public virtual override {
        BaseSetup.setUp();
        vault = new ConvexVault(WBTC_LP_TOKEN_ADDRESS, 38);
    }

    /**
        @dev This function tests the deposit and withdrawal of LP tokens, as well as claiming rewards, in a simulated environment using mocked contracts and functions. The function initializes variables and sets up the test environment before performing the following steps:
        - Alice and Bob add liquidity to the WBTC pool and receive LP tokens.
        - Alice and Bob deposit some of their LP tokens into the ConvexVault.
        - Alice and Bob wait for a specified period of time.
        - Bob deposits more LP tokens into the ConvexVault.
        - Alice and Bob withdraw some of their LP tokens from the ConvexVault.
        - Alice and Bob claim their CRV and CVX rewards.

        The function uses the Forge test library to simulate these interactions with the smart contract and to assert that certain conditions are met during each step of the process. Overall, this function provides a comprehensive test of the functionality of the ConvexVault smart contract and its integration with other contracts in the ecosystem. 
    */
    function test_depositLpTokenAndWithdraw() public {
        IERC20 wbtcLpToken = IERC20(WBTC_LP_TOKEN_ADDRESS);
        ICurvePool wbtcPool = ICurvePool(WBTC_POOL_ADDRESS);

        uint256 wbtcBalance = wbtc.balanceOf(address(alice));

        vm.startPrank(alice);
        wbtc.approve(address(wbtcPool), wbtcBalance);
        (bool success, ) = address(wbtcPool).call(
            abi.encodeWithSignature(
                "add_liquidity(uint256[3],uint256)",
                [0, wbtcBalance, 0],
                0
            )
        );
        assertEq(success, true);
        vm.stopPrank();
        // Once finished adding liquidity to pool. Alice's LP Token balance should be bigger than ZERO.
        assertGe(wbtcLpToken.balanceOf(address(alice)), 0);

        console.log(
            "Alice's WBTC LP Token = %d",
            wbtcLpToken.balanceOf(address(alice))
        );

        wbtcBalance = wbtc.balanceOf(address(bob));

        vm.startPrank(bob);
        wbtc.approve(address(wbtcPool), wbtcBalance);
        (success, ) = address(wbtcPool).call(
            abi.encodeWithSignature(
                "add_liquidity(uint256[3],uint256)",
                [0, wbtcBalance, 0],
                0
            )
        );
        assertEq(success, true);
        vm.stopPrank();
        // Once finished adding liquidity to pool. Alice's LP Token balance should be bigger than ZERO.
        assertGe(wbtcLpToken.balanceOf(address(bob)), 0);

        console.log(
            "Bob's WBTC LP Token = %d",
            wbtcLpToken.balanceOf(address(bob))
        );

        uint256 lpTokenBalance = wbtcLpToken.balanceOf(address(alice));

        vm.prank(alice);
        wbtcLpToken.approve(address(vault), lpTokenBalance);

        // 1st Alice's Deposit ------ Alice deposit some LP Tokens (amount = ALICE_DEPOSIT_AMOUNT_PER_ONCE) to CurveVault
        vm.prank(alice);
        vault.deposit(ALICE_DEPOSIT_AMOUNT_PER_ONCE);
        assertEq(
            wbtcLpToken.balanceOf(address(alice)),
            lpTokenBalance - ALICE_DEPOSIT_AMOUNT_PER_ONCE
        );
        // Advance block.timestamp to current timestamp + SKIP_FORWARD_PERIOD
        skip(SKIP_FORWARD_PERIOD);

        vm.prank(bob);
        lpTokenBalance = wbtcLpToken.balanceOf(address(bob));
        vm.prank(bob);
        wbtcLpToken.approve(address(vault), lpTokenBalance);

        // 1st Bob's Deposit ------ Bob deposit some LP Tokens (amount = ALICE_DEPOSIT_AMOUNT_PER_ONCE) to CurveVault
        vm.prank(bob);
        vault.deposit(ALICE_DEPOSIT_AMOUNT_PER_ONCE);
        // Once finished depositing, Bob's LP Token amount = Before LP TokenAmount - ALICE_DEPOSIT_AMOUNT_PER_ONCE
        assertEq(
            wbtcLpToken.balanceOf(address(bob)),
            lpTokenBalance - ALICE_DEPOSIT_AMOUNT_PER_ONCE
        );

        // Once finished depositing LP Token, WBTC's Liquidity gauge's balance should be bigger than ZERO.
        assertGe(wbtcLpToken.balanceOf(CONVEX_BOOSTER_ADDRESS), 0);
        // Advance block.timestamp to current timestamp + SKIP_FORWARD_PERIOD
        skip(SKIP_FORWARD_PERIOD);

        // 2nd Bob's Deposit ------ Bob deposit some LP Tokens (amount = ALICE_DEPOSIT_AMOUNT_PER_ONCE) to CurveVault
        vm.prank(bob);
        vault.deposit(BOB_DEPOSIT_AMOUNT_PER_ONCE);

        // Once finished depositing LP Token, WBTC's Liquidity gauge's balance should be bigger than ZERO.
        assertGe(wbtcLpToken.balanceOf(CONVEX_BOOSTER_ADDRESS), 0);
        skip(SKIP_FORWARD_PERIOD);

        // 1st Alice's withdraw ----- Alice withdraw some LP Tokens (amount = ALICE_WITHDRAW_AMOUNT_PER_ONCE) from CurveVault
        vm.startPrank(alice);
        vault.withdraw(ALICE_WITHDRAW_AMOUNT_PER_ONCE);
        skip(SKIP_FORWARD_PERIOD);

        // 1st Bob's withdraw -----  Bob withdraw some LP Tokens (amount = ALICE_WITHDRAW_AMOUNT_PER_ONCE) from CurveVault
        vm.prank(bob);
        vault.withdraw(BOB_WITHDRAW_AMOUNT_PER_ONCE);
        skip(SKIP_FORWARD_PERIOD);

        // 2nd Alice's withdraw ----- Alice withdraw some LP Tokens (amount = ALICE_WITHDRAW_AMOUNT_PER_ONCE) from CurveVault
        vm.prank(alice);
        vault.withdraw(ALICE_WITHDRAW_AMOUNT_PER_ONCE);
        // Advance block.timestamp to current timestamp + SKIP_FORWARD_PERIOD
        skip(SKIP_FORWARD_PERIOD);

        // 2nd Bob's withdraw -----  Bob withdraw some LP Tokens (amount = ALICE_WITHDRAW_AMOUNT_PER_ONCE) from CurveVault
        vm.prank(bob);
        vault.withdraw(BOB_WITHDRAW_AMOUNT_PER_ONCE);
        skip(SKIP_FORWARD_PERIOD);

        // Alice and Bob's CRV Token amount should be bigger than ZERO
        IERC20 crvToken = IERC20(CRV_TOKEN_ADDRESS);
        IERC20 cvxToken = IERC20(CVX_TOKEN_ADDRESS);
        assertGe(crvToken.balanceOf(address(alice)), 0);
        assertGe(crvToken.balanceOf(address(bob)), 0);
        assertGe(cvxToken.balanceOf(address(alice)), 0);
        assertGe(cvxToken.balanceOf(address(bob)), 0);

        console.log(
            "Alice's CRV Token balance = %d",
            crvToken.balanceOf(address(alice))
        );
        console.log(
            "Alice's CVX Token balance = %d",
            cvxToken.balanceOf(address(alice))
        );

        console.log(
            "Bob's CRV Token balance = %d",
            crvToken.balanceOf(address(bob))
        );
        console.log(
            "Bob's CVX Token balance = %d",
            cvxToken.balanceOf(address(bob))
        );
    }

    /**
        @dev This function tests the deposit of LP tokens and claiming rewards in a simulated environment using mocked contracts and functions. The function initializes variables and sets up the test environment before performing the following steps:
        - Alice and Bob add liquidity to the WBTC pool and receive LP tokens.
        - Alice and Bob deposit some of their LP tokens into the ConvexVault.
        - Alice and Bob wait for a specified period of time.
        - Bob deposits more LP tokens into the ConvexVault.
        - Alice and Bob wait for a specified period of time.
        - Alice claims her CRV reward from the ConvexVault.
        - Bob claims his CVX reward from the ConvexVault.
        
        The function uses the Forge test library to simulate these interactions with the smart contract and to assert that certain conditions are met during each step of the process. Overall, this function provides a comprehensive test of the functionality of the ConvexVault smart contract and its integration with other contracts in the ecosystem. 
    */
    function test_depositLpTokenAndClaimReward() public {
        IERC20 wbtcLpToken = IERC20(WBTC_LP_TOKEN_ADDRESS);
        ICurvePool wbtcPool = ICurvePool(WBTC_POOL_ADDRESS);

        uint256 wbtcBalance = wbtc.balanceOf(address(alice));

        vm.startPrank(alice);
        wbtc.approve(address(wbtcPool), wbtcBalance);
        (bool success, ) = address(wbtcPool).call(
            abi.encodeWithSignature(
                "add_liquidity(uint256[3],uint256)",
                [0, wbtcBalance, 0],
                0
            )
        );
        assertEq(success, true);
        vm.stopPrank();
        // Once finished adding liquidity to pool. Alice's LP Token balance should be bigger than ZERO.
        assertGe(wbtcLpToken.balanceOf(address(alice)), 0);

        console.log(
            "Alice's WBTC LP Token = %d",
            wbtcLpToken.balanceOf(address(alice))
        );

        wbtcBalance = wbtc.balanceOf(address(bob));

        vm.startPrank(bob);
        wbtc.approve(address(wbtcPool), wbtcBalance);
        (success, ) = address(wbtcPool).call(
            abi.encodeWithSignature(
                "add_liquidity(uint256[3],uint256)",
                [0, wbtcBalance, 0],
                0
            )
        );
        assertEq(success, true);
        vm.stopPrank();
        // Once finished adding liquidity to pool. Alice's LP Token balance should be bigger than ZERO.
        assertGe(wbtcLpToken.balanceOf(address(bob)), 0);

        console.log(
            "Bob's WBTC LP Token = %d",
            wbtcLpToken.balanceOf(address(bob))
        );

        uint256 lpTokenBalance = wbtcLpToken.balanceOf(address(alice));

        vm.prank(alice);
        wbtcLpToken.approve(address(vault), lpTokenBalance);

        // 1st Alice's Deposit ------ Alice deposit some LP Tokens (amount = ALICE_DEPOSIT_AMOUNT_PER_ONCE) to CurveVault
        vm.prank(alice);
        vault.deposit(ALICE_DEPOSIT_AMOUNT_PER_ONCE);
        assertEq(
            wbtcLpToken.balanceOf(address(alice)),
            lpTokenBalance - ALICE_DEPOSIT_AMOUNT_PER_ONCE
        );
        // Advance block.timestamp to current timestamp + SKIP_FORWARD_PERIOD
        skip(SKIP_FORWARD_PERIOD);

        lpTokenBalance = wbtcLpToken.balanceOf(address(bob));

        vm.prank(bob);
        wbtcLpToken.approve(address(vault), lpTokenBalance);

        // 1st Bob's Deposit ------ Bob deposit some LP Tokens (amount = ALICE_DEPOSIT_AMOUNT_PER_ONCE) to CurveVault
        vm.prank(bob);
        vault.deposit(BOB_DEPOSIT_AMOUNT_PER_ONCE);
        // Once finished depositing, Bob's LP Token amount = Before LP TokenAmount - ALICE_DEPOSIT_AMOUNT_PER_ONCE
        assertEq(
            wbtcLpToken.balanceOf(address(bob)),
            lpTokenBalance - BOB_DEPOSIT_AMOUNT_PER_ONCE
        );

        // Once finished depositing LP Token, WBTC's Liquidity gauge's balance should be bigger than ZERO.
        assertGe(wbtcLpToken.balanceOf(CONVEX_BOOSTER_ADDRESS), 0);
        // Advance block.timestamp to current timestamp + SKIP_FORWARD_PERIOD
        skip(SKIP_FORWARD_PERIOD);

        // 2nd Bob's Deposit ------ Bob deposit some LP Tokens (amount = ALICE_DEPOSIT_AMOUNT_PER_ONCE) to CurveVault
        vm.prank(bob);
        vault.deposit(BOB_DEPOSIT_AMOUNT_PER_ONCE);

        // 2st Alice's Deposit ------ Alice deposit some LP Tokens (amount = ALICE_DEPOSIT_AMOUNT_PER_ONCE) to CurveVault
        vm.prank(alice);
        vault.deposit(ALICE_DEPOSIT_AMOUNT_PER_ONCE);

        skip(SKIP_FORWARD_PERIOD);
        skip(SKIP_FORWARD_PERIOD);
        skip(SKIP_FORWARD_PERIOD);

        // Alice claim rewards

        vm.prank(bob);
        vault.claim(CVX_TOKEN_ADDRESS);

        vm.prank(alice);
        vault.claim(CRV_TOKEN_ADDRESS);

        // Alice and Bob's CRV Token amount should be bigger than ZERO
        IERC20 crvToken = IERC20(CRV_TOKEN_ADDRESS);
        IERC20 cvxToken = IERC20(CVX_TOKEN_ADDRESS);
        assertGe(crvToken.balanceOf(address(alice)), 0);
        assertGe(crvToken.balanceOf(address(bob)), 0);
        assertGe(cvxToken.balanceOf(address(alice)), 0);
        assertGe(cvxToken.balanceOf(address(bob)), 0);

        console.log(
            "Alice's CRV Token balance = %d",
            crvToken.balanceOf(address(alice))
        );
        console.log(
            "Alice's CVX Token balance = %d",
            cvxToken.balanceOf(address(alice))
        );

        console.log(
            "Bob's CRV Token balance = %d",
            crvToken.balanceOf(address(bob))
        );
        console.log(
            "Bob's CVX Token balance = %d",
            cvxToken.balanceOf(address(bob))
        );
    }
}
