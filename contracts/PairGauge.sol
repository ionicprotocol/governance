// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./interfaces/IPair.sol";
import "./Gauge.sol";

contract PairGauge is Gauge {
  using SafeERC20 for IERC20;

  uint256 public duration;
  uint256 public rewardRate;
  uint256 public lastUpdateTime;
  uint256 public rewardPerTokenStored;
  uint256 public periodFinish;

  mapping(address => uint256) public userRewardPerTokenPaid;
  mapping(address => uint256) public rewards;

  uint256 public totalSupply;
  mapping(address => uint256) internal _balances;

  modifier updateReward(address account) {
    rewardPerTokenStored = rewardPerToken();
    lastUpdateTime = lastTimeRewardApplicable();
    if (account != address(0)) {
      rewards[account] = earned(account);
      userRewardPerTokenPaid[account] = rewardPerTokenStored;
    }
    _;
  }

  function initialize(
    address _rewardToken,
    address _ve,
    address _target,
    address _voter
  ) external initializer {
    __Gauge_init(_rewardToken, _ve, _target, _voter);
    rewardToken = IERC20(_rewardToken);
    duration = 2 weeks;
  }

  /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    DISTRIBUTION
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */

  function notifyRewardAmount(
    address token,
    uint256 reward
  ) external override nonReentrant isNotEmergency onlyVoter updateReward(address(0)) {
    require(token == address(rewardToken), "not rew token");
    rewardToken.safeTransferFrom(voter, address(this), reward);

    if (block.timestamp >= periodFinish) {
      rewardRate = reward / duration;
    } else {
      uint256 remaining = periodFinish - block.timestamp;
      uint256 leftover = remaining * rewardRate;
      rewardRate = (reward + leftover) / duration;
    }

    // Ensure the provided reward amount is not more than the balance in the contract.
    // This keeps the reward rate in the right range, preventing overflows due to
    // very high values of rewardRate in the earned and rewardsPerToken functions;
    // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
    uint256 balance = rewardToken.balanceOf(address(this));
    require(rewardRate <= balance / duration, "Provided reward too high");

    lastUpdateTime = block.timestamp;
    periodFinish = block.timestamp + duration;
    emit RewardAdded(reward);
  }

  /* -----------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
                                  VIEW FUNCTIONS
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  ----------------------------------------------------------------------------- */

  ///@notice last time reward
  function lastTimeRewardApplicable() public view returns (uint256) {
    // return min
    return block.timestamp < periodFinish ? block.timestamp : periodFinish;
  }

  ///@notice  reward for a sinle token
  function rewardPerToken() public view returns (uint256) {
    if (totalSupply == 0) {
      return rewardPerTokenStored;
    } else {
      return rewardPerTokenStored + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalSupply;
    }
  }

  ///@notice balance of a user
  function balanceOf(address account) external view returns (uint256) {
    return _balances[account];
  }

  ///@notice see earned rewards for user
  function earned(address account) public view returns (uint256) {
    return rewards[account] + (_balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18;
  }

  /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    USER INTERACTION
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */

  ///@notice User harvest function called from voter (voter allows harvest on multiple gauges)
  function getReward(address _user) public nonReentrant onlyVoter updateReward(_user) {
    uint256 reward = rewards[_user];
    if (reward > 0) {
      rewards[_user] = 0;
      rewardToken.safeTransfer(_user, reward);
      emit Harvest(_user, reward);
    }
  }

  ///@notice User harvest function
  function getReward() public nonReentrant updateReward(msg.sender) {
    uint256 reward = rewards[msg.sender];
    if (reward > 0) {
      rewards[msg.sender] = 0;
      rewardToken.safeTransfer(msg.sender, reward);
      emit Harvest(msg.sender, reward);
    }
  }

  ///@notice deposit all rewardToken of msg.sender
  function depositAll() external {
    _deposit(rewardToken.balanceOf(msg.sender), msg.sender);
  }

  ///@notice deposit amount rewardToken
  function deposit(uint256 amount) external {
    _deposit(amount, msg.sender);
  }

  ///@notice deposit internal
  function _deposit(uint256 amount, address account) internal nonReentrant isNotEmergency updateReward(account) {
    require(amount > 0, "deposit(Gauge): cannot stake 0");

    _balances[account] = _balances[account] + amount;
    totalSupply = totalSupply + amount;

    rewardToken.safeTransferFrom(account, address(this), amount);

    emit Deposit(account, amount);
  }

  ///@notice withdraw all token
  function withdrawAll() external {
    _withdraw(_balances[msg.sender]);
  }

  ///@notice withdraw a certain amount of rewardToken
  function withdraw(uint256 amount) external {
    _withdraw(amount);
  }

  ///@notice withdraw internal
  function _withdraw(uint256 amount) internal nonReentrant isNotEmergency updateReward(msg.sender) {
    require(amount > 0, "Cannot withdraw 0");
    require(_balances[msg.sender] > 0, "no balances");

    totalSupply = totalSupply - amount;
    _balances[msg.sender] = _balances[msg.sender] - amount;

    rewardToken.safeTransfer(msg.sender, amount);

    emit Withdraw(msg.sender, amount);
  }

  function emergencyWithdraw() external nonReentrant {
    require(emergency, "emergency");
    require(_balances[msg.sender] > 0, "no balances");
    uint256 _amount = _balances[msg.sender];
    totalSupply = totalSupply - _amount;
    _balances[msg.sender] = 0;
    rewardToken.safeTransfer(msg.sender, _amount);
    emit Withdraw(msg.sender, _amount);
  }

  function emergencyWithdrawAmount(uint256 _amount) external nonReentrant {
    require(emergency, "emergency");
    totalSupply = totalSupply - _amount;

    _balances[msg.sender] = _balances[msg.sender] - _amount;
    rewardToken.safeTransfer(msg.sender, _amount);
    emit Withdraw(msg.sender, _amount);
  }

  ///@notice withdraw all rewardToken and harvest rewardToken
  function withdrawAllAndHarvest() external {
    _withdraw(_balances[msg.sender]);
    getReward();
  }

  //  function claimFees() external {
  //    claimPairFees();
  //  }
  //
  //  function claimPairFees() public nonReentrant returns (uint256 claimed0, uint256 claimed1) {
  //    return abi.decode(_claimFees(), (uint256, uint256));
  //  }
  //
  //  function _claimFees() internal override returns (bytes memory) {
  //    uint256 claimed0;
  //    uint256 claimed1;
  //    IPair pair = IPair(target);
  //
  //    (claimed0, claimed1) = pair.claimFees();
  //    if (claimed0 > 0 || claimed1 > 0) {
  //      uint256 _fees0 = claimed0;
  //      uint256 _fees1 = claimed1;
  //
  //      (address _token0, address _token1) = pair.tokens();
  //
  //      if (_fees0 > 0) {
  //        IERC20(_token0).approve(internal_bribe, 0);
  //        IERC20(_token0).approve(internal_bribe, _fees0);
  //        IBribe(internal_bribe).notifyRewardAmount(_token0, _fees0);
  //      }
  //      if (_fees1 > 0) {
  //        IERC20(_token1).approve(internal_bribe, 0);
  //        IERC20(_token1).approve(internal_bribe, _fees1);
  //        IBribe(internal_bribe).notifyRewardAmount(_token1, _fees1);
  //      }
  //      emit ClaimFees(msg.sender, claimed0, claimed1);
  //    }
  //
  //    return abi.encode(claimed0, claimed1);
  //  }
  //
  //  event ClaimFees(address indexed from, uint256 claimed0, uint256 claimed1);
}
