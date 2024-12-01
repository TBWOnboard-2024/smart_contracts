const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("MarketplaceModule", (m) => {

  const marketplaceContract = m.contract("Marketplace_RealEstate");

  return { marketplaceContract };
});
