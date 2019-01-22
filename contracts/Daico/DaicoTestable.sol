pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/token/ERC20/MintableToken.sol";

import "./Daico.sol";

contract DaicoTestable is Daico {

	constructor(
		address _daiTokenAddress,
		address _projectTokenAddress, 
		address _projectOwnerAddress,
		address _returnAddress,
		uint _tapsCount, 
		uint[] _tapAmounts, 
		uint[] _tapTimestampsFinishAt, 
		uint _minQuorumRate, 
		uint _minVoteRate
	) public Daico(
		_daiTokenAddress,
		_projectTokenAddress,
		_projectOwnerAddress,
		_returnAddress,
		_tapsCount,
		_tapAmounts,
		_tapTimestampsFinishAt,
		_minQuorumRate,
		_minVoteRate
	) {}

	function createVoting(uint _tapIndex, uint _quorumRate, uint _createdAt, uint _finishAt, VotingType _votingType) external {
		_createVoting(_tapIndex, _quorumRate, _createdAt, _finishAt, _votingType);
	}

}
