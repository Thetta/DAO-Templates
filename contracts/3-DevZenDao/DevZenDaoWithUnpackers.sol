pragma solidity ^0.4.24;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "./DevZenDao.sol";

/**
 * @title DevZenDaoWithUnpackers
 * @dev This contract describes methods that can be called automatically from DaoBaseAuto in result of a voting.
 * It features method unpackers that will convert bytes32[] params to the method params.
 *
 * When DaoBaseAuto creates voting/proposal -> it packs params into the bytes32[]
 * After voting is finished -> target method is called and params should be unpacked
 */
contract DevZenDaoWithUnpackers is DevZenDao {

	constructor(
		StdDaoToken _devZenToken, 
		StdDaoToken _repToken, 
		DaoStorage _store, 
		Params _params
	) public DevZenDao(_devZenToken, _repToken, _store, _params) {}

	/**
	 * @dev Change the DAO parameters
	*/
	function updateDaoParamsGeneric(bytes32[] _params) external {
		Params memory params = Params({
			mintTokensPerWeekAmount: uint(_params[0]),
			mintReputationTokensPerWeekAmount: uint(_params[1]),
			oneTokenPriceInWei: uint(_params[2]),
			oneAdSlotPrice: uint(_params[3]),
			becomeGuestStake: uint(_params[4]),
			repTokensReward_Host: uint(_params[5]),
			repTokensReward_Guest: uint(_params[6]),
			repTokensReward_TeamMembers: uint(_params[7])
		});
		updateDaoParams(params);
	}

	/**
	 * @dev Withdraw all collected ETH to the _output
	*/
	function withdrawEtherGeneric(bytes32[] _params) external {
		address output = address(_params[0]);
		withdrawEther(output);
	}

	/**
	 * @dev Select next episode's host
	*/
	function selectNextHostGeneric(bytes32[] _params) external {
		address nextHost = address(_params[0]);
		selectNextHost(nextHost);
	}

	/**
	 * @dev Changes the guest in "legal" way
	 */
	function changeTheGuestGeneric(bytes32[] _params) external {
		address guest = address(_params[0]);
		changeTheGuest(guest);
	}

	/**
	 * @dev Set the guest (emergency)
	*/
	function emergency_ChangeTheGuestGeneric(bytes32[] _params) external {
		address guest = address(_params[0]);
		emergency_ChangeTheGuest(guest);
	}

	/**
	 * @dev Move to next episode
	*/
	function moveToNextEpisodeGeneric(bytes32[] _params) external {
		bool guestHasCome = uint(_params[0]) == 1 ? true : false;
		moveToNextEpisode(guestHasCome);
	}

}