const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("PropertyModule", (m) => {

  const propertyContract = m.contract("Property_NFT");

  return { propertyContract };
});
