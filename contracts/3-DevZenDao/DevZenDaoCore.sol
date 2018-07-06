pragma solidity ^0.4.22;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoBase.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";

/**
 * @title DevZenDaoCore
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
contract DevZenDaoCore is DaoBaseWithUnpackers {

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
		uint createdAt;
	}

	StdDaoToken public devZenToken;
	StdDaoToken public repToken;
	Params public params;
	NextEpisode public nextEpisode;

	constructor(StdDaoToken _devZenToken, StdDaoToken _repToken, DaoStorage _store, Params _params) public DaoBaseWithUnpackers(_store){
		devZenToken = _devZenToken;
		repToken = _repToken;
		params = _params;
	}

	// --------------------------------------------- 
	// These methods should be called by DevZen team:
	//----------------------------------------------

	/**
	 * @dev Change the DAO parameters
	 * This method should require voting!
	 * Notice: DevZen_updateDaoParams is a custom action!
	*/
	function _updateDaoParams(Params _params) internal onlyOwner {
		params = _params;
	}

	/**
	 * @dev Withdraw all collected ETH to the _output.
	 * This method should require voting!
	 * Notice: DevZen_withdrawEther is a custom action!
	*/
	function _withdrawEther(address _output) internal onlyOwner {
		// TODO: better to use moneyflow instead of _output
		// Specifying _output can lead to hacks and money loss!
		_output.transfer(address(this).balance);
	}

	/**
	 * @dev Select next episode's host
	 * This method should require voting!
	 * Notice: DevZen_selectNextHost is a custom action!
	*/
	function _selectNextHost(address _nextHost) internal onlyOwner {
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
	function _burnGuestStake() internal onlyOwner {
		// TODO:

	}

	/**
	 * @dev Set the guest (emergency)
	 * In normal circumst. people should use 'becomeTheNextShowGuest' method. 
	 * However, sometimes DevZen team should be able to fix the next guest!
	 * Notice: DevZen_emergencyChangeGuest is a custom action!
	*/
	function _emergency_ChangeTheGuest(address _guest) internal onlyOwner {
		nextEpisode.nextShowGuest = _guest;
	}

	/**
	 * @dev Move to next episode
	 * Should be called right AFTER the recording of the current episode
	 * Notice: DevZen_moveToNextExpisode is a custom action!
	*/
	function _moveToNextEpisode() internal onlyOwner {
		// 1 - check if 1 week is passed
		require(_isOneWeekPassed());

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
		nextEpisode.createdAt = now;

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

	// ------------------------------------------------------ 
	// These methods should be called by DevZen token holders
	// ------------------------------------------------------

	// Any patron (DevZen token holder) can use DevZen tokens to run ads: Burn k tokens to add your add into the slot (linear, no priority).
	function _runAdsInTheNextEpisode(string _adText) internal onlyOwner {
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

	function _becomeTheNextShowGuest() internal onlyOwner {
		require(devZenToken.balanceOf(msg.sender)!=0); 

		// 1 - check if guest is still not selected
		require(0x0==nextEpisode.nextShowGuest);

		// TODO: 
		// 2 - lock (stake/bond) tokens 

		// 3 - select next host
		nextEpisode.nextShowGuest = msg.sender;
	}

	// ---------------------------------------------- 
	// These methods should be called by any address:
	// ----------------------------------------------

	/**
	* @dev Any listener can get a ERC20 “devzen” tokens by sending X ETHers to the DevZen DAO and becomes a “patron” (i.e. token holder).
    */
	function _buyTokens() public payable onlyOwner {

		require(msg.value != 0);
		
		// 1 - calculate how many tokens msg.sender wants to buy (use oneTokenPriceInWei)
		uint tokensToPurchase = (msg.value / params.oneTokenPriceInWei) * 10**18;

		// 2 - check if this address holds enough tokens
		require(devZenToken.balanceOf(address(this)) >= tokensToPurchase);

		// 3 - if ok -> transfer tokens to the msg.sender
		devZenToken.transfer(msg.sender, tokensToPurchase);
	}

	/**
	 * @dev Check that 1 week has passed since the last episode
	 * @return true if 1 week has passed else false
	 */
	function _isOneWeekPassed() internal view onlyOwner returns(bool) {

		// return true is this is the 1st episode
		if(nextEpisode.createdAt == 0) return true;

		return nextEpisode.createdAt + 7 days <= now;
	}

	// do not allow to send ETH here. Instead use buyTokens method
	function(){
		revert();
	}

}
