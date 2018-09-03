var DevZenDaoFactory = artifacts.require("DevZenDaoFactory");

module.exports = function(deployer, network, accounts) {
	deployer.deploy(DevZenDaoFactory, accounts[0], [accounts[1], accounts[2]]);
};