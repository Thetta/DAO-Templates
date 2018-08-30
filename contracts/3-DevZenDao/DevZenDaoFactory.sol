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

		daoBase.allowActionByAddress(keccak256("DevZen_updateDaoParams"), address(devZenDao));
		daoBase.allowActionByAddress(keccak256("DevZen_withdrawEther"), address(devZenDao));
		daoBase.allowActionByAddress(keccak256("DevZen_selectNextHost"), address(devZenDao));
		daoBase.allowActionByAddress(keccak256("DevZen_burnGuestStake"), address(devZenDao));
		daoBase.allowActionByAddress(keccak256("DevZen_changeGuest"), address(devZenDao));
		daoBase.allowActionByAddress(keccak256("DevZen_emergencyChangeGuest"), address(devZenDao));
		daoBase.allowActionByAddress(keccak256("DevZen_moveToNextExpisode"), address(devZenDao));
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
		daoBase.allowActionByAnyMemberOfGroup(keccak256("addNewProposal"),"DevZenTeam");
		daoBase.allowActionByVoting(keccak256("manageGroups"), devZenDao.repToken());
		daoBase.allowActionByVoting(keccak256("modifyMoneyscheme"), devZenDao.repToken());
		daoBase.allowActionByVoting(keccak256("upgradeDaoContract"), devZenDao.repToken());
		
		// 2 - set custom DevZenTeam permissions
		daoBase.allowActionByVoting(keccak256("DevZen_updateDaoParams"), devZenDao.repToken());
		daoBase.allowActionByVoting(keccak256("DevZen_withdrawEther"), devZenDao.repToken());
		daoBase.allowActionByVoting(keccak256("DevZen_selectNextHost"), devZenDao.repToken());
		daoBase.allowActionByVoting(keccak256("DevZen_burnGuestStake"), devZenDao.repToken());
		daoBase.allowActionByVoting(keccak256("DevZen_changeGuest"), devZenDao.repToken());
		daoBase.allowActionByVoting(keccak256("DevZen_emergencyChangeGuest"), devZenDao.repToken());
		daoBase.allowActionByVoting(keccak256("DevZen_moveToNextEpisode"), devZenDao.repToken());

		// DO NOT ALLOW to issueTokens even to DevZenTeam members!!!
		// devZenDao.allowActionByVoting(keccak256("issueTokens"), devZenDao.repToken());
	}

	function setupAac() internal {
		// TODO: add all custom actions to the DaoBaseAuto derived contract

		aac = new DevZenDaoAuto(IDaoBase(daoBase), devZenDao);

		// daoBase.allowActionByAddress(keccak256("addNewProposal"), aac);

		// daoBase.allowActionByAddress(keccak256("manageGroups"), aac);
		// daoBase.allowActionByAddress(keccak256("modifyMoneyscheme"), aac);
		// daoBase.allowActionByAddress(keccak256("upgradeDaoContract"), aac);
		// daoBase.allowActionByAddress(keccak256("DevZen_updateDaoParams"), aac);
		// daoBase.allowActionByAddress(keccak256("DevZen_withdrawEther"), aac);
		// daoBase.allowActionByAddress(keccak256("DevZen_selectNextHost"), aac);
		// daoBase.allowActionByAddress(keccak256("DevZen_burnGuestStake"), aac);
		// daoBase.allowActionByAddress(keccak256("DevZen_changeGuest"), aac);
		// daoBase.allowActionByAddress(keccak256("DevZen_emergencyChangeGuest"), aac);
		// daoBase.allowActionByAddress(keccak256("DevZen_moveToNextEpisode"), aac);

		// uint VOTING_TYPE_1P1V = 1;
		// aac.setVotingParams("manageGroups", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		// aac.setVotingParams("modifyMoneyscheme", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		// aac.setVotingParams("upgradeDaoContract", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		// aac.setVotingParams("DevZen_updateDaoParams", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		// aac.setVotingParams("DevZen_withdrawEther", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		// aac.setVotingParams("DevZen_selectNextHost", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		// aac.setVotingParams("DevZen_burnGuestStake", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		// aac.setVotingParams("DevZen_changeGuest", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		// aac.setVotingParams("DevZen_emergencyChangeGuest", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		// aac.setVotingParams("DevZen_moveToNextEpisode", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);

		// aac.transferOwnership(msg.sender);
	}

}
