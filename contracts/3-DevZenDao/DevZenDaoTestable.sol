pragma solidity ^0.4.22;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoBase.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";

import "./DevZenDaoCore.sol";

/**
 * @title DevZenDaoTestable
 * @dev DevZenDaoTestable is for testing DevZenDaoCore.
 * The difference between DevZenDao and DevZenDaoTestable is that there are no Thetta's isCanDo() modifiers in DevZenDaoTestable
 * which helps in testing only the logic.
 */
contract DevZenDaoTestable is DevZenDaoCore {

	constructor(
		StdDaoToken _devZenToken, 
		StdDaoToken _repToken, 
		DaoStorage _store, 
		Params _params
	) public DevZenDaoCore(_devZenToken, _repToken, _store, _params) {}

	// --------------------------------------------- 
	// These methods should be called by DevZen team:
	//----------------------------------------------

	/**
	 * @dev Change the DAO parameters
	*/
	function updateDaoParams(Params _params) public {
		super._updateDaoParams(_params);
	}

	/**
	 * @dev Withdraw all collected ETH to the _output.
	*/
	function withdrawEther(address _output) public {
		super._withdrawEther(_output);
	}

	/**
	 * @dev Select next episode's host
	*/
	function selectNextHost(address _nextHost) public {
		super._selectNextHost(_nextHost);
	}

	/**
	 * @dev Guest did not appear -> penalize him) 
	*/
	function burnGuestStake() public {
		// TODO:
	}

	/**
	 * @dev Set the guest (emergency)
	 * In normal circumst. people should use 'becomeTheNextShowGuest' method. 
	 * However, sometimes DevZen team should be able to fix the next guest!
	*/
	function emergency_ChangeTheGuest(address _guest) public {
		super._emergency_ChangeTheGuest(_guest);
	}

	/**
	 * @dev Move to next episode
	 * Should be called right AFTER the recording of the current episode
	*/
	function moveToNextEpisode() public {
		super._moveToNextEpisode();
	}

	// ------------------------------------------------------ 
	// These methods should be called by DevZen token holders
	// ------------------------------------------------------

	// Any patron (DevZen token holder) can use DevZen tokens to run ads: Burn k tokens to add your add into the slot (linear, no priority).
	function runAdsInTheNextEpisode(string _adText) public {
		super._runAdsInTheNextEpisode(_adText);
	}

	function becomeTheNextShowGuest() public {
		super._becomeTheNextShowGuest();
	}

	// ---------------------------------------------- 
	// These methods should be called by any address:
	// ----------------------------------------------

	/**
	* @dev Any listener can get a ERC20 “devzen” tokens by sending X ETHers to the DevZen DAO and becomes a “patron” (i.e. token holder).
    */
	function buyTokens() external payable {
		super._buyTokens();
	}

	/**
	 * @dev Check that 1 week has passed since the last episode
	 * @return true if 1 week has passed else false
	 */
	function isOneWeekPassed() public view returns(bool) {
		return super._isOneWeekPassed();
	}

	// do not allow to send ETH here. Instead use buyTokens method
	function() {
		revert();
	}

}
