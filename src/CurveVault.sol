pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ICurve.sol";
import "forge-std/Test.sol";

/**
 * @title CurveVault Contract
 * @dev The CurveVault contract allows users to deposit LP tokens and receive rewards proportionally based on their share of the total deposited tokens.
 */
contract CurveVault is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // const uint256 CRV_TOKEN_ADDRESS = "0xD533a949740bb3306d119CC777fa900bA034cd52";

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has deposited.
        uint256 rewardDebt; // Reward debt.
    }

    address constant CRV_TOKEN_ADDRESS =
        0xD533a949740bb3306d119CC777fa900bA034cd52;
    address constant CRV_TOKEN_MINTER_ADDRESS =
        0xd061D61a4d941c39E5453435B6345Dc261C2fcE0;

    // Address of LP token contract.
    IERC20 public lpToken;

    // Last block number that CRV distribution occurs.
    uint256 public lastRewardBlock;

    // Last Balance for reward.
    uint256 private lastRewardBalance;

    // Check if reward is withdrawn or not.
    bool private rewardWithdrawn;

    // The Curve gauge pool.
    ILiquidityGauge public crvLiquidityGauge;

    // CRV token address.
    ICurveToken public crvToken;

    // CRV token minter;
    ICurveMinter public crvMinter;

    // Accumulated CRV per share, times 1e18.
    uint256 public accRewardPerShare;

    // The total amount of LP tokens deposited in the vault.
    uint256 public totalDepositAmount;

    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);

    constructor(address _lpToken, address _curveGauge) {
        lpToken = IERC20(_lpToken);
        crvLiquidityGauge = ILiquidityGauge(_curveGauge);
        crvMinter = ICurveMinter(CRV_TOKEN_MINTER_ADDRESS);
        crvToken = ICurveToken(CRV_TOKEN_ADDRESS);
    }

    /**
     * @dev Updates the CRV reward variables for the vault.
     */
    function updateReward() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }

        if (totalDepositAmount == 0) {
            lastRewardBlock = block.number;
            return;
        }

        crvMinter.mint{gas: 30000000}(address(crvLiquidityGauge));

        uint256 earned = 0;
        uint256 currentBalance = getReward();

        if (rewardWithdrawn == false && lastRewardBalance == currentBalance) {
            earned = 0;
        } else {
            earned = currentBalance - lastRewardBalance;
        }

        accRewardPerShare = accRewardPerShare.add(
            earned.mul(1e18).div(totalDepositAmount)
        );

        lastRewardBlock = block.number;
    }

    function getReward() internal returns (uint256) {
        return crvToken.balanceOf(address(this));
    }

    /**
     * @dev Harvest user rewards from a given pool id
     */
    function harvestRewards() public {
        updateReward();

        UserInfo storage user = userInfo[msg.sender];

        uint256 rewardsToHarvest = accRewardPerShare
            .mul(user.amount)
            .div(1e18)
            .sub(user.rewardDebt);


        if (rewardsToHarvest == 0) {
            user.rewardDebt = accRewardPerShare.mul(user.amount).div(1e18);
            return;
        }

        user.rewardDebt = accRewardPerShare.mul(user.amount).div(1e18);

        safeCrvTransfer(msg.sender, rewardsToHarvest);

        lastRewardBalance = getReward();
        rewardWithdrawn = true;

        emit Claim(msg.sender, rewardsToHarvest);
    }

    /**
     * @dev Deposits LP tokens into the vault and updates the user's share of the rewards.
     * @param _amount The amount of LP tokens to deposit.
     */
    function deposit(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        harvestRewards();

        if (_amount > 0) {
            // Transfer LP tokens to the vault and update the total deposited amount.
            lpToken.safeTransferFrom(msg.sender, address(this), _amount);

            // Deposit LP tokens into the Curve gauge pool.
            lpToken.approve(address(crvLiquidityGauge), _amount);
            crvLiquidityGauge.deposit(_amount);

            user.amount = user.amount.add(_amount);
            user.rewardDebt = accRewardPerShare.mul(user.amount).div(1e18);
            totalDepositAmount = totalDepositAmount.add(_amount);
        }

        emit Deposit(msg.sender, _amount);
    }

    /**
     * @dev Withdraws LP tokens from the vault and updates the user's share of the rewards.
     * @param _amount The amount of LP tokens to withdraw.
     */
    function withdraw(uint256 _amount) public {

        UserInfo storage user = userInfo[msg.sender];

        require(
            user.amount >= _amount,
            "Vault: not enough balance to withdraw"
        );

        harvestRewards();

        user.amount = user.amount.sub(_amount);
        user.rewardDebt = accRewardPerShare.mul(user.amount).div(1e18);
        totalDepositAmount = totalDepositAmount.sub(_amount);

        if (_amount > 0) {
            // Withdraw LP tokens from the Curve gauge pool and transfer them to the user.
            lpToken.approve(address(this), _amount);
            crvLiquidityGauge.withdraw(_amount);
            lpToken.transferFrom(address(this), address(msg.sender), _amount);
        }

        emit Withdraw(msg.sender, _amount);
    }

    /**
     * @dev Withdraws all LP tokens from the vault and updates the user's share of the rewards.
     */
    function withdrawAll() public {
        UserInfo storage user = userInfo[msg.sender];
        withdraw(user.amount);
    }

    /**
     * @dev Claims pending CRV rewards for the user.
     */
    function claim() public {
        // emit Claim(msg.sender, pending);
    }

    /**
     * @dev Transfers CRV tokens from the contract to the recipient.
     * @param _to The address to transfer the CRV tokens to.
     * @param _amount The amount of CRV tokens to transfer.
     */
    function safeCrvTransfer(address _to, uint256 _amount) internal {
        uint256 crvBalance = crvToken.balanceOf(address(this));
        if (_amount > crvBalance) {
            crvToken.transfer(_to, crvBalance);
        } else {
            crvToken.transfer(_to, _amount);
        }
    }

    function getCrvTokenBalance() public returns (uint256) {
        return crvToken.balanceOf(msg.sender);
    }
}
