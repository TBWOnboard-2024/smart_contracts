const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LockModule", (m) => {

  const propertyContract = m.contract("RWA_RealEstate_NFT");

  return { propertyContract };
});
