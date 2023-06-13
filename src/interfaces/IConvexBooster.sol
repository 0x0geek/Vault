// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//main Convex contract(booster.sol) basic interface
interface IConvexBooster {
    //deposit into convex, receive a tokenized deposit.  parameter to stake immediately
    function deposit(
        uint256 _pid,
        uint256 _amount,
        bool _stake
    ) external returns (bool);

    //burn a tokenized deposit to receive curve lp tokens back
    function withdraw(uint256 _pid, uint256 _amount) external returns (bool);

    function withdrawAll(uint256 _pid) external returns (bool);

    function poolLength() external view returns (uint256);

    function stakerRewards() external view returns (address);

    function poolInfo(
        uint256 _pid
    )
        external
        view
        returns (
            address _lptoken,
            address _token,
            address _gauge,
            address _crvRewards,
            address _stash,
            bool _shutdown
        );

    function earmarkRewards(uint256 _pid) external returns (bool);
}
