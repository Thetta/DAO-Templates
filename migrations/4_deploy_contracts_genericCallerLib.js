var DaoBaseWithUnpackers = artifacts.require("./DaoBaseWithUnpackers");
var GenericCaller = artifacts.require("./GenericCaller");
var GenericCallerLib = artifacts.require("./GenericCallerLib");
var DaoBaseAuto = artifacts.require("./DaoBaseAuto");
var Voting = artifacts.require("./Voting");
var VotingLib = artifacts.require("./VotingLib");

module.exports = function (deployer) {
	deployer.deploy(GenericCallerLib).then(() => {
		deployer.link(GenericCallerLib, GenericCaller);
		deployer.link(GenericCallerLib, DaoBaseAuto);
	});
};
