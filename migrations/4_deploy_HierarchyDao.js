var StdDaoToken = artifacts.require("StdDaoToken");
var DaoStorage = artifacts.require("DaoStorage");
var DaoBase = artifacts.require("DaoBase");
var IDaoBase = artifacts.require("IDaoBase");
var DaoBaseAuto = artifacts.require("DaoBaseAuto");
var HierarchyDao = artifacts.require("HierarchyDao");
const { uintToBytes32, padToBytes, fromUtf8 } = require("../test/utils/helpers");

let mng1 = '0x5a2203e516d8f025eaa37d1f6d7f114ac654da05';
let mng2 = '0x9dc108ae0579a1c856b8eff862fcab76c6e6ee15';
let mng3 = '0x564dcf23922de39970b2b442b1a2de8d2fd25330';
let emp1 = '0xfac20ad5f3bfc1748235edf919d473272ca0fd55';
let emp2 = '0x38ed1a11e4f2fd85995a058e1f65d41a483a662a';
let emp3 = '0x92bc71cd9a9a6ad3a1dcacc2b8c9eab13f4d547e';

module.exports = function(deployer, network, accounts) {
	return deployer.then(async () => {	
		let token = await StdDaoToken.new("StdToken", "STD", 18, true, true, 100000000000000000000);
		let store = await DaoStorage.new([token.address]);
		let daoBase = await DaoBase.new(store.address);
		let hierarcyDao = await HierarchyDao.new(daoBase.address);

		await store.allowActionByAddress(await daoBase.MANAGE_GROUPS(), accounts[0]);
		await store.transferOwnership(daoBase.address);
		await token.transferOwnership(daoBase.address);

		await daoBase.addGroupMember("Managers", accounts[0]);
		await daoBase.addGroupMember("Employees", accounts[0]);

		await daoBase.allowActionByAddress(await daoBase.ISSUE_TOKENS(), accounts[0]); 
		await daoBase.allowActionByAddress(await daoBase.UPGRADE_DAO_CONTRACT(), accounts[0]);
		await daoBase.allowActionByAnyMemberOfGroup(await daoBase.ADD_NEW_PROPOSAL(), "Managers");
		await daoBase.allowActionByVoting(await daoBase.MANAGE_GROUPS(), token.address);

		await daoBase.addGroupMember("Managers", mng1);
		await daoBase.addGroupMember("Managers", mng2);
		await daoBase.addGroupMember("Managers", mng3);
		await daoBase.addGroupMember("Employees", emp1);
		await daoBase.addGroupMember("Employees", emp2);
		await daoBase.addGroupMember("Employees", emp3);

		let hierarchyDaoAuto = await DaoBaseAuto.new(daoBase.address);

		// set voring params 1 person 1 vote
		let VOTING_TYPE_1P1V = 1;
		await hierarchyDaoAuto.setVotingParams(await daoBase.MANAGE_GROUPS(), VOTING_TYPE_1P1V, uintToBytes32(0), fromUtf8("Managers"), uintToBytes32(50), uintToBytes32(50), 0);

		await daoBase.allowActionByAddress(await daoBase.ADD_NEW_PROPOSAL(), hierarchyDaoAuto.address);
		await daoBase.allowActionByAddress(await daoBase.MANAGE_GROUPS(), hierarchyDaoAuto.address);

		await hierarchyDaoAuto.transferOwnership(daoBase.address);
		await daoBase.renounceOwnership();
	});
};