// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICurveMinter {
    function mint_for(address, address) external;

    function mint(address) external;
}

interface ICurveToken {
    function approve(address, uint256) external returns (bool);

    function balanceOf(address) external returns (uint256);

    function transfer(address, uint256) external returns (bool);

    function transferFrom(address, address, uint256) external returns (bool);
}

interface ICurvePool {
    function add_liquidity(
        uint256[3] memory,
        uint256,
        bool
    ) external returns (uint256);

    function add_liquidity(
        uint256[3] memory,
        uint256
    ) external returns (uint256);

    function lp_token() external returns (address);
}

interface ILiquidityGauge {
    function deposit(uint256) external;

    function withdraw(uint256) external;

    function balanceOf(address account) external view returns (uint256);

    function claimable_tokens(address) external returns (uint256);

    function claimable_reward(address) external returns (uint256);

    function claim_rewards(address) external;

    function integrate_fraction(
        address _account
    ) external view returns (uint256);
}
