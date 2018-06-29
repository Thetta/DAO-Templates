var HierarchyDao = artifacts.require("HierarchyDao");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(HierarchyDao, accounts[0], accounts[1], accounts[2], accounts[3], accounts[4]);
};
