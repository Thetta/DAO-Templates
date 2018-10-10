pragma solidity ^0.4.24;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoBase.sol";
import "@thetta/core/contracts/DaoClient.sol";
import "@thetta/core/contracts/DaoStorage.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
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
contract DevZenDaoCore is DaoClient {	
	StdDaoToken public devZenToken;
	StdDaoToken public repToken;
	NextEpisode public nextEpisode;

	bytes32 public constant DEV_ZEN_UPDATE_DAO_PARAMS = keccak256("DevZen_updateDaoParams");
	bytes32 public constant DEV_ZEN_WITHDRAW_ETHER = keccak256("DevZen_withdrawEther");
	bytes32 public constant DEV_ZEN_SELECT_NEXT_HOST = keccak256("DevZen_selectNextHost");
	bytes32 public constant DEV_ZEN_CHANGE_GUEST = keccak256("DevZen_changeGuest");
	bytes32 public constant DEV_ZEN_EMERGENCY_CHANGE_GUEST = keccak256("DevZen_emergencyChangeGuest");
	bytes32 public constant DEV_ZEN_MOVE_TO_NEXT_EPISODE = keccak256("DevZen_moveToNextEpisode");

	bytes32 public constant MINT_TOKENS_PER_WEEK_AMOUNT = 0xc9b51a76ddd807905ae4f432305a7941a6eeed3018a217456051bf48a64b23cc;
	bytes32 public constant MINT_REPUTATION_TOKENS_PER_WEEK_AMOUNT = 0xf62293a5f827624aae2cb3ccf2a626acfb00192eb976ac25c0b6fcfe9099f109;
	bytes32 public constant ONE_AD_SLOT_PRICE = 0x2fc30c0260b9c2120dbb43e5716b23b323cb0059511c89856fe497bcaf93cbe0;
	bytes32 public constant ONE_TOKEN_PRICE_IN_WEI = 0x1d18f55c54a96a26d4aaa596d526372f95c7cef9f217e9bbe766cea168596907;
	bytes32 public constant BECOME_GUEST_STAKE = 0x3016d4c48f6a1e0a92b321085915d5914a9ab2c36783443e2b6066054b37f7c4;
	bytes32 public constant REP_TOKENS_REWARD_HOST = 0x91a208a4a1aa03cdcf19de90fdf6add60ea8d103a63e151f2b189cc77dfc8cf7;
	bytes32 public constant REP_TOKENS_REWARD_GUEST = 0x9cf4c579edc10b766d99450c69f14a06144239d4923ded8d12e0a7d6ec69a048;
	bytes32 public constant REP_TOKENS_REWARD_TEAM_MEMBERS = 0x8097db39df04019c8a72c19c6369ebda43741c8e2a45d27badc3e4ff8ecc3d0b;

	event DevZenDaoCore_WithdrawEther(address _output);
	event DevZenDaoCore_SelectNextHost(address _nextHost);
	event DevZenDaoCore_ChangeTheGuest(address _guest);
	event DevZenDaoCore_BurnGuestStake();
	event DevZenDaoCore_Emergency_ChangeTheGuest(address _guest);
	event DevZenDaoCore_MoveToNextEpisode(bool _guestHasCome);
	event DevZenDaoCore_RunAdsInTheNextEpisode(string _adText);
	event DevZenDaoCore_BecomeTheNextShowGuest();
	event DevZenDaoCore_BuyTokens();
	event DevZenDaoCore_IsOneWeekPassed();
	event DevZenDaoCore_SetGuest(address _guest);

	event SetParam(bytes32 _param, uint _value);

	mapping (bytes32 => uint) public params;

	// this is changed each week in 'moveToNextEpisode' method
	struct NextEpisode {
		address nextShowHost;
		address nextShowGuest;
		address prevShowHost;
		address prevShowGuest;
		string[] adSlots;
		uint usedSlots;
		uint createdAt;
		bool isEmergencyGuest;
	}

	constructor(IDaoBase _daoBase, address[] _tokens) public DaoClient(_daoBase){
		devZenToken = StdDaoToken(_tokens[0]);
		repToken = StdDaoToken(_tokens[1]);
	}
	// --------------------------------------------- 
	// These methods should be called by DevZen team:
	//----------------------------------------------
	/**
	 * @dev Change the DAO parameters
	*/
	function _setParam(bytes32 _param, uint _value) internal  {
		emit SetParam(_param, _value);
		params[_param] = _value;
	}

	/**
	 * @dev Withdraw all collected ETH to the _output.
	*/
	function _withdrawEther(address _output) internal  {
		emit DevZenDaoCore_WithdrawEther(_output);
		// TODO: better to use moneyflow instead of _output
		// Specifying _output can lead to hacks and money loss!
		_output.transfer(address(this).balance);
	}

	/**
	 * @dev Select next episode's host
	*/
	function _selectNextHost(address _nextHost) internal  {
		emit DevZenDaoCore_SelectNextHost(_nextHost);
		// 1 - check if host is still not selected
		require(0x0==nextEpisode.nextShowHost);
		// 2 - select next host
		nextEpisode.nextShowHost = _nextHost;
	}

	/**
	 * @dev Guest did not appear -> penalize him) 
	*/
	function _burnGuestStake() internal  {
		emit DevZenDaoCore_BurnGuestStake();	
		daoBase.burnTokens(devZenToken, address(this), params[BECOME_GUEST_STAKE]);
	}

	/**
	 * @dev Changes the guest in "legal" way
	 * @param _guest New guest address
	 * When guest is changed via this function we ensure that stake is returned to previous guest.
	 */
	function _changeTheGuest(address _guest) internal  {
		emit DevZenDaoCore_ChangeTheGuest(_guest);
		// 0 - check that next show guest exists
		require(0x0 != nextEpisode.nextShowGuest);
		// 1 - save previous guest address for future use
		address prevGuest = nextEpisode.nextShowGuest;
		// 2 - set the new guest
		_setGuest(_guest);
		// 3 - if previous guest is not emergency guest then return stake
		if(!nextEpisode.isEmergencyGuest) {
			devZenToken.transfer(prevGuest, params[BECOME_GUEST_STAKE]);
		}
		// 4 - mark guest as legal
		nextEpisode.isEmergencyGuest = false;
	}

	/**
	 * @dev Set the guest (emergency)
	 * In normal circumst. people should use 'becomeTheNextShowGuest' method. 
	 * However, sometimes DevZen team should be able to fix the next guest!
	*/
	function _emergency_ChangeTheGuest(address _guest) internal  {
		// emit DevZenDaoCore_Emergency_ChangeTheGuest(_guest);
		// 1 - check that next show guest exists
		require(nextEpisode.nextShowGuest != 0x0);
		// 2 - set next show guest
		nextEpisode.nextShowGuest = _guest;
		// 3 - mark guest as emergency guest
		nextEpisode.isEmergencyGuest = true;
	}

	/**
	 * @dev Move to next episode
	 * @param _guestHasCome Whether the guest(initual or emergency) has come to the show
	 * Should be called right AFTER the recording of the current episode
	*/
	function _moveToNextEpisode(bool _guestHasCome) internal  {
		emit DevZenDaoCore_MoveToNextEpisode(_guestHasCome);
		// 1 - check if 1 week is passed
		require(_isOneWeekPassed());
		// 2 - mint tokens 
		// We are minting X tokens to this address (to the DevZen DAO contract itself)
		// Current contract is the owner of the devZenToken contract, so it can do anything with it (mint/burn tokens)
		daoBase.issueTokens(address(devZenToken), address(this), params[MINT_TOKENS_PER_WEEK_AMOUNT]);
		daoBase.issueTokens(address(repToken), address(this), params[MINT_REPUTATION_TOKENS_PER_WEEK_AMOUNT]);
		// 3 - clear next host and next guest
		nextEpisode.prevShowHost = nextEpisode.nextShowHost;
		nextEpisode.prevShowGuest = nextEpisode.nextShowGuest;
		nextEpisode.nextShowHost = 0x0;
		nextEpisode.nextShowGuest = 0x0;
		nextEpisode.usedSlots = 0;
		nextEpisode.createdAt = now;
		// 4 - mint DZTREP tokens to the Guest 
		if(_guestHasCome) {
			daoBase.issueTokens(address(repToken), nextEpisode.prevShowGuest, params[REP_TOKENS_REWARD_GUEST]);
		}
		// 5 - mint some reputation tokens to the Host 
		daoBase.issueTokens(address(repToken), nextEpisode.prevShowHost, params[REP_TOKENS_REWARD_HOST]);
		// TODO:
		// 6 - mint some reputation tokens to the rest of the DevZen team!
		uint teamMembers = daoBase.getMembersCount("DevZenTeam");
		assert(teamMembers>=1);
		uint perMember = params[REP_TOKENS_REWARD_TEAM_MEMBERS] / (teamMembers - 1); 
		address member;
		for(uint i=0; i<teamMembers; ++i){
			member = daoBase.getMemberByIndex("DevZenTeam", i);
			if(member!=nextEpisode.prevShowHost){
				daoBase.issueTokens(address(repToken), member, perMember);
			}
		}
		// 7 - recovering guests's stake
		if(_guestHasCome && !nextEpisode.isEmergencyGuest) {
			// if initial guest has come to the show then transfer DZT back
			devZenToken.transfer(nextEpisode.prevShowGuest, params[BECOME_GUEST_STAKE]);
		} else {
			// if there was a guest who has missed the show then burn his stake
			if(nextEpisode.prevShowGuest != 0x0) {
				_burnGuestStake();
			}
		}
		// 8 - clear guest's emergency
		nextEpisode.isEmergencyGuest = false;	
	}

	// ------------------------------------------------------ 
	// These methods should be called by DevZen token holders
	// ------------------------------------------------------

	// Any patron (DevZen token holder) can use DevZen tokens to run ads: Burn k tokens to add your add into the slot (linear, no priority).
	function _runAdsInTheNextEpisode(string _adText) internal  {
		emit DevZenDaoCore_RunAdsInTheNextEpisode(_adText);
		// 0 - check if we have available slot 
		require(nextEpisode.usedSlots<5);
		// 1 - check if msg.sender has oneAdSlotPrice tokens 
		require(devZenToken.balanceOf(msg.sender)!=0); 
		// 2 - burn his oneAdSlotPrice tokens 
		daoBase.burnTokens(devZenToken, msg.sender, params[ONE_AD_SLOT_PRICE]);
		// 3 - add ad to the slot 
		nextEpisode.adSlots.push(_adText);
		nextEpisode.usedSlots++;
	}

	/**
	 * @dev Become the next guest.
	 * To become a guest sender should buy 5 DZT and approve dao to put them at stake. Sender will get back tokens after the show.
	 */
	function _becomeTheNextShowGuest() internal {
		emit DevZenDaoCore_BecomeTheNextShowGuest();
		// 0 - check if guest is still not selected
		require(0x0 == nextEpisode.nextShowGuest);
		// 1 - set the sender as the new guest
		_setGuest(msg.sender);
	}

	// ---------------------------------------------- 
	// These methods should be called by any address:
	// ----------------------------------------------

	/**
	* @dev Any listener can get a ERC20 “devzen” tokens by sending X ETHers to the DevZen DAO and becomes a “patron” (i.e. token holder).
    */
	function _buyTokens() public payable {
		emit DevZenDaoCore_BuyTokens();
		require(msg.value != 0);		
		// 1 - calculate how many tokens msg.sender wants to buy (use oneTokenPriceInWei)

		uint tokensToPurchase = (msg.value*10**18)/ params[ONE_TOKEN_PRICE_IN_WEI];
		// 2 - check if this address holds enough tokens
		require(devZenToken.balanceOf(address(this)) >= tokensToPurchase);
		// 3 - if ok -> transfer tokens to the msg.sender
		devZenToken.transfer(msg.sender, tokensToPurchase);
	}

	/**
	 * @dev Check that 1 week has passed since the last episode
	 * @return true if 1 week has passed else false
	 */
	function _isOneWeekPassed() internal view  returns(bool) {
		emit DevZenDaoCore_IsOneWeekPassed();
		// return true if this is the 1st episode
		if(nextEpisode.createdAt == 0) return true;
		return nextEpisode.createdAt + 7 days <= now;
	}

	// do not allow to send ETH here. Instead use buyTokens method
	function(){
		revert();
	}

	//-----------------------------------------------
	// These are helper methods for usage in contract
	//-----------------------------------------------
	/**
	 * @dev Sets the guest for next show in "legal" way
	 * @param _guest New guest address
	 * New guest should have enough DZT and should allow current contract to transfer his stake
	 */
	function _setGuest(address _guest) internal {
		// emit DevZenDaoCore_SetGuest(_guest);
		// 0 - check that guest has required amount of tokens
		require(devZenToken.balanceOf(_guest) >= params[BECOME_GUEST_STAKE]); 
		// 1 - check that guest has allowed current contract to put 5 DZT at stake
		require(devZenToken.allowance(_guest, address(this)) >= params[BECOME_GUEST_STAKE]);
		// 3 - lock tokens, transfer tokens from guest to current contract
		devZenToken.transferFrom(_guest, address(this), params[BECOME_GUEST_STAKE]);
		// 4 - select next guest

		nextEpisode.nextShowGuest = _guest;
	}
}
