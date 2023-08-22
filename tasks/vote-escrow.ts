import { task, types } from "hardhat/config";
import { VoteEscrow } from "../typechain/VoteEscrow";

// npx hardhat voter:factory --action 0 --gauge 0x000 --network chapel
export default task("ve:create-lock", "increase the max gas fees to speed up a tx")
  .addParam("signer", "The address of the current deployer", "deployer", types.string)
  .addParam("value", "Amount to deposit in wei", undefined, types.string)
  .addParam("duration", "Duration of lock in seconds", undefined, types.int)
  .addOptionalParam("address", "If creating a lock for another address", undefined, types.string)
  .setAction(async ({ signer, value, duration, address }, { ethers }) => {
    const deployer = await ethers.getNamedSigner(signer);
    const ve = (await ethers.getContract("VoteEscrow", deployer)) as VoteEscrow;

    let tx;
    if (address) {
      tx = await ve.create_lock_for(value, duration, address);
    } else {
      tx = await ve.create_lock(value, duration);
    }
    await tx.wait();
    console.log(`created lock for ${address || deployer.address} with ${value} for ${duration} seconds`);
  });

task("ve:withdraw", "Withdraw all tokens for `_tokenId`")
  .addParam("signer", "The address of the current deployer", "deployer", types.string)
  .addParam("tokenId", "ID of the NFT", undefined, types.int)
  .setAction(async ({ signer, tokenId }, { ethers, getChainId }) => {
    const deployer = await ethers.getNamedSigner(signer);

    const ve = (await ethers.getContract("VoteEscrow", deployer)) as VoteEscrow;
    const masterChainId = await ve.callStatic.masterChainId();
    const chainId = parseInt(await getChainId());
    if (chainId != masterChainId.toNumber()) throw new Error(`configure the max gas fees for the chain`);

    const tx = await ve.withdraw(tokenId);
    await tx.wait();
    console.log(`withdrawn ${tokenId} with tx: ${tx.hash}`);
  });

task("ve:merge", "Merge NFTs from an address to another")
  .addParam("signer", "The address of the current deployer", "deployer", types.string)
  .addParam("from", "Address from where to merge veNFT", undefined, types.string)
  .addParam("to", "Address to which to merge veNFT", undefined, types.string)
  .setAction(async ({ signer, from, to }, { ethers, getChainId }) => {
    const deployer = await ethers.getNamedSigner(signer);

    const ve = (await ethers.getContract("VoteEscrow", deployer)) as VoteEscrow;
    const masterChainId = await ve.callStatic.masterChainId();
    const chainId = parseInt(await getChainId());
    if (chainId != masterChainId.toNumber()) throw new Error(`configure the max gas fees for the chain`);

    const tx = await ve.merge(from, to);
    await tx.wait();
    console.log(`Merged from: ${from} to: ${to} with tx: ${tx.hash}`);
  });

task("ve:split", "Split NFTs into multiple NFTs")
  .addParam("signer", "The address of the current deployer", "deployer", types.string)
  .addParam("amounts", "String of amounts in % values in which to split them", undefined, types.string)
  .addParam("tokenId", "ID of the NFT", undefined, types.string)
  .setAction(async ({ signer, amounts, tokenId }, { ethers, getChainId }) => {
    const deployer = await ethers.getNamedSigner(signer);

    const ve = (await ethers.getContract("VoteEscrow", deployer)) as VoteEscrow;
    const masterChainId = await ve.callStatic.masterChainId();
    const chainId = parseInt(await getChainId());
    if (chainId != masterChainId.toNumber()) throw new Error(`configure the max gas fees for the chain`);

    const amountsArray = amounts.split(",").map((a: string) => parseInt(a));
    if (amountsArray.reduce((a: number, b: number) => a + b, 0) != 100) throw new Error(`amounts must add up to 100`);

    const tx = await ve.split(amounts, tokenId);
    await tx.wait();
    console.log(`Split NFT: ${tokenId} into positions: ${JSON.stringify(amountsArray)} with tx: ${tx.hash}`);
  });
