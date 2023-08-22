// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "../test/MockBridge.sol";
import "../VoteEscrow.sol";
import "../IonicToken.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// forge script contracts/scripts/BridgeManagementScript.sol:BridgeManagementScript --rpc-url CHAPEL_RPC --broadcast -vv
contract BridgeManagementScript is Script, Test {

  function run() external {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address veAddr;
    address bridgeAddr;
    address ionicTokenAddr;
    address dpaAddr;

    if (block.chainid == 97) {
      bridgeAddr = 0xFEbC03Ea04f1E6D71D7e45b431e604537ee7E6a6;
      veAddr = 0x1800bf8c4D87746857207f56fB522f689551AFFf;
      ionicTokenAddr = 0x2D51E00Cf28b8A51704CA65c3Cf1Bb8212706ca6;
      dpaAddr = 0x86e1fd7BfF48d3bC4Ad9d95CF40b523D42E48811;
    } else if (block.chainid == 80001) {
      bridgeAddr = 0xFEbC03Ea04f1E6D71D7e45b431e604537ee7E6a6;
      veAddr = 0x1800bf8c4D87746857207f56fB522f689551AFFf;
      ionicTokenAddr = 0xE2efE52ae230DBf66438F82c366c1F405Aa1F3A0;
      dpaAddr = 0x86e1fd7BfF48d3bC4Ad9d95CF40b523D42E48811;
    }

    MockBridge bridge = MockBridge(bridgeAddr);
    VoteEscrow ve = VoteEscrow(veAddr);
    IonicToken ionicToken = IonicToken(veAddr);

    emit log_named_address("ve owner", address(ve.owner()));
    emit log_named_address("caller", vm.addr(deployerPrivateKey));

    ProxyAdmin dpa = ProxyAdmin(dpaAddr);
    VoteEscrow veImpl = VoteEscrow(0xe6f08927E283D623B74374304b16C710bB0b6220); //new VoteEscrow();
    dpa.upgrade(ITransparentUpgradeableProxy(payable(veAddr)), address(veImpl));

    ve.setToken(ionicTokenAddr);
    //ve.create_lock(200e18, 4 weeks);

    vm.stopBroadcast();
  }
}
