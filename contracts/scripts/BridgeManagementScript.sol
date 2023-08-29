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
      bridgeAddr = 0xF6838DF98b3294E689A6741Ec21C9B07603edaC9;
      veAddr = 0x6644E6D2e773fE4Bbf8400926924DedD87cd9177;
      ionicTokenAddr = 0x1F58582511FBD5DC4157527f228B600Be74FEf8b;
      dpaAddr = 0x4751E54fFE16B7050B8d54710EF30728bcF97945;
    } else if (block.chainid == 80001) {
      bridgeAddr = 0x3B452E7A36812558C2A1a5F0d489C41Ec9374A05;
      veAddr = 0x1A259641e9bd072caC79e5Fd08B9fcF4A186b97E;
      ionicTokenAddr = 0xc9247012ba63aD9Ec021048282E0Ff1266Cc2a15;
      dpaAddr = 0xa3bDf120A0cDF2017a20795b766baE0631B20831;
    }

    MockBridge bridge = MockBridge(bridgeAddr);
    VoteEscrow ve = VoteEscrow(veAddr);
    IonicToken ionicToken = IonicToken(veAddr);

    emit log_named_address("ve owner", address(ve.owner()));
    emit log_named_address("caller", vm.addr(deployerPrivateKey));

    //    {
    //      ProxyAdmin dpa = ProxyAdmin(dpaAddr);
    //      VoteEscrow veImpl = VoteEscrow(0x37fbAa9DBC39832D3BBEc55495b6CAF51DD1561c); //new VoteEscrow();
    //      dpa.upgrade(ITransparentUpgradeableProxy(payable(veAddr)), address(veImpl));
    //    }

    {
      ProxyAdmin dpa = ProxyAdmin(dpaAddr);
      address voter = 0xEBD60993642CA6e49ADa0Df517EA48D4084a05dE;
      address impl = 0xDFE79b4F18Fa0CC0588b8732bea1B54688988c7E;
      dpa.upgrade(ITransparentUpgradeableProxy(payable(voter)), impl);
    }

    //ve.setMasterChain();

    vm.stopBroadcast();
  }
}
