pragma solidity ^0.4.22;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoBase.sol";
import "@thetta/core/contracts/IDaoBase.sol";
import "@thetta/core/contracts/DaoStorage.sol";
import "@thetta/core/contracts/DaoBaseAuto.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";

import "./DevZenDao.sol";
import "./DevZenDaoAuto.sol";
import "./DevZenDaoCore.sol";

import "./DevZenDaoWithUnpackers.sol";

// DevZen tokens:
// 10 tokens for 5 ads slots
// 0 free floating tokens
// Reputation tokens:
// 2 tokens as reputation incentive for 1 host   
// 2 tokens as reputation incentive for 4 moderators
// 1 tokens as incentive for 1 guest

contract DevZenDaoFactory {
	DevZenDaoCore public devZenDao;
	DaoBase public daoBase;
	DaoStorage store;
	DevZenDaoAuto public aac;

	constructor(address _boss, address[] _devZenTeam) public{
		createDao(_boss, _devZenTeam);
		setupAac();
		daoBase.renounceOwnership();
	}

	function createDao(address _boss, address[] _devZenTeam) internal returns(address) {
		StdDaoToken devZenToken = new StdDaoToken("DevZenToken", "DZT", 18, true, true, 10**25);
		StdDaoToken repToken = new StdDaoToken("DevZenRepToken", "DZTREP", 18, true, true, 10**25);

		address[] tokens;
		tokens.push(address(devZenToken));
		tokens.push(address(repToken));
		store = new DaoStorage(tokens);
		daoBase = new DaoBase(store);

		DevZenDao.Params memory defaultParams;
		defaultParams.mintTokensPerWeekAmount = 10 * 10**18;
		defaultParams.mintReputationTokensPerWeekAmount = 5 * 10**18;
		defaultParams.oneAdSlotPrice = 2 * 10**18; // Current ETH price is ~$450. One token will be worth ~$45. One ad will cost ~$90 (2 tokens)
		defaultParams.oneTokenPriceInWei =  10**17; // To become a guest user should put 5 tokens at stake
		defaultParams.becomeGuestStake = 5 * 10**18;
		defaultParams.repTokensReward_Host = 2 * 10**18;
		defaultParams.repTokensReward_Guest = 1 * 10**18;
		defaultParams.repTokensReward_TeamMembers = 2 * 10**18;
		
		createNewContract(IDaoBase(daoBase), tokens, defaultParams);
		
		store.allowActionByAddress(daoBase.MANAGE_GROUPS(),address(this));
		store.allowActionByAddress(daoBase.ISSUE_TOKENS(),address(devZenDao));
		store.allowActionByAddress(daoBase.BURN_TOKENS(),address(devZenDao));
		store.transferOwnership(daoBase);
		devZenToken.transferOwnership(daoBase);
		repToken.transferOwnership(daoBase);

		daoBase.allowActionByAddress(devZenDao.DEV_ZEN_UPDATE_DAO_PARAMS(), address(devZenDao));
		daoBase.allowActionByAddress(devZenDao.DEV_ZEN_WITHDRAW_ETHER(), address(devZenDao));
		daoBase.allowActionByAddress(devZenDao.DEV_ZEN_SELECT_NEXT_HOST(), address(devZenDao));
		daoBase.allowActionByAddress(devZenDao.DEV_ZEN_BURN_GUEST_STAKE(), address(devZenDao));
		daoBase.allowActionByAddress(devZenDao.DEV_ZEN_CHANGE_GUEST(), address(devZenDao));
		daoBase.allowActionByAddress(devZenDao.DEV_ZEN_EMERGENCY_CHANGE_GUEST(), address(devZenDao));
		// daoBase.allowActionByAddress(devZenDao.DEV_ZEN_MOVE_TO_NEXT_EXPISODE(), address(devZenDao));
		// 2 - setup
		setPermissions(_boss, _devZenTeam);
		

		// 3 - return 
		// 
		return devZenDao;
	}

	function createNewContract(IDaoBase _daoBase, address[] _tokens, DevZenDao.Params _defaultParams) internal {
		devZenDao = new DevZenDaoWithUnpackers(_daoBase, _tokens, _defaultParams);
	}	

	function setPermissions(address _boss, address[] _devZenTeam) internal {
		// 1 - populate groups
		daoBase.addGroupMember("DevZenTeam", _boss);

		uint i = 0;
		for(i=0; i<_devZenTeam.length; ++i){
			daoBase.addGroupMember("DevZenTeam", _devZenTeam[i]);
		}

		// 1 - set DevZenTeam group permissions
		daoBase.allowActionByAnyMemberOfGroup(daoBase.ADD_NEW_PROPOSAL(),"DevZenTeam");
		daoBase.allowActionByVoting(daoBase.MANAGE_GROUPS(), devZenDao.repToken());
		daoBase.allowActionByVoting(daoBase.UPGRADE_DAO_CONTRACT(), devZenDao.repToken());
		
		// 2 - set custom DevZenTeam permissions
		daoBase.allowActionByVoting(devZenDao.DEV_ZEN_UPDATE_DAO_PARAMS(), devZenDao.repToken());
		daoBase.allowActionByVoting(devZenDao.DEV_ZEN_WITHDRAW_ETHER(), devZenDao.repToken());
		daoBase.allowActionByVoting(devZenDao.DEV_ZEN_SELECT_NEXT_HOST(), devZenDao.repToken());
		daoBase.allowActionByVoting(devZenDao.DEV_ZEN_BURN_GUEST_STAKE(), devZenDao.repToken());
		daoBase.allowActionByVoting(devZenDao.DEV_ZEN_CHANGE_GUEST(), devZenDao.repToken());
		daoBase.allowActionByVoting(devZenDao.DEV_ZEN_EMERGENCY_CHANGE_GUEST(), devZenDao.repToken());
		// daoBase.allowActionByVoting(devZenDao.DEV_ZEN_MOVE_TO_NEXT_EPISODE(), devZenDao.repToken());

		// DO NOT ALLOW to issueTokens even to DevZenTeam members!!!
		// devZenDao.allowActionByVoting(devZenDao.ISSUE_TOKENS(), devZenDao.repToken());
	}

	function setupAac() internal {
		// TODO: add all custom actions to the DaoBaseAuto derived contract

		aac = new DevZenDaoAuto(IDaoBase(daoBase), devZenDao);

		daoBase.allowActionByAddress(daoBase.ADD_NEW_PROPOSAL(), aac);
		daoBase.allowActionByAddress(daoBase.MANAGE_GROUPS(), aac);
		daoBase.allowActionByAddress(daoBase.UPGRADE_DAO_CONTRACT(), aac);
		
		daoBase.allowActionByAddress(devZenDao.DEV_ZEN_UPDATE_DAO_PARAMS(), aac);
		daoBase.allowActionByAddress(devZenDao.DEV_ZEN_WITHDRAW_ETHER(), aac);
		daoBase.allowActionByAddress(devZenDao.DEV_ZEN_SELECT_NEXT_HOST(), aac);
		daoBase.allowActionByAddress(devZenDao.DEV_ZEN_BURN_GUEST_STAKE(), aac);
		daoBase.allowActionByAddress(devZenDao.DEV_ZEN_CHANGE_GUEST(), aac);
		daoBase.allowActionByAddress(devZenDao.DEV_ZEN_EMERGENCY_CHANGE_GUEST(), aac);
		// daoBase.allowActionByAddress(devZenDao.DEV_ZEN_MOVE_TO_NEXT_EPISODE(), aac);

		uint VOTING_TYPE_1P1V = 1;
		aac.setVotingParams(daoBase.MANAGE_GROUPS(), VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams(daoBase.UPGRADE_DAO_CONTRACT(), VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		
		aac.setVotingParams(devZenDao.DEV_ZEN_UPDATE_DAO_PARAMS(), VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams(devZenDao.DEV_ZEN_WITHDRAW_ETHER(), VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams(devZenDao.DEV_ZEN_SELECT_NEXT_HOST(), VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams(devZenDao.DEV_ZEN_BURN_GUEST_STAKE(), VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams(devZenDao.DEV_ZEN_CHANGE_GUEST(), VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams(devZenDao.DEV_ZEN_EMERGENCY_CHANGE_GUEST(), VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		// aac.setVotingParams(devZenDao.DEV_ZEN_MOVE_TO_NEXT_EPISODE(), VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);

		// aac.transferOwnership(msg.sender);
	}

}
