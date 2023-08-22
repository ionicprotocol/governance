// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "./MockBridge.sol";

contract BridgingTest is Test {
  MockBridge public bridge;
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

    vm.startPrank(bridge.ve().owner());
    bridge.ve().addBridge(address(bridge));
    vm.stopPrank();
  }

  function testBridging() public {
    _fork(BSC_CHAPEL);
    // turn chapel persistence on
    vm.makePersistent(address(bridge.ve()));

    uint256 tsNow = block.timestamp;

    uint256 totalTokens = 0;

    address alice = address(1);
    address bob = address(255);

    uint256 aliceNftId = ++totalTokens;
    bridge.mint(alice, aliceNftId, abi.encode(20e18, tsNow + 8 weeks));

    bytes memory aliceFromChapel = bridge.burn(aliceNftId);

    _fork(MUMBAI);
    // turn mumbai persistence on
    vm.makePersistent(address(bridge.ve()));

    bridge.mint(alice, aliceNftId, aliceFromChapel);

    address shouldBeAlice = bridge.ve().ownerOf(aliceNftId);

    assertEq(shouldBeAlice, alice, "owner is not alice");
  }
}