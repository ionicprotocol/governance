import { DeployFunction } from "hardhat-deploy/types";

import { IonicToken } from "../typechain/IonicToken";
import { VoteEscrow } from "../typechain/VoteEscrow";
import { VoterRolesAuthority } from "../typechain/VoterRolesAuthority";

const func: DeployFunction = async ({ ethers, getNamedAccounts, deployments, getChainId }): Promise<void> => {
  console.log("RPC URL: ", ethers.provider.connection.url);
  const chainId = parseInt(await getChainId());
  console.log("chainId: ", chainId);
  const { deployer } = await getNamedAccounts();
  console.log("deployer: ", deployer);

  const CHAPEL_ID = 97;
  const HARDHAT_ID = 1337;
  const MUMBAI_ID = 80001;
  const ARBI_GOERLI_ID = 421613;
  // const ARBI_ID = 42161;

  let lockedTokenAddress;
  if (chainId === HARDHAT_ID || chainId === CHAPEL_ID || chainId === MUMBAI_ID || chainId === ARBI_GOERLI_ID) {
    const ionicToken = await deployments.deploy("IonicToken", {
      contract: "IonicToken",
      from: deployer,
      args: [],
      log: true,
      waitConfirmations: 1,
      proxy: {
        execute: {
          init: {
            methodName: "initializeIon",
            args: []
          }
        },
        owner: deployer,
        proxyContract: "OpenZeppelinTransparentProxy"
      }
    });
    console.log(`IonicToken deployed at ${ionicToken.address}`);

    // lock ION for testing
    lockedTokenAddress = ionicToken.address;
  } else {
    // lockedTokenAddress = BAL8020;
  }

  const voterRolesAuth = await deployments.deploy("VoterRolesAuthority", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: 1,
    proxy: {
      execute: {
        init: {
          methodName: "initialize",
          args: [deployer]
        }
      },
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy"
    }
  });
  console.log(`VoterRolesAuthority deployed at ${voterRolesAuth.address}`);

  const gaugeFactory = await deployments.deploy("GaugeFactory", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: 1,
    proxy: {
      execute: {
        init: {
          methodName: "initialize",
          args: [voterRolesAuth.address]
        }
      },
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy"
    }
  });
  console.log(`GaugeFactory deployed at ${gaugeFactory.address}`);
  const voterRolesAuthority = await ethers.getContract("VoterRolesAuthority") as VoterRolesAuthority;
  let tx = await voterRolesAuthority.configureRoles(gaugeFactory.address);
  console.log(`setting the gauge factory in the voter roles auth`, tx.hash);
  await tx.wait();
  console.log(`tx mined`);

  const voteEscrow = await deployments.deploy("VoteEscrow", {
    contract: "VoteEscrow",
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: 1,
    proxy: {
      execute: {
        init: {
          methodName: "initialize",
          args: ["Ionic Vote Escrow", "veIONIC", lockedTokenAddress]
        }
      },
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy"
    }
  });
  console.log(`VoteEscrow deployed at ${voteEscrow.address}`);

  const timer = await deployments.deploy("EpochsTimer", {
    contract: "EpochsTimer",
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: 1,
    proxy: {
      execute: {
        init: {
          methodName: "initialize",
          args: []
        }
      },
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy"
    }
  });
  console.log(`EpochsTimer deployed at ${timer.address}`);

  const bribeFactory = ethers.constants.AddressZero;

  const voter = await deployments.deploy("Voter", {
    contract: "Voter",
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: 1,
    proxy: {
      execute: {
        init: {
          methodName: "initialize",
          args: [voteEscrow.address, gaugeFactory.address, bribeFactory, timer.address, voterRolesAuth.address]
        },
        onUpgrade: {
          methodName: "reinitialize",
          args: [voteEscrow.address]
        }
      },
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy"
    }
  });
  console.log(`Voter deployed at ${voter.address}`);
  tx = await voterRolesAuthority.configureVoterPermissions(voter.address);
  console.log(`configuring the voter permissions`, tx.hash);
  await tx.wait();
  console.log(`tx mined`);

  const voteEscrowContract = (await ethers.getContractOrNull("VoteEscrow")) as VoteEscrow;
  const currentVoter = await voteEscrowContract.callStatic.voter();
  if (currentVoter != voter.address) {
    const tx = await voteEscrowContract.setVoter(voter.address);
    await tx.wait();
    console.log(`set the voter in the escrow with tx ${tx.hash}`);
  }

  if (chainId === HARDHAT_ID || chainId === CHAPEL_ID || chainId === MUMBAI_ID || chainId === ARBI_GOERLI_ID) {
    const mockBridge = await deployments.deploy("MockBridge", {
      contract: "MockBridge",
      from: deployer,
      args: [voteEscrow.address],
      log: true,
      waitConfirmations: 1,
      skipIfAlreadyDeployed: true
    });
    console.log(`MockBridge deployed at ${mockBridge.address}`);

    let tx = await voteEscrowContract.addBridge(mockBridge.address);
    await tx.wait();
    console.log(`enabled the bridge to mint NFTs ${tx.hash}`);

    const ionicTokenContract = (await ethers.getContractOrNull("IonicToken")) as IonicToken;
    tx = await ionicTokenContract.addBridge(mockBridge.address);
    await tx.wait();
    console.log(`enabled the bridge to mint ION ${tx.hash}`);
  }
};

func.tags = ["prod"];

export default func;
