import { task, types } from "hardhat/config";

import { GaugeFactory } from "../typechain/GaugeFactory";
import { IonicToken } from "../typechain/IonicToken";
import { VoteEscrow } from "../typechain/VoteEscrow";
import { Voter } from "../typechain/Voter";

const BAL8020 = "0x0000";

// npx hardhat gf:create-market-gauge --action 0 --gauge 0x000 --network chapel
export default task("gf:create-market-gauge", "create market gauge")
  .addParam("signer", "The address of the current deployer", "deployer", types.string)
  .addParam("flywheel", "The address of the flywheel deployed to the market", undefined, types.string)
  .setAction(async ({ signer, flywheel }, { ethers }) => {
    const deployer = await ethers.getNamedSigner(signer);
    const ionicToken = (await ethers.getContract("IonicToken", deployer)) as IonicToken;
    const ve = (await ethers.getContract("VoteEscrow", deployer)) as VoteEscrow;
    const voter = (await ethers.getContract("Voter", deployer)) as Voter;
    const gf = (await ethers.getContract("GaugeFactory", deployer)) as GaugeFactory;

    const tx = await gf.createMarketGauge(
      flywheel, // Flywheel Address
      ionicToken.address, // reward token
      ve.address, // VoteEscrow address
      BAL8020, // Lock token address
      voter.address // Distribution address (Voter)
    );

    await tx.wait();
    console.log(`creating market gauge tx: ${tx.hash}`);
  });
