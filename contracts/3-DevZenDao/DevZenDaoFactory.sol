pragma solidity ^0.4.22;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoBase.sol";
import "@thetta/core/contracts/DaoBaseAuto.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";

import "./DevZenDao.sol";
import "./DevZenDaoCore.sol";

contract DevZenDaoFactory {
	DevZenDaoCore public dao;
	// DaoBaseAuto public aac;

	constructor(address _boss, address[] _devZenTeam) public{
		createDao(_boss, _devZenTeam);
		// setupAac();
	}

	function createDao(address _boss, address[] _devZenTeam) internal returns(address) {
		StdDaoToken devZenToken = new StdDaoToken("DevZenToken", "DZT", 18, true, true, 10**25);
		StdDaoToken repToken = new StdDaoToken("DevZenRepToken", "DZTREP", 18, true, true, 10**25);

		address[] tokens;
		tokens.push(address(devZenToken));
		tokens.push(address(repToken));

		// DevZen tokens:
		// 10 tokens for 5 ads slots
		// 0 free floating tokens

		// Reputation tokens:
		// 2 tokens as reputation incentive for 1 host   
		// 2 tokens as reputation incentive for 4 moderators
		// 1 tokens as incentive for 1 guest
		DevZenDao.Params memory defaultParams;
		defaultParams.mintTokensPerWeekAmount = 10 * 10**18;
		defaultParams.mintReputationTokensPerWeekAmount = 5 * 10**18;
		defaultParams.oneAdSlotPrice = 2 * 10**18;
		// Current ETH price is ~$450. One token will be worth ~$45. One ad will cost ~$90 (2 tokens)
		defaultParams.oneTokenPriceInWei =  10**17;
		// To become a guest user should put 5 tokens at stake
		defaultParams.becomeGuestStake = 5 * 10**18;
		defaultParams.repTokensReward_Host = 2 * 10**18;
		defaultParams.repTokensReward_Guest = 1 * 10**18;
		defaultParams.repTokensReward_TeamMembers = 2 * 10**18;
		
		createNewContract(tokens, defaultParams);

		dao.allowActionByAddress(keccak256("manageGroups"),this);

		devZenToken.transferOwnership(dao);
		repToken.transferOwnership(dao);

		// 2 - setup
		setPermissions(_boss, _devZenTeam);

		// 3 - return 
		dao.transferOwnership(msg.sender);
		return dao;
	}

	function createNewContract(address[] _tokens, DevZenDao.Params _defaultParams) internal {
		dao = new DevZenDao(_tokens, _defaultParams);
	}

	function setPermissions(address _boss, address[] _devZenTeam) internal {
		// 1 - populate groups
		dao.addGroupMember("DevZenTeam", _boss);

		uint i = 0;
		for(i=0; i<_devZenTeam.length; ++i){
			dao.addGroupMember("DevZenTeam", _devZenTeam[i]);
		}

		// 1 - set DevZenTeam group permissions
		dao.allowActionByAnyMemberOfGroup(keccak256("addNewProposal"),"DevZenTeam");
		dao.allowActionByVoting(keccak256("manageGroups"), dao.repToken());
		dao.allowActionByVoting(keccak256("modifyMoneyscheme"), dao.repToken());
		dao.allowActionByVoting(keccak256("upgradeDaoContract"), dao.repToken());
		
		// 2 - set custom DevZenTeam permissions
		dao.allowActionByVoting(keccak256("DevZen_updateDaoParams"), dao.repToken());
		dao.allowActionByVoting(keccak256("DevZen_withdrawEther"), dao.repToken());
		dao.allowActionByVoting(keccak256("DevZen_selectNextHost"), dao.repToken());
		dao.allowActionByVoting(keccak256("DevZen_burnGuestStake"), dao.repToken());
		dao.allowActionByVoting(keccak256("DevZen_changeGuest"), dao.repToken());
		dao.allowActionByVoting(keccak256("DevZen_emergencyChangeGuest"), dao.repToken());
		dao.allowActionByVoting(keccak256("DevZen_moveToNextEpisode"), dao.repToken());

		// DO NOT ALLOW to issueTokens even to DevZenTeam members!!!
		// dao.allowActionByVoting(keccak256("issueTokens"), dao.repToken());
	}

	/*function setupAac() internal {
		// TODO: add all custom actions to the DaoBaseAuto derived contract

		aac = new DaoBaseAuto(IDaoBase(dao));

		dao.allowActionByAddress(keccak256("addNewProposal"), aac);

		dao.allowActionByAddress(keccak256("manageGroups"), aac);
		dao.allowActionByAddress(keccak256("modifyMoneyscheme"), aac);
		dao.allowActionByAddress(keccak256("upgradeDaoContract"), aac);
		dao.allowActionByAddress(keccak256("DevZen_updateDaoParams"), aac);
		dao.allowActionByAddress(keccak256("DevZen_withdrawEther"), aac);
		dao.allowActionByAddress(keccak256("DevZen_selectNextHost"), aac);
		dao.allowActionByAddress(keccak256("DevZen_burnGuestStake"), aac);
		dao.allowActionByAddress(keccak256("DevZen_changeGuest"), aac);
		dao.allowActionByAddress(keccak256("DevZen_emergencyChangeGuest"), aac);
		dao.allowActionByAddress(keccak256("DevZen_moveToNextEpisode"), aac);

		uint VOTING_TYPE_1P1V = 1;
		aac.setVotingParams("manageGroups", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("modifyMoneyscheme", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("upgradeDaoContract", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("DevZen_updateDaoParams", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("DevZen_withdrawEther", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("DevZen_selectNextHost", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("DevZen_burnGuestStake", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("DevZen_changeGuest", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("DevZen_emergencyChangeGuest", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("DevZen_moveToNextEpisode", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);

		aac.transferOwnership(msg.sender);
	}*/

}
