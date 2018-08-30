var DaoBaseLib = artifacts.require("./DaoBaseLib");
var DaoBase = artifacts.require("./DaoBase");
var DaoBaseWithUnpackers = artifacts.require("./DaoBaseWithUnpackers");
var BodDaoFactory = artifacts.require("./BodDaoFactory");
var HierarchyDaoFactory = artifacts.require("./HierarchyDaoFactory");
var DevZenDaoFactory = artifacts.require("./DevZenDaoFactory");
var DevZenDaoFactoryTestable = artifacts.require("./DevZenDaoFactoryTestable");
var DevZenDaoTestable = artifacts.require("./DevZenDaoTestable");

module.exports = function (deployer) {
	deployer.deploy(DaoBaseLib).then(() => {
		deployer.link(DaoBaseLib, DaoBase);
		deployer.link(DaoBaseLib, DaoBaseWithUnpackers);
		deployer.link(DaoBaseLib, BodDaoFactory);
		deployer.link(DaoBaseLib, HierarchyDaoFactory);
		deployer.link(DaoBaseLib, DevZenDaoFactory);

		deployer.link(DaoBaseLib, DevZenDaoFactoryTestable);
		deployer.link(DaoBaseLib, DevZenDaoTestable);		
	});
};

