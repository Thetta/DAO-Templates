var BodDaoFactory = artifacts.require("BodDaoFactory");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(BodDaoFactory, accounts[0], [accounts[1], accounts[2]], [accounts[3], accounts[4]]);
};
