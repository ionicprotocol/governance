// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "./MockBridge.sol";
import "../IonicToken.sol";

contract BridgingTest is Test {
  MockBridge public bridge;
  VoteEscrow public ve;
  IonicToken public token;

  address alice = address(1);
  address bob = address(255);
  address charlie = address(255);

  uint256 aliceLockAmount = 20e18;
  uint256 aliceLockPeriod = 8 weeks;
  uint256 bobLockAmount = 10e18;
  uint256 bobLockTime = 2 weeks;
  uint256 locksStartingTs;

  mapping(uint128 => uint256) private forkIds;

  uint128 constant BSC_CHAPEL = 97;
  uint128 constant MUMBAI = 80001;

  function _forkAtBlock(uint128 chainid, uint256 blockNumber) internal {
    if (block.chainid != chainid) {
      if (blockNumber != 0) {
        vm.selectFork(getArchiveForkId(chainid));
        vm.rollFork(blockNumber);
      } else {
        vm.selectFork(getForkId(chainid));
      }
    }
    afterForkSetUp();
  }

  function _fork(uint128 chainid) internal {
    _forkAtBlock(chainid, 0);
  }

  function getForkId(uint128 chainid, bool archive) private returns (uint256) {
    return archive ? getForkId(chainid) : getArchiveForkId(chainid);
  }

  function getForkId(uint128 chainid) private returns (uint256) {
    if (forkIds[chainid] == 0) {
      if (chainid == BSC_CHAPEL) {
        forkIds[chainid] = vm.createFork(vm.rpcUrl("chapel_rpc")) + 100;
      } else if (chainid == MUMBAI) {
        forkIds[chainid] = vm.createFork(vm.rpcUrl("mumbai_rpc")) + 100;
      }
    }

    return forkIds[chainid] - 100;
  }

  function getArchiveForkId(uint128 chainid) private returns (uint256) {
    // store the archive rpc urls in the forkIds mapping at an offset
    uint128 chainidWithOffset = chainid + type(uint64).max;
    if (forkIds[chainidWithOffset] == 0) {
      if (chainid == BSC_CHAPEL) {
        forkIds[chainidWithOffset] = vm.createFork(vm.rpcUrl("chapel_rpc_archive")) + 100;
      } else if (chainid == MUMBAI) {
        forkIds[chainidWithOffset] = vm.createFork(vm.rpcUrl("mumbai_rpc_archive")) + 100;
      }
    }
    return forkIds[chainidWithOffset] - 100;
  }

  function afterForkSetUp() internal virtual {
    if (block.chainid == BSC_CHAPEL) {
      bridge = MockBridge(0xF6838DF98b3294E689A6741Ec21C9B07603edaC9);
    } else if (block.chainid == MUMBAI) {
      bridge = MockBridge(0x3B452E7A36812558C2A1a5F0d489C41Ec9374A05);
    } else {
      bridge = new MockBridge(VoteEscrow(address(0)));
    }

    ve = bridge.ve();
    token = IonicToken(ve.token());

    if (!token.isBridge(address(this))) {
      vm.prank(token.owner());
      token.addBridge(address(this));
    }

    // mint ION to the users
    token.mint(alice, 100e18);
    token.mint(bob, 1000e18);
    token.mint(charlie, 1000e18);

    if (!ve.isBridge(address(bridge))) {
      vm.startPrank(ve.owner());
      ve.addBridge(address(bridge));
      vm.stopPrank();
    }
  }

  function createUsersLocks() internal {
    vm.startPrank(alice);
    token.approve(address(ve), 1e36);
    ve.create_lock(aliceLockAmount, aliceLockPeriod);
    vm.stopPrank();

    vm.startPrank(bob);
    token.approve(address(ve), 1e36);
    ve.create_lock(bobLockAmount, bobLockTime);
    vm.stopPrank();

    locksStartingTs = ((block.timestamp) / 2 weeks) * 2 weeks;
  }

  function testBridging() public {
    _fork(BSC_CHAPEL);

    createUsersLocks();

    uint256 aliceNftId = ve.tokenOfOwnerByIndex(alice, 0);
    uint256 bobNftId = ve.tokenOfOwnerByIndex(bob, 0);
    assertGt(bobNftId, aliceNftId, "!nfts ids incremental");

    // start bridging alice to some other chain
    bytes memory aliceFromChapel = bridge.burn(aliceNftId);

    {
      // verify that her NFT data is reset
      (int128 aliceChapelAmount, uint256 aliceChapelLockTime) = ve.locked(aliceNftId);
      assertEq(aliceChapelAmount, int128(0), "chapel alice amount");
      assertEq(aliceChapelLockTime, 0, "chapel alice end ts");

      // TODO verify vars with the tag RESET_STORAGE_BURN
    }

    // also start bridging bob whose NFT was minted later than alice's
    bytes memory bobFromChapel = bridge.burn(bobNftId);

    // fork to a subchain
    _fork(MUMBAI);

    // complete the bridging of bob's NFT first
    bridge.mint(bob, bobNftId, bobFromChapel);

    // complete the bridging of alice
    bridge.mint(alice, aliceNftId, aliceFromChapel);
    address shouldBeAlice = ve.ownerOf(aliceNftId);
    assertEq(shouldBeAlice, alice, "mumbai owner is not alice");

    // start bridging alice's NFT back to the master chain
    bytes memory aliceFromMumbai = bridge.burn(aliceNftId);

    // fork back to the originating chain
    _fork(BSC_CHAPEL);

    {
      // lock for charlie before alice had bridged back
      vm.startPrank(charlie);
      token.approve(address(ve), 1e36);
      uint256 charlieNftId = ve.create_lock(99e18, 3 weeks);
      vm.stopPrank();
    }

    // bridge back alice
    bridge.mint(alice, aliceNftId, aliceFromMumbai);
    shouldBeAlice = ve.ownerOf(aliceNftId);
    assertEq(shouldBeAlice, alice, "chapel owner is not alice");

    {
      // verify that alice's NFT was correctly minted back on the originating chain
      (int128 aliceAmount, uint256 aliceEndTs) = ve.locked(aliceNftId);
      assertEq(aliceAmount, int128(uint128(aliceLockAmount)), "alice amount");
      assertEq(aliceEndTs, locksStartingTs + aliceLockPeriod, "alice end ts");

      // TODO verify vars with the tag RESET_STORAGE_BURN
    }
  }
}
