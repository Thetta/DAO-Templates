pragma solidity ^0.4.24;


contract IDaico {
	enum TapStage {
		Preparing,
		Investing,
		Voting,
		VotingDQ,
		RoadmapPreparing,
		RoadmapVoting,
		RoadmapVotingDQ,
		Success,
		Terminated
	}

	function addInvestor(uint _amount, address _investorAddress) public;
	function returnTokens() public;
	function withdrawFundsFromTap(uint _tapNum) public;
	function vote(bool _vote) public;
	function proposeNewRoadmap(uint[] _tapFunds, uint[] _tapDurations) public;

	function getTapsInfo() public view returns(uint, TapStage[], uint);
}
