var DaoBaseWithUnpackers = artifacts.require("./DaoBaseWithUnpackers");
var GenericCaller = artifacts.require("./GenericCaller");
var GenericCallerLib = artifacts.require("./GenericCallerLib");
var DaoBaseAuto = artifacts.require("./DaoBaseAuto");
var Voting = artifacts.require("./Voting");
var VotingLib = artifacts.require("./VotingLib");

var BodDaoFactory = artifacts.require("./BodDaoFactory");
var HierarchyDaoFactory = artifacts.require("./HierarchyDaoFactory");
var DevZenDaoFactory = artifacts.require("./DevZenDaoFactory");
var DevZenDaoFactoryTestable = artifacts.require("./DevZenDaoFactoryTestable");
var DevZenDaoTestable = artifacts.require("./DevZenDaoTestable");
var DevZenDaoAuto = artifacts.require("./DevZenDaoAuto");
var DevZenDaoWithUnpackers = artifacts.require("./DevZenDaoWithUnpackers");
var DevZenDaoWithUnpackersTestable = artifacts.require("./DevZenDaoWithUnpackersTestable");
var DevZenDaoAutoTestable = artifacts.require("./DevZenDaoAutoTestable");

module.exports = function (deployer) {
	deployer.deploy(GenericCallerLib).then(() => {
		deployer.link(GenericCallerLib, GenericCaller);
		deployer.link(GenericCallerLib, DaoBaseAuto);
		deployer.link(GenericCallerLib, BodDaoFactory);
		deployer.link(GenericCallerLib, HierarchyDaoFactory);
		deployer.link(GenericCallerLib, DevZenDaoFactory);
		deployer.link(GenericCallerLib, DevZenDaoFactoryTestable);
		deployer.link(GenericCallerLib, DevZenDaoTestable);
		deployer.link(GenericCallerLib, DevZenDaoAuto);
		deployer.link(GenericCallerLib, DevZenDaoWithUnpackers);
		deployer.link(GenericCallerLib, DevZenDaoWithUnpackersTestable);
		deployer.link(GenericCallerLib, DevZenDaoAutoTestable);		
	});
};
