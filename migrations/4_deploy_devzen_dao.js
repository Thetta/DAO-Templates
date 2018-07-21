var DevZenDaoFactoryTestable = artifacts.require("DevZenDaoFactoryTestable");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(DevZenDaoFactoryTestable, accounts[0], [accounts[1], accounts[2]]);
};
