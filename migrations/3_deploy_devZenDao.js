var DevZenDaoFactory = artifacts.require("DevZenDaoFactory");
var StdDaoToken = artifacts.require("StdDaoToken");
var DaoStorage = artifacts.require("DaoStorage");
var DaoBase = artifacts.require("DaoBase");
var IDaoBase = artifacts.require("IDaoBase");
var DaoBaseAuto = artifacts.require("DaoBaseAuto");
var DevZenDao = artifacts.require("DevZenDao");
var DevZenDaoAuto = artifacts.require("DevZenDaoAuto");
var DevZenDaoCore = artifacts.require("DevZenDaoCore");
var DevZenDaoWithUnpackers = artifacts.require("DevZenDaoWithUnpackers");
const { uintToBytes32, padToBytes, fromUtf8 } = require("../test/utils/helpers");

let emp1 = '0xfac20ad5f3bfc1748235edf919d473272ca0fd55';
let emp2 = '0x38ed1a11e4f2fd85995a058e1f65d41a483a662a';
let emp3 = '0x92bc71cd9a9a6ad3a1dcacc2b8c9eab13f4d547e';

module.exports = function(deployer, network, accounts) {
	return deployer.then(async () => {	
		let devZenToken = await StdDaoToken.new("DevZenToken", "DZT", 18, true, true, 100000000000000000000);
		let repToken = await StdDaoToken.new("DevZenRepToken", "DZTREP", 18, true, true, 100000000000000000000);
		let store = await DaoStorage.new([devZenToken.address, repToken.address]);
		let daoBase = await DaoBase.new(store.address);
		let devZenDao = await DevZenDaoWithUnpackers.new(daoBase.address, [devZenToken.address, repToken.address]);

		await store.allowActionByAddress(await daoBase.MANAGE_GROUPS(),accounts[0]);
		await store.allowActionByAddress(await daoBase.ISSUE_TOKENS(),devZenDao.address);
		await store.allowActionByAddress(await daoBase.BURN_TOKENS(),devZenDao.address);
		await store.allowActionByAddress(await devZenDao.DEV_ZEN_MOVE_TO_NEXT_EPISODE(), accounts[0]);
		await store.allowActionByAddress(await devZenDao.DEV_ZEN_UPDATE_DAO_PARAMS(), accounts[0]);
	
		// await await 2 - setup
		await store.addGroupMember(web3.sha3("DevZenTeam"), accounts[0]);
		await store.addGroupMember(web3.sha3("DevZenTeam"), emp1);
		await store.addGroupMember(web3.sha3("DevZenTeam"), emp2);
		await store.addGroupMember(web3.sha3("DevZenTeam"), emp3);

		await store.transferOwnership(daoBase.address);
		await devZenDao.setParam(await devZenDao.MINT_TOKENS_PER_WEEK_AMOUNT(), 10 * 1e18);
		await devZenDao.setParam(await devZenDao.MINT_REPUTATION_TOKENS_PER_WEEK_AMOUNT(), 5 * 1e18);
		await devZenDao.setParam(await devZenDao.ONE_AD_SLOT_PRICE(), 2 * 1e18); // Current ETH price is ~$450. One token will be worth ~$45. One ad will cost ~$90 (2 tokens)
		await devZenDao.setParam(await devZenDao.ONE_TOKEN_PRICE_IN_WEI(),  1e17); //) To become a guest user should put 5 tokens at stake
		
		await devZenDao.setParam(await devZenDao.BECOME_GUEST_STAKE(), 5 * 1e18);
		await devZenDao.setParam(await devZenDao.REP_TOKENS_REWARD_HOST(), 2 * 1e18);
		await devZenDao.setParam(await devZenDao.REP_TOKENS_REWARD_GUEST(), 1 * 1e18);
		await devZenDao.setParam(await devZenDao.REP_TOKENS_REWARD_TEAM_MEMBERS(), 2 * 1e18);

		await devZenToken.transferOwnership(daoBase.address);
		await repToken.transferOwnership(daoBase.address);

		// 1 - set DevZenTeam group permissions
		await daoBase.allowActionByAnyMemberOfGroup(await daoBase.ADD_NEW_PROPOSAL(),"DevZenTeam");
		await daoBase.allowActionByVoting(await daoBase.MANAGE_GROUPS(), repToken.address);
		await daoBase.allowActionByVoting(await daoBase.UPGRADE_DAO_CONTRACT(), repToken.address);
		
		// 2 - set custom DevZenTeam permissions
		await daoBase.allowActionByVoting(await devZenDao.DEV_ZEN_UPDATE_DAO_PARAMS(), repToken.address);
		await daoBase.allowActionByVoting(await devZenDao.DEV_ZEN_WITHDRAW_ETHER(), repToken.address);
		await daoBase.allowActionByVoting(await devZenDao.DEV_ZEN_SELECT_NEXT_HOST(), repToken.address);
		await daoBase.allowActionByVoting(await devZenDao.DEV_ZEN_BURN_GUEST_STAKE(), repToken.address);
		await daoBase.allowActionByVoting(await devZenDao.DEV_ZEN_CHANGE_GUEST(), repToken.address);
		await daoBase.allowActionByVoting(await devZenDao.DEV_ZEN_EMERGENCY_CHANGE_GUEST(), repToken.address);
		await daoBase.allowActionByVoting(await devZenDao.DEV_ZEN_MOVE_TO_NEXT_EPISODE(), repToken.address);
	
		let devZenDaoAuto = await DevZenDaoAuto.new(daoBase.address, devZenDao.address);

		await daoBase.allowActionByAddress(await daoBase.ADD_NEW_PROPOSAL(), devZenDaoAuto.address);
		await daoBase.allowActionByAddress(await daoBase.MANAGE_GROUPS(), devZenDaoAuto.address);
		await daoBase.allowActionByAddress(await daoBase.UPGRADE_DAO_CONTRACT(), devZenDaoAuto.address);
		
		await daoBase.allowActionByAddress(await devZenDao.DEV_ZEN_UPDATE_DAO_PARAMS(), devZenDaoAuto.address);
		await daoBase.allowActionByAddress(await devZenDao.DEV_ZEN_WITHDRAW_ETHER(), devZenDaoAuto.address);
		await daoBase.allowActionByAddress(await devZenDao.DEV_ZEN_SELECT_NEXT_HOST(), devZenDaoAuto.address);
		await daoBase.allowActionByAddress(await devZenDao.DEV_ZEN_BURN_GUEST_STAKE(), devZenDaoAuto.address);
		await daoBase.allowActionByAddress(await devZenDao.DEV_ZEN_CHANGE_GUEST(), devZenDaoAuto.address);
		await daoBase.allowActionByAddress(await devZenDao.DEV_ZEN_EMERGENCY_CHANGE_GUEST(), devZenDaoAuto.address);
		await daoBase.allowActionByAddress(await devZenDao.DEV_ZEN_MOVE_TO_NEXT_EPISODE(), devZenDaoAuto.address);

		let VOTING_TYPE_1P1V = 1;
		await devZenDaoAuto.setVotingParams(await daoBase.MANAGE_GROUPS(), VOTING_TYPE_1P1V, uintToBytes32(0), fromUtf8("DevZenTeam"), uintToBytes32(65), uintToBytes32(65), 0);
		await devZenDaoAuto.setVotingParams(await daoBase.UPGRADE_DAO_CONTRACT(), VOTING_TYPE_1P1V, uintToBytes32(0), fromUtf8("DevZenTeam"), uintToBytes32(65), uintToBytes32(65), 0);
		await devZenDaoAuto.setVotingParams(await devZenDao.DEV_ZEN_UPDATE_DAO_PARAMS(), VOTING_TYPE_1P1V, uintToBytes32(0), fromUtf8("DevZenTeam"), uintToBytes32(65), uintToBytes32(65), 0);
		await devZenDaoAuto.setVotingParams(await devZenDao.DEV_ZEN_WITHDRAW_ETHER(), VOTING_TYPE_1P1V, uintToBytes32(0), fromUtf8("DevZenTeam"), uintToBytes32(65), uintToBytes32(65), 0);
		await devZenDaoAuto.setVotingParams(await devZenDao.DEV_ZEN_SELECT_NEXT_HOST(), VOTING_TYPE_1P1V, uintToBytes32(0), fromUtf8("DevZenTeam"), uintToBytes32(65), uintToBytes32(65), 0);
		await devZenDaoAuto.setVotingParams(await devZenDao.DEV_ZEN_BURN_GUEST_STAKE(), VOTING_TYPE_1P1V, uintToBytes32(0), fromUtf8("DevZenTeam"), uintToBytes32(65), uintToBytes32(65), 0);
		await devZenDaoAuto.setVotingParams(await devZenDao.DEV_ZEN_CHANGE_GUEST(), VOTING_TYPE_1P1V, uintToBytes32(0), fromUtf8("DevZenTeam"), uintToBytes32(65), uintToBytes32(65), 0);
		await devZenDaoAuto.setVotingParams(await devZenDao.DEV_ZEN_EMERGENCY_CHANGE_GUEST(), VOTING_TYPE_1P1V, uintToBytes32(0), fromUtf8("DevZenTeam"), uintToBytes32(65), uintToBytes32(65), 0);
		await devZenDaoAuto.setVotingParams(await devZenDao.DEV_ZEN_MOVE_TO_NEXT_EPISODE(), VOTING_TYPE_1P1V, uintToBytes32(0), fromUtf8("DevZenTeam"), uintToBytes32(65), uintToBytes32(65), 0);

		await devZenDaoAuto.transferOwnership(daoBase.address);

		await daoBase.renounceOwnership();
	});
};