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

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256[] rewardDebts; // Reward debt. See explanation below.
    }

    struct RewardPoolInfo {
        IERC20 rewardToken;
        IConvexRewardPool pool;
    }

    IERC20 public lpToken;
    IConvexBooster public booster;
    uint256 private lastCVXBalance;
    bool private cvxWithdraw;

    uint256[] public lastRewardBlocks;
    uint256[] public accRewardPerShares; // Accumulated SUSHIs per share, times 1e12. See below.
    RewardPoolInfo[] public rewardPools;

    mapping(address => UserInfo) public userInfo;

    uint256 public pid;
    uint256 public rewardTokenLength;
    uint256 public totalDepositAmount;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, address rewardToken);

    error InvalidRewardData();
    error InsufficientBalance(uint256 available, uint256 requested);
    error UnauthorizedAccess(string message);

    constructor(address _lpToken, address _booster, uint256 _pid) {
        lpToken = IERC20(_lpToken);
        booster = IConvexBooster(_booster);
        pid = _pid;

        require(pid < IConvexBooster(booster).poolLength(), "invalid pool id");

        (, , , address _crvRewards, , ) = IConvexBooster(booster).poolInfo(pid);

        IConvexRewardPool baseRewardPool = IConvexRewardPool(_crvRewards);
        IConvexRewardPool cvxRewardPool = IConvexRewardPool(
            booster.stakerRewards()
        );

        uint256 extraRewardLength = baseRewardPool.extraRewardsLength();
        rewardTokenLength = extraRewardLength.add(2);

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

        for (uint256 i; i != rewardTokenLength; ++i) {
            lastRewardBlocks.push(0);
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

    function deposit(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];

        updateReward();

        uint256 pending = 0;
        uint256 amountAfterDeposit = user.amount.add(_amount);

        for (uint256 i; i < rewardTokenLength; ++i) {
            if (user.amount > 0) {
                pending = accRewardPerShares[i].mul(user.amount).div(1e18).sub(
                    user.rewardDebts[i]
                );

                safeRewardTransfer(
                    rewardPools[i].rewardToken,
                    msg.sender,
                    pending
                );

                if (i == 0) {
                    lastCVXBalance = rewardPools[i].rewardToken.balanceOf(
                        address(this)
                    );
                    cvxWithdraw = true;
                }

                user.rewardDebts[i] = accRewardPerShares[i]
                    .mul(amountAfterDeposit)
                    .div(1e18);
            } else {
                user.rewardDebts = new uint256[](rewardTokenLength);
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

    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];

        require(user.amount >= _amount, "Insufficient balance");

        updateReward();

        rewardPools[1].pool.withdraw(_amount, true);
        booster.withdraw(pid, _amount);

        uint256 pending = 0;
        uint256 amountAfterWithdraw = user.amount.sub(_amount);

        for (uint256 i; i != rewardTokenLength; ++i) {
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

                    if (i == 0) {
                        lastCVXBalance = rewardPools[i].rewardToken.balanceOf(
                            address(this)
                        );
                        cvxWithdraw = true;
                    }
                }
            }

            user.rewardDebts[i] = accRewardPerShares[i]
                .mul(amountAfterWithdraw)
                .div(1e18);
        }

        lpToken.safeTransfer(address(msg.sender), _amount);
        user.amount = user.amount.sub(_amount);
        totalDepositAmount = totalDepositAmount.sub(_amount);

        emit Withdraw(msg.sender, _amount);
    }

    function claim(address _rewardToken) public {
        UserInfo storage user = userInfo[msg.sender];

        updateReward();

        uint256 pending = 0;

        for (uint256 i; i != rewardTokenLength; ++i) {
            if (address(rewardPools[i].rewardToken) == _rewardToken) {
                pending = accRewardPerShares[i].mul(user.amount).div(1e18).sub(
                    user.rewardDebts[i]
                );

                if (pending > 0) {
                    safeRewardTransfer(
                        rewardPools[i].rewardToken,
                        msg.sender,
                        pending
                    );

                    if (i == 0) {
                        lastCVXBalance = rewardPools[i].rewardToken.balanceOf(
                            address(this)
                        );
                        cvxWithdraw = true;
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

    // Update reward variables of the given pool to be up-to-date.
    function updateReward() public {
        for (uint256 i; i != rewardTokenLength; ++i) {
            if (block.number <= lastRewardBlocks[i]) {
                continue;
            }

            if (totalDepositAmount == 0) {
                lastRewardBlocks[i] = block.number;
                continue;
            }

            uint256 earned = 0;

            if (i == 0) {
                uint256 cvxBalance = rewardPools[i].rewardToken.balanceOf(
                    address(this)
                );
                if (cvxWithdraw == false && lastCVXBalance == cvxBalance) {
                    earned = 0;
                } else {
                    earned = cvxBalance - lastCVXBalance;
                }
            } else {
                earned = rewardPools[i].pool.earned(address(this));
                rewardPools[i].pool.getReward();
            }

            accRewardPerShares[i] = accRewardPerShares[i].add(
                earned.mul(1e18).div(totalDepositAmount)
            );

            lastRewardBlocks[i] = block.number;
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
