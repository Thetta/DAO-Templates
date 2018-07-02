pragma solidity ^0.4.22;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoBase.sol";
import "@thetta/core/contracts/DaoBaseAuto.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";

/**
 * @title DevZenDao
 * @dev This is the DAO for russian most famous "for hard-core developers only" podcast. 
 *  I was a guest of show #198 (July 30, 2018)
 *  We discussed how Thetta can be applied to their structure. You can read the blog post here - TODO.
 * 
 * ## Requirements:
 *
 * 1) Any listener can get a ERC20 “devzen” tokens by sending X ETHers to the DevZen DAO and becomes a “patron” (i.e. token holder).
 * 2) Any patron can use DevZen tokens to run ads: Burn k tokens to add your add into the slot (linear, no priority).
 * 3) Any team member can use Reputation to govern the DAO, i.e., change the parameters. Also, reputation is used in the votes to select the next host and to add or remove moderator.
 * 4) To become a guest, a listener has to become a patron first (i.e., they have to buy some DevZen tokens), then they must stake S tokens for D days. After the show has ended, S tokens are returned to the patron. If the guest missed the show (that is bad), the tokens are burned.   
 * 
 * ## Token model (example):
 * 
 * DevZen tokens are minted each week:
 *		10 tokens for 5 ads slots
 *		0 free floating tokens
 * DevZen tokens are burned:
 *		2 tokens per 1 ads slot (if ads is running in the current episode)
 * Reputation tokens are minted each week:
 *		2 tokens as reputation incentive for 1 host   
 *		2 tokens as reputation incentive for 4 moderators
 *		1 tokens as incentive for 1 guest
*/
contract DevZenDao is DaoBaseWithUnpackers {
	struct Params {
		uint mintTokensPerWeekAmount;
		uint mintReputationTokensPerWeekAmount;
		uint oneTokenPriceInWei;
		uint oneAdSlotPrice;

		uint repTokensReward_Host;
		uint repTokensReward_Guest;
		uint repTokensReward_TeamMembers;		// for all team members! not for one member!
	}

	// this is changed each week in 'moveToNextEpisode' method
	struct NextEpisode {
		address nextShowHost;
		address nextShowGuest;

		address prevShowHost;
		address prevShowGuest;

		string[] adSlots;
		uint usedSlots;
	}

	StdDaoToken public devZenToken;
	StdDaoToken public repToken;
	Params public params;
	NextEpisode public nextEpisode;

// 
	constructor(StdDaoToken _devZenToken, StdDaoToken _repToken, DaoStorage _store, Params _params)public DaoBaseWithUnpackers(_store){
		devZenToken = _devZenToken;
		repToken = _repToken;
		params = _params;
	}

// These methods should be called by DevZen team:
	/**
	 * @dev Change the DAO parameters
	 * This method should require voting!
	 * Notice: DevZen_updateDaoParams is a custom action!
	*/
	function updateDaoParams(Params _params) isCanDo("DevZen_updateDaoParams") public {
		params = _params;
	}

	/**
	 * @dev Withdraw all collected ETH to the _output.
	 * This method should require voting!
	 * Notice: DevZen_withdrawEther is a custom action!
	*/
	function withdrawEther(address _output) isCanDo("DevZen_withdrawEther") public {
		// TODO: better to use moneyflow instead of _output
		// Specifying _output can lead to hacks and money loss!
		_output.transfer(address(this).balance);
	}

	/**
	 * @dev Select next episode's host
	 * This method should require voting!
	 * Notice: DevZen_selectNextHost is a custom action!
	*/
	function selectNextHost(address _nextHost) isCanDo("DevZen_selectNextHost") public {
		// 1 - check if host is still not selected
		require(0x0==nextEpisode.nextShowHost);

		// 2 - select next host
		nextEpisode.nextShowHost = _nextHost;
	}

	/**
	 * @dev Guest did not appear -> penalize hime) 
	 * This method should require voting!
	 * Notice: DevZen_selectNextHost is a custom action!
	*/
	function burnGuestStake() isCanDo("DevZen_burnGuestStake") public {
		// TODO:

	}

	/**
	 * @dev Set the guest (emergency)
	 * In normal circumst. people should use 'becomeTheNextShowGuest' method. 
	 * However, sometimes DevZen team should be able to fix the next guest!
	 * Notice: DevZen_emergencyChangeGuest is a custom action!
	*/
	function emergency_ChangeTheGuest(address _guest) isCanDo("DevZen_emergencyChangeGuest") public {
		nextEpisode.nextShowGuest = _guest;
	}

	/**
	 * @dev Move to next episode
	 * Should be called right AFTER the recording of the current episode
	 * Notice: DevZen_moveToNextExpisode is a custom action!
	*/
	function moveToNextEpisode() isCanDo("DevZen_moveToNextEpisode") public {
		// 1 - check if 1 week is passed
		require(isOneWeekPassed());

		// 2 - mint tokens 
		// We are minting X tokens to this address (to the DevZen DAO contract itself)
		// Current contract is the owner of the devZenToken contract, so it can do anything with it (mint/burn tokens)
		devZenToken.mint(address(this), params.mintTokensPerWeekAmount);
		repToken.mint(address(this), params.mintReputationTokensPerWeekAmount);

		// 3 - clear next host and next guest
		nextEpisode.prevShowHost = nextEpisode.nextShowHost;
		nextEpisode.prevShowGuest = nextEpisode.nextShowGuest;
		nextEpisode.nextShowHost = 0x0;
		nextEpisode.nextShowGuest = 0x0;
		nextEpisode.usedSlots = 0;

		// 4 - mint some reputation tokens to the Guest 
		repToken.mint(nextEpisode.prevShowGuest, params.repTokensReward_Guest);

		// 5 - mint some reputation tokens to the Host 
		repToken.mint(nextEpisode.prevShowHost, params.repTokensReward_Host);

		// TODO:
		/*
		// 6 - mint some reputation tokens to the rest of the DevZen team!
		uint teamMembers = getMembersCount("DevZenTeam");
		assert(teamMembers>=1);
		uint perMember = params.repTokensReward_TeamMembers / (teamMembers - 1); 
		for(uint i=0; i<teamMembers; ++i){
			// TODO: use daoBase.getMemberByIndex() method when it will be implemented!
			address member = 0x0;

			if(member!=nextEpisode.prevShowHost){
				repToken.mint(member, perMember);
			}
		}
		*/
	}

// These methods should be called by DevZen token holders

	// Any patron (DevZen token holder) can use DevZen tokens to run ads: Burn k tokens to add your add into the slot (linear, no priority).
	function runAdsInTheNextEpisode(string _adText) public {
		// 0 - check if we have available slot 
		require(nextEpisode.usedSlots<5);

		// 1 - check if msg.sender has oneAdSlotPrice tokens 
		require(devZenToken.balanceOf(msg.sender)!=0); 

		// 2 - burn his oneAdSlotPrice tokens 
		devZenToken.burn(msg.sender, params.oneAdSlotPrice);

		// 3 - add ad to the slot 
		nextEpisode.adSlots[nextEpisode.usedSlots] = _adText;
		nextEpisode.usedSlots++;
	}

	function becomeTheNextShowGuest() public {
		require(devZenToken.balanceOf(msg.sender)!=0); 

		// 1 - check if guest is still not selected
		require(0x0==nextEpisode.nextShowGuest);

		// TODO: 
		// 2 - lock (stake/bond) tokens 

		// 3 - select next host
		nextEpisode.nextShowGuest = msg.sender;
	}

// These methods should be called by any address:

   // Any listener can get a ERC20 “devzen” tokens by sending X ETHers to the DevZen DAO and becomes a “patron” (i.e. token holder).
	function buyTokens() public payable {
		// TODO:
		// 1 - check the msg.value and calculate how many tokens msg.sender wants to buy (use oneTokenPriceInWei)

		// 2 - check if this address holds enough tokens 

		// 3 - if ok -> transfer tokens to the msg.sender!
	}
//
	function isOneWeekPassed() public constant returns(bool){
		// TODO: 
		return false;
	}

	// do not allow to send ETH here. Instead use buyTokens method
	function(){
		revert();
	}
}

