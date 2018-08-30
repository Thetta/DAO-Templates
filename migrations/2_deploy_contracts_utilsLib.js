var UtilsLib = artifacts.require("./UtilsLib");

//var DaoBase = artifacts.require("./DaoBase");
var DaoBaseWithUnpackers = artifacts.require("./DaoBaseWithUnpackers");
var GenericCaller = artifacts.require("./GenericCaller");
var GenericCallerLib = artifacts.require("./GenericCallerLib");
// var MoneyflowAuto = artifacts.require("./MoneyflowAuto");
var Voting = artifacts.require("./Voting");
var VotingLib = artifacts.require("./VotingLib");
var DaoBaseAuto = artifacts.require("./DaoBaseAuto");
var DaoStorage = artifacts.require("./DaoStorage");
var StdDaoToken = artifacts.require("./StdDaoToken");
var BodDaoFactory = artifacts.require("./BodDaoFactory");
var HierarchyDaoFactory = artifacts.require("./HierarchyDaoFactory");
var DevZenDaoFactory = artifacts.require("./DevZenDaoFactory");
var DevZenDaoFactoryTestable = artifacts.require("./DevZenDaoFactoryTestable");
var DevZenDaoTestable = artifacts.require("./DevZenDaoTestable");

module.exports = function (deployer) {
	deployer.deploy(UtilsLib).then(() => {
		deployer.link(UtilsLib, GenericCaller);
		deployer.link(UtilsLib, VotingLib);
		deployer.link(UtilsLib, DaoBaseAuto);
		deployer.link(UtilsLib, DaoStorage);
		deployer.link(UtilsLib, StdDaoToken);

		deployer.link(UtilsLib, BodDaoFactory);
		deployer.link(UtilsLib, HierarchyDaoFactory);
		deployer.link(UtilsLib, DevZenDaoFactoryTestable);
		deployer.link(UtilsLib, DevZenDaoTestable);

	});
};
