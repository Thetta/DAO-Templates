pragma solidity ^0.4.22;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoBase.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";

import "./DevZenDaoTestable.sol";

contract DevZenDaoFactoryTestable {
	
	DaoStorage store;

	DevZenDaoTestable public dao;

	constructor() public {
		createDao();
	}

	function createDao() internal returns(address) {
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
		DevZenDaoTestable.Params memory defaultParams;
		defaultParams.mintTokensPerWeekAmount = 10 * 10**18;
		defaultParams.mintReputationTokensPerWeekAmount = 5 * 10**18;
		defaultParams.oneAdSlotPrice = 2 * 10**18;
		// Current ETH price is ~$450. One token will be worth ~$45. One ad will cost ~$90 (2 tokens)
		defaultParams.oneTokenPriceInWei = 0.1 * 10**18;
		// To become a guest user should put 5 tokens at stake
		defaultParams.becomeGuestStake = 5 * 10**18;
		defaultParams.repTokensReward_Host = 2 * 10**18;
		defaultParams.repTokensReward_Guest = 1 * 10**18;
		defaultParams.repTokensReward_TeamMembers = 2 * 10**18;

		dao = new DevZenDaoTestable(devZenToken, repToken, store, defaultParams);

		devZenToken.transferOwnership(dao);
		repToken.transferOwnership(dao);
		store.transferOwnership(dao);

		// 3 - return 
		dao.transferOwnership(msg.sender);
		return dao;
	}

}
