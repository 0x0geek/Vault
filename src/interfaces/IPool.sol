// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPool {
    function addPool(
        address _lptoken,
        address _gauge,
        uint256 _stashVersion
    ) external returns (bool);

    function forceAddPool(
        address _lptoken,
        address _gauge,
        uint256 _stashVersion
    ) external returns (bool);

    function shutdownPool(uint256 _pid) external returns (bool);

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

    function poolLength() external view returns (uint256);

    function gaugeMap(address) external view returns (bool);

    function setPoolManager(address _poolM) external;
}
