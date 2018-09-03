var DevZenDaoFactory = artifacts.require("DevZenDaoFactory");
var StdDaoToken = artifacts.require("StdDaoToken");
var DaoStorage = artifacts.require("DaoStorage");
var DaoBase = artifacts.require("DaoBase");

module.exports = function(deployer, network, accounts) {
	return deployer.then(async () => {
		let devZenToken = await StdDaoToken.new("DevZenToken", "DZT", 18, true, true, 1e25);
		let repToken = await StdDaoToken.new("DevZenRepToken", "DZTREP", 18, true, true, 1e25);
		let store = await DaoStorage.new([devZenToken.address, repToken.address]);
		let daoBase = await DaoBase.new(store.address);
	});
};