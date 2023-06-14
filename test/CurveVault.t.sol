// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/CurveVault.sol";
import {BaseSetup} from "./BaseSetup.sol";
import {ICurveToken, ICurvePool} from "../src/interfaces/ICurve.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CurveVaultTest is BaseSetup {
    CurveVault public vault;

    address internal constant AAVE_POOL_LP_TOKEN_ADDRESS =
        0xFd2a8fA60Abd58Efe3EeE34dd494cD491dC14900;
    address internal constant AAVE_POOL_ADDRESS =
        0xDeBF20617708857ebe4F679508E7b7863a8A8EeE;
    address public constant AAVE_LIQUIDITY_GAUGE_ADDRESS =
        0xd662908ADA2Ea1916B3318327A97eB18aD588b5d;

    function setUp() public virtual override {
        BaseSetup.setUp();

        vault = new CurveVault(
            AAVE_POOL_LP_TOKEN_ADDRESS,
            AAVE_LIQUIDITY_GAUGE_ADDRESS
        );
    }

    function test_depositLpTokenAndWithdraw() public {
        IERC20 aaveLpToken = IERC20(AAVE_POOL_LP_TOKEN_ADDRESS);
        ICurvePool aavePool = ICurvePool(AAVE_POOL_ADDRESS);

        uint256 daiBalance = dai.balanceOf(address(alice));
        uint256 usdcBalance = usdc.balanceOf(address(alice));
        uint256 usdtBalance = usdt.balanceOf(address(alice));

        vm.startPrank(alice);
        dai.approve(address(aavePool), daiBalance);
        usdt.approve(address(aavePool), usdtBalance);
        usdc.approve(address(aavePool), usdcBalance);

        uint256 mint_amount = aavePool.add_liquidity(
            [daiBalance, usdcBalance, 0],
            100,
            true
        );

        vm.stopPrank();

        // The minted amount should be always bigger than 100
        assertGe(mint_amount, 100);
        // Once finished adding liquidity to pool. Alice's LP Token balance should be bigger than ZERO.
        assertGe(aaveLpToken.balanceOf(address(alice)), 0);

        daiBalance = dai.balanceOf(address(bob));
        usdcBalance = usdc.balanceOf(address(bob));
        usdtBalance = usdt.balanceOf(address(bob));

        vm.startPrank(bob);
        dai.approve(address(aavePool), daiBalance);
        usdt.approve(address(aavePool), usdtBalance);
        usdc.approve(address(aavePool), usdcBalance);

        mint_amount = aavePool.add_liquidity(
            [daiBalance, usdcBalance, 0],
            0,
            true
        );
        vm.stopPrank();

        // The minted amount should be always bigger than 100
        assertGe(mint_amount, 100);
        // Once finished adding liquidity to pool. Alice's LP Token balance should be bigger than ZERO.
        assertGe(aaveLpToken.balanceOf(address(bob)), 0);

        uint256 lpTokenBalance = aaveLpToken.balanceOf(address(alice));

        vm.prank(alice);
        aaveLpToken.approve(address(vault), lpTokenBalance);

        // 1st Alice's Deposit ------ Alice deposit some LP Tokens (amount = ALICE_DEPOSIT_AMOUNT_PER_ONCE) to CurveVault
        vm.prank(alice);
        vault.deposit(ALICE_DEPOSIT_AMOUNT_PER_ONCE);
        assertEq(
            aaveLpToken.balanceOf(address(alice)),
            lpTokenBalance - ALICE_DEPOSIT_AMOUNT_PER_ONCE
        );
        // Advance block.timestamp to current timestamp + SKIP_FORWARD_PERIOD
        skip(SKIP_FORWARD_PERIOD);

        vm.prank(bob);
        lpTokenBalance = aaveLpToken.balanceOf(address(bob));
        vm.prank(bob);
        aaveLpToken.approve(address(vault), lpTokenBalance);

        // 1st Bob's Deposit ------ Bob deposit some LP Tokens (amount = ALICE_DEPOSIT_AMOUNT_PER_ONCE) to CurveVault
        vm.prank(bob);
        vault.deposit(ALICE_DEPOSIT_AMOUNT_PER_ONCE);
        // Once finished depositing, Bob's LP Token amount = Before LP TokenAmount - ALICE_DEPOSIT_AMOUNT_PER_ONCE
        assertEq(
            aaveLpToken.balanceOf(address(bob)),
            lpTokenBalance - ALICE_DEPOSIT_AMOUNT_PER_ONCE
        );

        // Once finished depositing LP Token, Aave's Liquidity gauge's balance should be bigger than ZERO.
        assertGe(aaveLpToken.balanceOf(AAVE_LIQUIDITY_GAUGE_ADDRESS), 0);
        // Advance block.timestamp to current timestamp + SKIP_FORWARD_PERIOD
        skip(SKIP_FORWARD_PERIOD);

        // 2nd Bob's Deposit ------ Bob deposit some LP Tokens (amount = ALICE_DEPOSIT_AMOUNT_PER_ONCE) to CurveVault
        vm.prank(bob);
        vault.deposit(BOB_DEPOSIT_AMOUNT_PER_ONCE);

        // Once finished depositing LP Token, Aave's Liquidity gauge's balance should be bigger than ZERO.
        assertGe(aaveLpToken.balanceOf(AAVE_LIQUIDITY_GAUGE_ADDRESS), 0);
        skip(SKIP_FORWARD_PERIOD);

        IERC20 crvToken = IERC20(CRV_TOKEN_ADDRESS);

        vm.prank(alice);
        vault.harvestRewards();

        vm.prank(bob);
        vault.harvestRewards();

        assertGe(crvToken.balanceOf(address(alice)), 0);
        assertGe(crvToken.balanceOf(address(bob)), 0);

        console.log(
            "Alice's CRV Token balance = %d",
            crvToken.balanceOf(address(alice))
        );

        console.log(
            "Bob's CRV Token balance = %d",
            crvToken.balanceOf(address(bob))
        );
    }

    function test_depositLpTokenAndHarvestCrvReward() public {
        IERC20 aaveLpToken = IERC20(AAVE_POOL_LP_TOKEN_ADDRESS);
        ICurvePool aavePool = ICurvePool(AAVE_POOL_ADDRESS);

        uint256 daiBalance = dai.balanceOf(address(alice));
        uint256 usdcBalance = usdc.balanceOf(address(alice));
        uint256 usdtBalance = usdt.balanceOf(address(alice));

        vm.startPrank(alice);
        dai.approve(address(aavePool), daiBalance);
        usdt.approve(address(aavePool), usdtBalance);
        usdc.approve(address(aavePool), usdcBalance);

        uint256 mint_amount = aavePool.add_liquidity(
            [daiBalance, usdcBalance, 0],
            100,
            true
        );

        vm.stopPrank();

        // The minted amount should be always bigger than 100
        assertGe(mint_amount, 100);
        // Once finished adding liquidity to pool. Alice's LP Token balance should be bigger than ZERO.
        assertGe(aaveLpToken.balanceOf(address(alice)), 0);

        daiBalance = dai.balanceOf(address(bob));
        usdcBalance = usdc.balanceOf(address(bob));
        usdtBalance = usdt.balanceOf(address(bob));

        vm.startPrank(bob);
        dai.approve(address(aavePool), daiBalance);
        usdt.approve(address(aavePool), usdtBalance);
        usdc.approve(address(aavePool), usdcBalance);

        mint_amount = aavePool.add_liquidity(
            [daiBalance, usdcBalance, 0],
            0,
            true
        );
        vm.stopPrank();

        // The minted amount should be always bigger than 100
        assertGe(mint_amount, 100);
        // Once finished adding liquidity to pool. Alice's LP Token balance should be bigger than ZERO.
        assertGe(aaveLpToken.balanceOf(address(bob)), 0);

        uint256 lpTokenBalance = aaveLpToken.balanceOf(address(alice));

        vm.prank(alice);
        aaveLpToken.approve(address(vault), lpTokenBalance);

        // 1st Alice's Deposit ------ Alice deposit some LP Tokens (amount = ALICE_DEPOSIT_AMOUNT_PER_ONCE) to CurveVault
        vm.prank(alice);
        vault.deposit(ALICE_DEPOSIT_AMOUNT_PER_ONCE);
        assertEq(
            aaveLpToken.balanceOf(address(alice)),
            lpTokenBalance - ALICE_DEPOSIT_AMOUNT_PER_ONCE
        );
        // Advance block.timestamp to current timestamp + SKIP_FORWARD_PERIOD
        skip(SKIP_FORWARD_PERIOD);

        vm.prank(bob);
        lpTokenBalance = aaveLpToken.balanceOf(address(bob));
        vm.prank(bob);
        aaveLpToken.approve(address(vault), lpTokenBalance);

        // 1st Bob's Deposit ------ Bob deposit some LP Tokens (amount = ALICE_DEPOSIT_AMOUNT_PER_ONCE) to CurveVault
        vm.prank(bob);
        vault.deposit(ALICE_DEPOSIT_AMOUNT_PER_ONCE);
        // Once finished depositing, Bob's LP Token amount = Before LP TokenAmount - ALICE_DEPOSIT_AMOUNT_PER_ONCE
        assertEq(
            aaveLpToken.balanceOf(address(bob)),
            lpTokenBalance - ALICE_DEPOSIT_AMOUNT_PER_ONCE
        );

        // Once finished depositing LP Token, Aave's Liquidity gauge's balance should be bigger than ZERO.
        assertGe(aaveLpToken.balanceOf(AAVE_LIQUIDITY_GAUGE_ADDRESS), 0);
        // Advance block.timestamp to current timestamp + SKIP_FORWARD_PERIOD
        skip(SKIP_FORWARD_PERIOD);

        // 2nd Bob's Deposit ------ Bob deposit some LP Tokens (amount = ALICE_DEPOSIT_AMOUNT_PER_ONCE) to CurveVault
        vm.prank(bob);
        vault.deposit(BOB_DEPOSIT_AMOUNT_PER_ONCE);

        // Once finished depositing LP Token, Aave's Liquidity gauge's balance should be bigger than ZERO.
        assertGe(aaveLpToken.balanceOf(AAVE_LIQUIDITY_GAUGE_ADDRESS), 0);
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
        assertGe(crvToken.balanceOf(address(alice)), 0);
        assertGe(crvToken.balanceOf(address(bob)), 0);

        console.log(
            "Alice's CRV Token balance = %d",
            crvToken.balanceOf(address(alice))
        );

        console.log(
            "Bob's CRV Token balance = %d",
            crvToken.balanceOf(address(bob))
        );
    }
}
