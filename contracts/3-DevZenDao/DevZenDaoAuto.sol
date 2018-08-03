pragma solidity ^0.4.24;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoBaseAuto.sol";

import "./DevZenDaoCore.sol";

/**
 * @title DevZenDaoAuto
 * @dev This contract is a helper that will create new Proposal (i.e. voting) if the action is not allowed directly. 
*/
contract DevZenDaoAuto is DaoBaseAuto {

	constructor(IDaoBase _dao) public DaoBaseAuto(_dao) {}

	/**
	 * @dev Change the DAO parameters
	*/
	function updateDaoParamsAuto(DevZenDaoCore.Params _params) public returns(address proposalOut) {
		bytes32[] memory params = new bytes32[](8);
		params[0] = bytes32(_params.mintTokensPerWeekAmount);
		params[1] = bytes32(_params.mintReputationTokensPerWeekAmount);
		params[2] = bytes32(_params.oneTokenPriceInWei);
		params[3] = bytes32(_params.oneAdSlotPrice);
		params[4] = bytes32(_params.becomeGuestStake);
		params[5] = bytes32(_params.repTokensReward_Host);
		params[6] = bytes32(_params.repTokensReward_Guest);
		params[7] = bytes32(_params.repTokensReward_TeamMembers);

	   return doAction("DevZen_updateDaoParams", dao, msg.sender, "updateDaoParamsGeneric(bytes32[])", params);
	}

	/**
	 * @dev Withdraw all collected ETH to the _output.
	*/
	function withdrawEtherAuto(address _output) public returns(address proposalOut) {
		bytes32[] memory params = new bytes32[](1);
		params[0] = bytes32(_output);

		return doAction("DevZen_withdrawEther", dao, msg.sender, "withdrawEtherGeneric(bytes32[])", params);
	}

	/**
	 * @dev Select next episode's host
	*/
	function selectNextHostAuto(address _nextHost) public returns(address proposalOut) {
		bytes32[] memory params = new bytes32[](1);
		params[0] = bytes32(_nextHost);

		return doAction("DevZen_selectNextHost", dao, msg.sender, "selectNextHostGeneric(bytes32[])", params);
	}

	/**
	 * @dev Changes the guest in "legal" way
	 */
	function changeTheGuestAuto(address _guest) public returns(address proposalOut) {
		bytes32[] memory params = new bytes32[](1);
		params[0] = bytes32(_guest);

		return doAction("DevZen_changeGuest", dao, msg.sender, "changeTheGuestGeneric(bytes32[])", params);
	}

	/**
	 * @dev Set the guest (emergency)
	*/
	function emergency_ChangeTheGuestAuto(address _guest) public returns(address proposalOut) {
		bytes32[] memory params = new bytes32[](1);
		params[0] = bytes32(_guest);

		return doAction("DevZen_emergencyChangeGuest", dao, msg.sender, "emergency_ChangeTheGuestGeneric(bytes32[])", params);
	}

	/**
	 * @dev Move to next episode
	*/
	function moveToNextEpisodeAuto(bool _guestHasCome) public returns(address proposalOut) {
		bytes32[] memory params = new bytes32[](1);
		params[0] = bytes32(_guestHasCome ? uint(1) : uint(0));

		return doAction("DevZen_moveToNextExpisode", dao, msg.sender, "moveToNextEpisodeGeneric(bytes32[])", params);
	}

}
