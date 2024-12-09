const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("Marketplace_2_Module", (m) => {

  const marketplace_2_Contract = m.contract("FractionalOwnershipMarketplace");

  return { marketplace_2_Contract };
});