contract DevZenDaoFactory {
	DaoStorage store;

	DevZenDao public dao;
	DaoBaseAuto public aac;

	constructor(address _boss, address[] _devZenTeam) public{
		createDao(_boss, _devZenTeam);
		setupAac();
	}

	function createDao(address _boss, address[] _devZenTeam) internal returns(address) {
	   StdDaoToken devZenToken = new StdDaoToken("DevZenToken", "DZT", 18);
	   StdDaoToken repToken = new StdDaoToken("DevZenRepToken", "DZTREP", 18);

		address[] tokens;
		tokens.push(devZenToken);
		tokens.push(repToken);
		store = new DaoStorage(tokens);

		// DevZen tokens:
		// 10 tokens for 5 ads slots
		// 0 free floating tokens

		// Reputation tokens:
		// 2 tokens as reputation incentive for 1 host   
		// 2 tokens as reputation incentive for 4 moderators
		// 1 tokens as incentive for 1 guest
		DevZenDao.Params defaultParams;
		defaultParams.mintTokensPerWeekAmount = 10 * 10e18;
		defaultParams.mintReputationTokensPerWeekAmount = 5 * 10e18;
		defaultParams.oneAdSlotPrice = 2 * 10e18;
		// Current ETH price is ~$450. One token will be worth ~$45. One ad will cost ~$90 (2 tokens)
		defaultParams.oneTokenPriceInWei = 0.1 * 10e18;
		defaultParams.repTokensReward_Host = 2 * 10e18;
		defaultParams.repTokensReward_Guest = 1 * 10e18;
		defaultParams.repTokensReward_TeamMembers = 2 * 10e18;

		dao = new DevZenDao(devZenToken, repToken, store, defaultParams);

		store.allowActionByAddress(keccak256("manageGroups"),this);

		devZenToken.transferOwnership(dao);
		repToken.transferOwnership(dao);
		store.transferOwnership(dao);

		// 2 - setup
		setPermissions(_devZenTeam);

		// 3 - return 
		dao.transferOwnership(msg.sender);
		return dao;
	}

	function setPermissions(address[] _devZenTeam) internal {
		// 1 - populate groups
		uint i = 0;
		for(i=0; i<_devZenTeam.length; ++i){
			dao.addGroupMember("DevZenTeam", _devZenTeam[i]);
		}

		// 1 - set DevZenTeam group permissions
		dao.allowActionByAnyMemberOfGroup("addNewProposal","DevZenTeam");
		dao.allowActionByVoting("manageGroups", dao.repToken());
		dao.allowActionByVoting("modifyMoneyscheme", dao.repToken());
		dao.allowActionByVoting("upgradeDaoContract", dao.repToken());
		
		// 2 - set custom DevZenTeam permissions
		dao.allowActionByVoting("DevZen_updateDaoParams", dao.repToken());
		dao.allowActionByVoting("DevZen_withdrawEther", dao.repToken());
		dao.allowActionByVoting("DevZen_selectNextHost", dao.repToken());
		dao.allowActionByVoting("DevZen_burnGuestStake", dao.repToken());
		dao.allowActionByVoting("DevZen_emergencyChangeGuest", dao.repToken());
		dao.allowActionByVoting("DevZen_moveToNextEpisode", dao.repToken());

		// DO NOT ALLOW to issueTokens even to DevZenTeam members!!!
		// dao.allowActionByVoting("issueTokens", dao.repToken());
	}

	function setupAac() internal {
		// TODO: add all custom actions to the DaoBaseAuto derived contract

		aac = new DaoBaseAuto(IDaoBase(dao));

		dao.allowActionByAddress("addNewProposal", aac);

		dao.allowActionByAddress("manageGroups", aac);
		dao.allowActionByAddress("modifyMoneyscheme", aac);
		dao.allowActionByAddress("upgradeDaoContract", aac);
		dao.allowActionByAddress("DevZen_updateDaoParams", aac);
		dao.allowActionByAddress("DevZen_withdrawEther", aac);
		dao.allowActionByAddress("DevZen_selectNextHost", aac);
		dao.allowActionByAddress("DevZen_burnGuestStake", aac);
		dao.allowActionByAddress("DevZen_emergencyChangeGuest", aac);
		dao.allowActionByAddress("DevZen_moveToNextEpisode", aac);

		uint VOTING_TYPE_1P1V = 1;
		aac.setVotingParams("manageGroups", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("modifyMoneyscheme", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("upgradeDaoContract", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("DevZen_updateDaoParams", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("DevZen_withdrawEther", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("DevZen_selectNextHost", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("DevZen_burnGuestStake", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("DevZen_emergencyChangeGuest", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);
		aac.setVotingParams("DevZen_moveToNextEpisode", VOTING_TYPE_1P1V, bytes32(0), "DevZenTeam", bytes32(50), bytes32(50), 0);

		aac.transferOwnership(msg.sender);
	}
}

