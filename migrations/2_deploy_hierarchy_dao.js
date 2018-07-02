var HierarchyDaoFactory = artifacts.require("HierarchyDaoFactory");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(HierarchyDaoFactory, accounts[0], [accounts[1], accounts[2]], [accounts[3], accounts[4]], [accounts[5], accounts[6]]);
};
