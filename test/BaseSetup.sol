// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import {Utils} from "./utils/Util.sol";
import {IUniswapRouter} from "../src/interfaces/IUniswap.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BaseSetup is Test {
    Utils internal utils;
    address payable[] internal users;

    address internal alice;
    address internal bob;

    address public constant AAVE_LIQUIDITY_GAUGE_ADDRESS =
        0xd662908ADA2Ea1916B3318327A97eB18aD588b5d;
    address internal constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant UNISWAP_ROUTER_ADDRESS =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant DAI_ADDRESS =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address[] internal pathDAI;
    address[] internal pathUSDT;
    address[] internal pathUSDC;

    IWETH internal weth;
    IERC20 internal dai;
    IERC20 internal usdc;
    IERC20 internal usdt;
    IUniswapRouter public uniswapRouter;

    function setUp() public virtual {
        console.log("address = %s", address(this));
        utils = new Utils();
        users = utils.createUsers(5);

        alice = users[0];
        vm.label(alice, "Alice");
        bob = users[0];
        vm.label(bob, "Bob");

        vm.startPrank(alice);
        initPathForSwap();
        initBalanceForTesting();
    }

    function initPathForSwap() internal {
        weth = IWETH(WETH_ADDRESS);
        dai = IERC20(DAI_ADDRESS);
        usdc = IERC20(USDC_ADDRESS);
        usdt = IERC20(USDT_ADDRESS);

        pathDAI = new address[](2);
        pathDAI[0] = WETH_ADDRESS;
        pathDAI[1] = DAI_ADDRESS;

        pathUSDC = new address[](2);
        pathUSDC[0] = WETH_ADDRESS;
        pathUSDC[1] = USDC_ADDRESS;

        pathUSDT = new address[](2);
        pathUSDT[0] = WETH_ADDRESS;
        pathUSDT[1] = USDT_ADDRESS;
    }

    function initBalanceForTesting() internal {
        uint wethAmount = 10 * 1e18;

        weth.approve(address(uniswapRouter), wethAmount * 10);

        uniswapRouter = IUniswapRouter(UNISWAP_ROUTER_ADDRESS);

        uniswapRouter.swapExactETHForTokens{value: wethAmount}(
            0,
            pathDAI,
            address(alice),
            block.timestamp + 3600000
        );
        uniswapRouter.swapExactETHForTokens{value: wethAmount}(
            0,
            pathUSDC,
            address(alice),
            block.timestamp + 3600000
        );
        uniswapRouter.swapExactETHForTokens{value: wethAmount}(
            0,
            pathUSDT,
            address(alice),
            block.timestamp + 3600000
        );

        uniswapRouter.swapExactETHForTokens{value: wethAmount}(
            0,
            pathDAI,
            address(bob),
            block.timestamp + 3600000
        );
        uniswapRouter.swapExactETHForTokens{value: wethAmount}(
            0,
            pathUSDC,
            address(bob),
            block.timestamp + 3600000
        );
        uniswapRouter.swapExactETHForTokens{value: wethAmount}(
            0,
            pathUSDT,
            address(bob),
            block.timestamp + 3600000
        );

        console.log(
            "Alice's dai balance = %d",
            dai.balanceOf(0x9aF2E2B7e57c1CD7C68C5C3796d8ea67e0018dB7)
        );
        console.log(
            "Alice's usdc balance = %d",
            usdc.balanceOf(address(alice))
        );
        console.log(
            "Alice's usdt balance = %d",
            usdt.balanceOf(address(alice))
        );

        console.log("Bob's dai balance = %d", dai.balanceOf(address(bob)));
        console.log("Bob's usdc balance = %d", usdc.balanceOf(address(bob)));
        console.log("Bob's usdt balance = %d", usdt.balanceOf(address(bob)));
    }
}
