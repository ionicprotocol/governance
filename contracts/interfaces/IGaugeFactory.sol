// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IGaugeFactory {
  function createPairGauge(
    address _rewardToken,
    address _ve,
    address _target,
    address _distribution
  ) external returns (address);

  function createMarketGauge(
    address _flywheel,
    address _rewardToken,
    address _ve,
    address _target,
    address _distribution
  ) external returns (address);
}
