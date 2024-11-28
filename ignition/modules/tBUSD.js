const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("tBUSDModule", (m) => {

  const tBUSDContract = m.contract("tBUSD");

  return { tBUSDContract };
});
