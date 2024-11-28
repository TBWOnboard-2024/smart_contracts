const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("PropertyModule", (m) => {

  const propertyContract = m.contract("RWA_RealEstate_NFT");

  return { propertyContract };
});
