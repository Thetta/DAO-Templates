var DaoLib = artifacts.require("./DaoLib");
var DaoBase = artifacts.require("./DaoBase");
var DaoBaseWithUnpackers = artifacts.require("./DaoBaseWithUnpackers");
var BodDaoFactory = artifacts.require("./BodDaoFactory");
var HierarchyDaoFactory = artifacts.require("./HierarchyDaoFactory");
var DevZenDaoFactoryTestable = artifacts.require("./DevZenDaoFactoryTestable");

module.exports = function (deployer) {
	deployer.deploy(DaoLib).then(() => {
		deployer.link(DaoLib, DaoBase);
		deployer.link(DaoLib, DaoBaseWithUnpackers);
		deployer.link(DaoLib, BodDaoFactory);
		deployer.link(DaoLib, HierarchyDaoFactory);
		deployer.link(DaoLib, DevZenDaoFactoryTestable);
	});
};

