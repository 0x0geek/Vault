// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IConvexBooster.sol";
import "./interfaces/IConvexRewardPool.sol";
import "./interfaces/IPool.sol";

contract ConvexVault is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address private constant CONVEX_BOOSTER_ADDRESS =
        0xF403C135812408BFbE8713b5A23a04b3D48AAE31;

    uint256 private constant CVX_REWARD_POOL_INDEX = 0;
    uint256 private constant CRV_REWARD_POOL_INDEX = 1;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256[] rewardDebts; // Reward debt. See explanation below.
    }

    struct RewardPoolInfo {
        IERC20 rewardToken;
        IConvexRewardPool pool;
    }

    uint256[] public lastRewardTimestamps;
    uint256[] public accRewardPerShares; // Accumulated Rewards, times 1e18. See below.
    RewardPoolInfo[] public rewardPools;
    mapping(address => UserInfo) public userInfo;

    IERC20 public lpToken;
    IConvexBooster public booster;

    uint256 public pid;
    uint256 public totalDepositAmount;

    uint256 private lastCVXBalance;
    bool private needCVXWithdraw;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, address rewardToken);

    error InvalidPoolId();
    error InsufficientBalance(uint256 available, uint256 requested);

    constructor(address _lpToken, uint256 _pid) {
        lpToken = IERC20(_lpToken);
        booster = IConvexBooster(CONVEX_BOOSTER_ADDRESS);
        pid = _pid;

        if (pid > IConvexBooster(booster).poolLength()) revert InvalidPoolId();

        (, , , address _crvRewards, , ) = IConvexBooster(booster).poolInfo(pid);

        IConvexRewardPool baseRewardPool = IConvexRewardPool(_crvRewards);
        IConvexRewardPool cvxRewardPool = IConvexRewardPool(
            booster.stakerRewards()
        );

        uint256 extraRewardLength = baseRewardPool.extraRewardsLength();
        uint256 rewardTokenCount = extraRewardLength.add(2);

        rewardPools.push(
            RewardPoolInfo({
                rewardToken: IERC20(cvxRewardPool.stakingToken()),
                pool: cvxRewardPool
            })
        );
        rewardPools.push(
            RewardPoolInfo({
                rewardToken: IERC20(baseRewardPool.rewardToken()),
                pool: baseRewardPool
            })
        );

        for (uint256 i; i != rewardTokenCount; ++i) {
            lastRewardTimestamps.push(0);
            accRewardPerShares.push(0);

            if (i > 1) {
                IConvexRewardPool extraRewardPool = IConvexRewardPool(
                    baseRewardPool.extraRewards(i - 2)
                );
                rewardPools.push(
                    RewardPoolInfo({
                        rewardToken: IERC20(extraRewardPool.rewardToken()),
                        pool: extraRewardPool
                    })
                );
            }
        }
    }

    /**
        @dev Allows a user to deposit LP tokens into the farming pool and earn rewards.
        @param _amount The amount of LP tokens to deposit 
    */
    function deposit(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];

        updateReward();

        uint256 pending;
        uint256 amountAfterDeposit = user.amount.add(_amount);
        uint256 rewardTokenCount = rewardPools.length;

        for (uint256 i; i < rewardTokenCount; ++i) {
            if (user.amount > 0) {
                pending = accRewardPerShares[i].mul(user.amount).div(1e18).sub(
                    user.rewardDebts[i]
                );

                if (pending > 0) {
                    safeRewardTransfer(
                        rewardPools[i].rewardToken,
                        msg.sender,
                        pending
                    );

                    // CVX RewardPool's index is 0
                    if (i == CVX_REWARD_POOL_INDEX) {
                        lastCVXBalance = rewardPools[i].rewardToken.balanceOf(
                            address(this)
                        );
                        needCVXWithdraw = false;
                    }

                    user.rewardDebts[i] = accRewardPerShares[i]
                        .mul(amountAfterDeposit)
                        .div(1e18);
                }
            } else {
                user.rewardDebts = new uint256[](rewardTokenCount);
                break;
            }
        }

        if (_amount > 0) {
            lpToken.safeTransferFrom(msg.sender, address(this), _amount);
            lpToken.safeApprove(address(booster), _amount);
            booster.deposit(pid, _amount, true);
            user.amount = user.amount.add(_amount);
            totalDepositAmount = totalDepositAmount.add(_amount);
        }

        emit Deposit(msg.sender, _amount);
    }

    /**
        @dev Allows a user to withdraw their deposited LP tokens from the pool along with any earned rewards. Updates the accumulated rewards
        - for all reward tokens and stores them in the accRewardPerShares array. The function first checks if the user has sufficient balance
        - before updating the rewards and withdrawing the LP tokens from the external staking contract and the MasterChef booster. It then calculates
        - the pending rewards for each token and transfers them to the user before updating their reward debts based on the new deposit amount.
        - Finally, it updates the user's deposit amount and the total deposit amount before emitting an event indicating that the withdrawal
        has been processed successfully.
        @param _amount The amount of LP tokens to be withdrawn by the user. 
    */
    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];

        if (user.amount < _amount)
            revert InsufficientBalance(user.amount, _amount);

        updateReward();

        rewardPools[CRV_REWARD_POOL_INDEX].pool.withdraw(_amount, true);
        booster.withdraw(pid, _amount);

        uint256 pending;
        uint256 amountAfterWithdraw = user.amount.sub(_amount);
        uint256 rewardTokenCount = rewardPools.length;

        for (uint256 i; i != rewardTokenCount; ++i) {
            if (user.amount > 0) {
                pending = accRewardPerShares[i].mul(user.amount).div(1e18).sub(
                    user.rewardDebts[i]
                );

                if (pending > 0) {
                    safeRewardTransfer(
                        rewardPools[i].rewardToken,
                        msg.sender,
                        pending
                    );

                    if (i == CVX_REWARD_POOL_INDEX) {
                        lastCVXBalance = rewardPools[i].rewardToken.balanceOf(
                            address(this)
                        );
                        needCVXWithdraw = false;
                    }
                }
            }

            user.rewardDebts[i] = accRewardPerShares[i]
                .mul(amountAfterWithdraw)
                .div(1e18);
        }

        user.amount = user.amount.sub(_amount);
        lpToken.safeTransfer(address(msg.sender), _amount);
        totalDepositAmount = totalDepositAmount.sub(_amount);

        emit Withdraw(msg.sender, _amount);
    }

    /**
        @dev Allows a user to claim their pending rewards for a specific reward token.
        @param _rewardToken The address of the reward token to be claimed.
        Emits a {ClaimReward} event indicating that the reward has been claimed by the user. 
    */
    function claim(address _rewardToken) public {
        UserInfo storage user = userInfo[msg.sender];

        updateReward();

        uint256 pending;
        uint256 rewardTokenCount = rewardPools.length;

        for (uint256 i; i != rewardTokenCount; ++i) {
            if (address(rewardPools[i].rewardToken) == _rewardToken) {
                pending = accRewardPerShares[i].mul(user.amount).div(1e18).sub(
                    user.rewardDebts[i]
                );

                if (pending > 0) {
                    if (i == CVX_REWARD_POOL_INDEX) {
                        lastCVXBalance = rewardPools[i].rewardToken.balanceOf(
                            address(this)
                        );
                        needCVXWithdraw = false;
                    }

                    safeRewardTransfer(
                        rewardPools[i].rewardToken,
                        msg.sender,
                        pending
                    );

                    user.rewardDebts[i] = accRewardPerShares[i]
                        .mul(user.amount)
                        .div(1e18);
                }

                break;
            }
        }

        emit ClaimReward(msg.sender, _rewardToken);
    }

    /**
        @dev Updates the accumulated rewards for all reward tokens and stores them in the accRewardPerShares array.
        This function is internal and can only be called by other functions within the contract. It calculates the rewards earned
        since the last update based on the deposit amount and time elapsed. If the reward token is CVX, it also checks if any CVX
        has been withdrawn from the MasterChef pool since the last update and calculates the earned rewards accordingly. 
    */
    function updateReward() internal {
        uint256 rewardTokenCount = rewardPools.length;

        for (uint256 i; i != rewardTokenCount; ++i) {
            if (block.timestamp <= lastRewardTimestamps[i]) {
                continue;
            }

            if (totalDepositAmount == 0) {
                lastRewardTimestamps[i] = block.timestamp;
                continue;
            }

            uint256 earned;

            if (i == CVX_REWARD_POOL_INDEX) {
                uint256 cvxBalance = rewardPools[i].rewardToken.balanceOf(
                    address(this)
                );

                if (needCVXWithdraw == true && lastCVXBalance == cvxBalance) {
                    earned = 0;
                } else {
                    earned = cvxBalance - lastCVXBalance;
                    needCVXWithdraw = true;
                }
            } else {
                earned = rewardPools[i].pool.earned(address(this));
                rewardPools[i].pool.getReward();
            }

            accRewardPerShares[i] = accRewardPerShares[i].add(
                earned.mul(1e18).div(totalDepositAmount)
            );

            lastRewardTimestamps[i] = block.timestamp;
        }
    }

    // Safe rewardToken transfer function, just in case if rounding error causes pool to not have enough SUSHIs.
    function safeRewardTransfer(
        IERC20 _token,
        address _to,
        uint256 _amount
    ) internal {
        uint256 balance = _token.balanceOf(address(this));
        if (_amount > balance) {
            _token.transfer(_to, balance);
        } else {
            _token.transfer(_to, _amount);
        }
    }
}
