import { task, types } from "hardhat/config";
import { MockBridge } from "../typechain/MockBridge";

export default task("bridge:mint", "Mint NFT to address")
  .addParam("signer", "The address of the current deployer", "deployer", types.string)
  .addParam("to", "Amount to deposit in wei", undefined, types.string)
  .addParam("tokenId", "Token id", undefined, types.int)
  .addParam("amount", "Amount to mint", undefined, types.int)
  .addParam("timestamp", "Timestamp for the lock", undefined, types.int)
  .setAction(async ({ signer, to, tokenId, amount, timestamp }, { ethers }) => {
    const deployer = await ethers.getNamedSigner(signer);
    const mockBridge = (await ethers.getContract("MockBridge", deployer)) as MockBridge;

    const mintMetadata = ethers.utils.keccak256(
      new ethers.utils.AbiCoder().encode(["uint", "uint"], [amount.toString(), timestamp.toString()])
    );
    const tx = await mockBridge.mint(to, tokenId, mintMetadata);
    await tx.wait();
    console.log(`minted ${amount} for ${to} with tx: ${tx.hash}`);
  });

task("bridge:burn", "Mint NFT to address")
  .addParam("signer", "The address of the current deployer", "deployer", types.string)
  .addParam("tokenId", "Token id", undefined, types.int)
  .setAction(async ({ signer, tokenId }, { ethers }) => {
    const deployer = await ethers.getNamedSigner(signer);
    const mockBridge = (await ethers.getContract("MockBridge", deployer)) as MockBridge;

    const tx = await mockBridge.burn(tokenId);
    await tx.wait();
    console.log(`burned ${tokenId} with tx: ${tx.hash}`);
  });
