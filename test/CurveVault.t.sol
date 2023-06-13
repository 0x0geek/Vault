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

    address internal constant CRV_TOKEN_ADDRESS =
        0xD533a949740bb3306d119CC777fa900bA034cd52;

    function setUp() public virtual override {
        BaseSetup.setUp();
        vault = new CurveVault(
            AAVE_POOL_LP_TOKEN_ADDRESS,
            AAVE_LIQUIDITY_GAUGE_ADDRESS
        );

        // uniswapRouter.swapExactETHForTokens(0, pathDAI, )
    }

    function test_depositLPTokenAndGetRewards() public {
        IERC20 aaveLpToken = IERC20(AAVE_POOL_LP_TOKEN_ADDRESS);
        ICurvePool aavePool = ICurvePool(AAVE_POOL_ADDRESS);

        dai.approve(address(aavePool), dai.balanceOf(address(alice)));
        usdt.approve(address(aavePool), usdt.balanceOf(address(alice)));
        usdc.approve(address(aavePool), usdt.balanceOf(address(alice)));

        dai.approve(address(aavePool), dai.balanceOf(address(bob)));
        usdt.approve(address(aavePool), usdt.balanceOf(address(bob)));
        usdc.approve(address(aavePool), usdt.balanceOf(address(bob)));

        uint256[3] memory aAmounts = [
            uint256(300000000),
            uint256(6000000),
            uint256(5000000)
        ];

        uint256[3] memory bAmounts = [
            uint256(400000000),
            uint256(7000000),
            uint256(4000000)
        ];

        uint256 mint_amount = aavePool.add_liquidity(aAmounts, 0, true);
        assertGe(mint_amount, 0);

        mint_amount = aavePool.add_liquidity(bAmounts, 0, true);
        assertGe(mint_amount, 0);

        console.log(
            "Alice's LP Token balance = %d",
            aaveLpToken.balanceOf(address(alice))
        );

        console.log(
            "BOB's LP Token balance = %d",
            aaveLpToken.balanceOf(address(bob))
        );

        console.log(block.number);

        aaveLpToken.approve(
            address(vault),
            aaveLpToken.balanceOf(address(alice))
        );
        vault.deposit(aaveLpToken.balanceOf(address(alice)));

        assertEq(aaveLpToken.balanceOf(address(alice)), 0);

        aaveLpToken.approve(
            address(vault),
            aaveLpToken.balanceOf(address(bob))
        );
        vault.deposit(aaveLpToken.balanceOf(address(bob)));

        assertEq(aaveLpToken.balanceOf(address(bob)), 0);

        vm.roll(block.number + 10000);
        console.log(block.number);

        vault.withdraw(30000);
        assertEq(aaveLpToken.balanceOf(address(alice)), 30000);

        vault.withdraw(30000);
        assertEq(aaveLpToken.balanceOf(address(bob)), 30000);

        IERC20 crvToken = IERC20(CRV_TOKEN_ADDRESS);
        assertEq(crvToken.balanceOf(address(alice)), 0);
        assertEq(crvToken.balanceOf(address(bob)), 0);

        console.log(
            "Alice's CRV token balance = %d",
            crvToken.balanceOf(address(alice))
        );
        console.log(
            "Bob's CRV token balance= %d",
            crvToken.balanceOf(address(bob))
        );

        console.log(
            "Alice's LP token balance= %d",
            aaveLpToken.balanceOf(address(alice))
        );
        console.log(
            "Bob's LP token balance= %d",
            aaveLpToken.balanceOf(address(bob))
        );

        console.log(block.number);
    }
}
