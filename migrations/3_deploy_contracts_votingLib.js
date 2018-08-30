var DaoBaseWithUnpackers = artifacts.require("./DaoBaseWithUnpackers");
var GenericCaller = artifacts.require("./GenericCaller");
var GenericCallerLib = artifacts.require("./GenericCallerLib");
var Voting = artifacts.require("./Voting");
var VotingLib = artifacts.require("./VotingLib");
var DaoBaseAuto = artifacts.require("./DaoBaseAuto");

var BodDaoFactory = artifacts.require("./BodDaoFactory");
var HierarchyDaoFactory = artifacts.require("./HierarchyDaoFactory");
var DevZenDaoFactory = artifacts.require("./DevZenDaoFactory");
var DevZenDaoFactoryTestable = artifacts.require("./DevZenDaoFactoryTestable");
var DevZenDaoTestable = artifacts.require("./DevZenDaoTestable");
var DevZenDaoAuto = artifacts.require("./DevZenDaoAuto");
var DevZenDaoWithUnpackers = artifacts.require("./DevZenDaoWithUnpackers");
var DevZenDaoWithUnpackersTestable = artifacts.require("./DevZenDaoWithUnpackersTestable");

module.exports = function (deployer) {
	deployer.deploy(VotingLib).then(() => {
		deployer.link(VotingLib, Voting);
		deployer.link(VotingLib, GenericCaller);
		deployer.link(VotingLib, GenericCallerLib);
		deployer.link(VotingLib, DaoBaseAuto);

		deployer.link(VotingLib, DevZenDaoFactory);
		deployer.link(VotingLib, DevZenDaoFactoryTestable);
		deployer.link(VotingLib, DevZenDaoTestable);
		deployer.link(VotingLib, DevZenDaoAuto);
		deployer.link(VotingLib, DevZenDaoWithUnpackers);
		deployer.link(VotingLib, DevZenDaoWithUnpackersTestable);
	});
};
