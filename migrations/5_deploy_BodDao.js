var StdDaoToken = artifacts.require("StdDaoToken");
var DaoStorage = artifacts.require("DaoStorage");
var DaoBase = artifacts.require("DaoBase");
var IDaoBase = artifacts.require("IDaoBase");
var DaoBaseAuto = artifacts.require("DaoBaseAuto");
var BodDao = artifacts.require("BodDao");
const { uintToBytes32, padToBytes, fromUtf8 } = require("../test/utils/helpers");

let dir1 = '0x5a2203e516d8f025eaa37d1f6d7f114ac654da05';
let dir2 = '0x9dc108ae0579a1c856b8eff862fcab76c6e6ee15';
let dir3 = '0x564dcf23922de39970b2b442b1a2de8d2fd25330';
let emp1 = '0xfac20ad5f3bfc1748235edf919d473272ca0fd55';
let emp2 = '0x38ed1a11e4f2fd85995a058e1f65d41a483a662a';
let emp3 = '0x92bc71cd9a9a6ad3a1dcacc2b8c9eab13f4d547e';

module.exports = function(deployer, network, accounts) {
	return deployer.then(async () => {	
		let token = await deployer.deploy(StdDaoToken, "StdToken", "STD", 18, true, true, 100000000000000000000);
		let store = await deployer.deploy(DaoStorage, [token.address]);
		let daoBase = await deployer.deploy(DaoBase, store.address);
		let bodDao = await deployer.deploy(BodDao, daoBase.address);

		await store.allowActionByAddress(await daoBase.MANAGE_GROUPS(), accounts[0]);

		await token.transferOwnership(daoBase.address);
		await store.transferOwnership(daoBase.address);

		await daoBase.addGroupMember("BoD", accounts[0]);
		await daoBase.addGroupMember("Employees", accounts[0]);

		daoBase.allowActionByAnyMemberOfGroup(await daoBase.ADD_NEW_PROPOSAL(), "BoD");
		daoBase.allowActionByVoting(await daoBase.MANAGE_GROUPS(), token.address);
		daoBase.allowActionByVoting(await daoBase.ISSUE_TOKENS(), token.address);
		daoBase.allowActionByVoting(await daoBase.UPGRADE_DAO_CONTRACT(), token.address);

		await daoBase.addGroupMember("BoD", dir1);
		await daoBase.addGroupMember("BoD", dir2);
		await daoBase.addGroupMember("BoD", dir3);
		await daoBase.addGroupMember("Employees", emp1);
		await daoBase.addGroupMember("Employees", emp2);
		await daoBase.addGroupMember("Employees", emp3);
	
		let bodDaoAuto = await deployer.deploy(DaoBaseAuto, daoBase.address);

		let VOTING_TYPE_1P1V = 1;
		await bodDaoAuto.setVotingParams(await daoBase.MANAGE_GROUPS(), VOTING_TYPE_1P1V, uintToBytes32(0), fromUtf8("BoD"), uintToBytes32(49), uintToBytes32(49), 0);
		await bodDaoAuto.setVotingParams(await daoBase.ISSUE_TOKENS(), VOTING_TYPE_1P1V, uintToBytes32(0), fromUtf8("BoD"), uintToBytes32(49), uintToBytes32(49), 0);
		await bodDaoAuto.setVotingParams(await daoBase.UPGRADE_DAO_CONTRACT(), VOTING_TYPE_1P1V, uintToBytes32(0), fromUtf8("BoD"), uintToBytes32(49), uintToBytes32(49), 0);
		
		await daoBase.allowActionByAddress(await daoBase.MANAGE_GROUPS(), bodDaoAuto.address);
		await daoBase.allowActionByAddress(await daoBase.ISSUE_TOKENS(), bodDaoAuto.address);
		await daoBase.allowActionByAddress(await daoBase.ADD_NEW_PROPOSAL(), bodDaoAuto.address);

		await bodDaoAuto.transferOwnership(daoBase.address);
		await daoBase.renounceOwnership();
	});
};