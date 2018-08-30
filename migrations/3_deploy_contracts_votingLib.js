var DaoBaseWithUnpackers = artifacts.require("./DaoBaseWithUnpackers");
var GenericCaller = artifacts.require("./GenericCaller");
var GenericCallerLib = artifacts.require("./GenericCallerLib");
var Voting = artifacts.require("./Voting");
var VotingLib = artifacts.require("./VotingLib");
var DaoBaseAuto = artifacts.require("./DaoBaseAuto");
var BodDaoFactory = artifacts.require("./BodDaoFactory");
var HierarchyDaoFactory = artifacts.require("./HierarchyDaoFactory");
var DevZenDaoFactory = artifacts.require("./DevZenDaoFactory");

module.exports = function (deployer) {
	deployer.deploy(VotingLib).then(() => {
		deployer.link(VotingLib, Voting);
		deployer.link(VotingLib, GenericCaller);
		deployer.link(VotingLib, GenericCallerLib);
		deployer.link(VotingLib, DaoBaseAuto);

		deployer.link(VotingLib, BodDaoFactory);
		deployer.link(VotingLib, HierarchyDaoFactory);
		deployer.link(VotingLib, DevZenDaoFactory);			
	});
};
