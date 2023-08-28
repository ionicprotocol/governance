// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Voter } from "../Voter.sol";
import { VoteEscrow } from "../VoteEscrow.sol";
import { BaseTest } from "./BaseTest.sol";

contract VoteEscrowFuzzTest is BaseTest {
  address alice = address(1);
  address bob = address(255);
  address charlie = address(768);

  function testLocksFixed() public {
    testLocksFuzz(220, 9234914913);
  }

  function testLocksFuzz(uint16 runs, uint256 random) public {
    vm.label(alice, "alice");
    vm.label(bob, "bob");
    vm.label(charlie, "charlie");

    vm.assume(runs > 20);
    vm.assume(random > 20);

    address bridgingUser;
    uint256 bridgedTokenId;
    bytes memory bridgingMetadata;

    for (uint256 i = 0; i < runs; i++) {
      address minter;
      if (i % 3 == 0) {
        minter = alice;
      } else if (i % 2 == 0) {
        minter = bob;
      } else {
        minter = charlie;
      }

      ionicToken.mint(minter, 1e24);
      vm.startPrank(minter);
      {
        ionicToken.approve(address(ve), 1e36);
        emit log_named_address("minting for", minter);
        uint256 tokenId = ve.create_lock(20e18, 2 weeks);

        // start bridging, splitting and merging
        uint256 minterNfts = ve.balanceOf(minter);
        emit log_named_uint("minter nfts", minterNfts);
        if (minterNfts > 2) {
          uint256 randi = random - i;
          if (i > 15 && randi % 4 == 0) {
            vm.stopPrank();
            vm.startPrank(bridge1);

            if (bridgingUser != address(0)) {
              emit log_named_uint("bridge minting", bridgedTokenId);
              ve.mint(bridgingUser, bridgedTokenId, bridgingMetadata);
              bridgedTokenId = 0;
              bridgingMetadata = "";
              bridgingUser = address(0);
            } else {
              bridgedTokenId = ve.tokenOfOwnerByIndex(minter, 1);
              bridgingMetadata = ve.burn(bridgedTokenId);
              bridgingUser = minter;
              emit log_named_uint("bridge burning", bridgedTokenId);
            }
            vm.stopPrank();
            vm.startPrank(minter);
          } else {
            if (i > 6 && randi % 3 == 0) {
              uint256 nft2 = ve.tokenOfOwnerByIndex(minter, 2);
              if (nft2 != 0 && block.timestamp < ve.locked__end(nft2)) {
                uint256 nft2Balance = ve.balanceOfNFT(nft2);
                emit log_named_uint("splitting nft at", nft2);
                uint256 half0 = nft2Balance / 2;
                uint256 half1 = nft2Balance - half0;
                ve.split(asArray(half0, half1), nft2);
              }
            }
            if (i > 10 && randi % 5 == 0) {
              uint256 nft0 = ve.tokenOfOwnerByIndex(minter, 0);
              uint256 nft1 = ve.tokenOfOwnerByIndex(minter, 1);
              uint256 nft2 = ve.tokenOfOwnerByIndex(minter, 2);
              if (nft0 != 0 && nft1 != 0 && nft2 != 0) {
                emit log_named_uint("merging", nft0);
                emit log_named_uint("merging", nft1);
                emit log_named_uint("merging", nft2);
                ve.merge(nft0, nft1);
                ve.merge(nft1, nft2);
              }
            }
            if (i > 14 && randi % 7 == 0) {
              uint256 nft1 = ve.tokenOfOwnerByIndex(minter, 1);
              if (nft1 != 0 && block.timestamp > ve.locked__end(nft1)) {
                emit log_named_uint("withdrawing", nft1);
                ve.withdraw(nft1);
              }
            }
          }
        }
        emit log("");
        vm.warp(block.timestamp + 6 hours);
        vm.roll(block.number + 1000);
      }
      vm.stopPrank();
    }
  }
}
