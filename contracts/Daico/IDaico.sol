pragma solidity ^0.4.24;


contract IDaico {
	function addInvestor(uint _amount, address _investorAddress) public;
	function vote(bool _vote) external;
	function proposeNewRoadmap(uint[] _tapFunds, uint[] _tapDurations) external;
}
