// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./interfaces/IMarket.sol";
import "./interfaces/IFlywheel.sol";
import "./Gauge.sol";

contract MarketGauge is Gauge {
  using SafeERC20 for IERC20;

  IFlywheel public flywheel;

  function initialize(
    address _flywheel,
    address _rewardToken,
    address _ve,
    address _target,
    address _voter
  ) external initializer {
    __Gauge_init(_rewardToken, _ve, _target, _voter);
    flywheel = IFlywheel(_flywheel);
  }

  function notifyRewardAmount(address token, uint256 reward) external override nonReentrant isNotEmergency onlyVoter {
    require(token == address(rewardToken), "not rew token");
    address flywheelRewards = flywheel.flywheelRewards();
    require(flywheelRewards != address(0), "zero addr flywheel");
    rewardToken.safeTransferFrom(voter, flywheelRewards, reward);
  }

  function getReward(address _user) public override nonReentrant onlyVoter {
    flywheel.accrue(IERC20(target), _user);
    flywheel.claimRewards(_user);
  }

  //  function claimFees() external {
  //    claimMarketFees();
  //  }
  //
  //  function claimMarketFees() public nonReentrant returns (uint256) {
  //    return abi.decode(_claimFees(), (uint256));
  //  }
  //
  //  function _claimFees() internal override returns (bytes memory) {
  //    uint256 fees = IMarket(target).totalAdminFees();
  //
  //    if (fees > 0) {
  //      IMarket(target)._withdrawAdminFees(fees);
  //      address underlying = IMarket(target).underlying();
  //
  //      if (fees > 0) {
  //        // assuming that the admin is the gauge
  //        IERC20(underlying).approve(internal_bribe, fees);
  //        IBribe(internal_bribe).notifyRewardAmount(underlying, fees);
  //      }
  //      emit ClaimFees(msg.sender, fees);
  //    }
  //
  //    return abi.encode(fees);
  //  }

  function setFlywheel(IFlywheel _flywheel) external onlyOwner {
    flywheel = _flywheel;
  }
}
