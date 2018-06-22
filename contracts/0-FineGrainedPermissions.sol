pragma solidity ^0.4.22;

import "../tokens/StdDaoToken.sol";

import "../IDaoBase.sol";

// This is an example of a more fine grained permissions.
// DaoBase allows us to permit 'issueTokens'/'burnTokens' only for all tokens at once. 
//
// So if you have 3 tokens (governance, rep, repdev) -> any member that can issueTokens 
// for 1st, will be able to issueTokens for the 2nd, etc. 
// 
// Imagine you want:
//		1. create your own more fine grained permissions - issueTokensGovr, issueTokensRep, issueTokensRepDev
//		2. to permit issueTokensGovr to CEO
//		3. to permit issueTokensRep tnd issueTokensRepDev to Managers
// 
// This contract shows how to do that:
contract ExampleOfFineGrainedPerms is DaoClient {
	StdDaoToken public tokenGovernance;
	// Generic reputation
	StdDaoToken public tokenReputation;
	// Reputation for Devs
	StdDaoToken public tokenReputationDev;

////
	constructor(IDaoBase _dao) public DaoClient(_dao){
		// 1 - create tokens 
		tokenGovernance = new StdDaoToken("YourDaoGovToken","GOV",18);
		tokenReputation = new StdDaoToken("YourDaoRepToken","REP",18);
		tokenReputationDev = new StdDaoToken("YourDaoRepDevToken","REPD",18);

		// 2 - transfer ownership to the Dao
		tokenGovernance.transferOwnership(dao);
		tokenReputation.transferOwnership(dao);
		tokenReputationDev.transferOwnership(dao);
	}

// ACTIONS: 
	function issueTokensGovr(address _to, uint _amount) external isCanDo("CUSTOM_issueTokensGovr"){
		// you should grant issueTokens permission to THIS contract
		dao.issueTokens(tokenGovernance, _to, _amount);
	}

	function issueTokensRep(address _to, uint _amount) external isCanDo("CUSTOM_issueTokensRep"){
		// you should grant issueTokens permission to THIS contract
		dao.issueTokens(tokenReputation, _to, _amount);
	}

	function issueTokensRepDev(address _to, uint _amount) external isCanDo("CUSTOM_issueTokensRepDev"){
		// you should grant issueTokens permission to THIS contract
		dao.issueTokens(tokenReputationDev, _to, _amount);
	}
}
