pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./IDaico.sol";

contract Daico is IDaico {
	using SafeMath for uint;

	event InvestEvent(uint _amount, address _sender, uint _total, uint _tapSum, uint _startedAt);
	event Vote(uint _amount, address _sender, bool _vote);

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

	// Voting result
	enum VR { 
		NoResult,
		NoCons,
		Success,
		Decline
	}

	uint votesD = 7 days;
	uint addVotesD = 7 days;
	uint investD = 7 days;
	uint roadmapD = 21 days;
	uint infinity = 99999 days;

	uint quorumPercent = 70;
	uint declinePercent = 80;
	uint consensusPercent = 70;

	address owner;
	address STOContractAddress;
	ERC20 daiToken;
	uint createdAt;
	uint startedAt;
	bool newRoadmapProposed;
	uint roadmapsCount;
	mapping(uint=>uint) tapToRId; // tapId -> roadmapId
	mapping(uint=>Roadmap) roadmaps; // roadmapId -> roadmap


	struct Roadmap {
		uint tapsCount;
		uint investorsCount;
		mapping(uint=>Tap) taps;
		mapping(uint=>Investor) investors;
	}

	struct Investor {
		address addr;
		uint invested;
	}

	struct Tap {
		uint funds;
		uint duration;
		bool isWithdrawed;
		mapping(uint => Voting) votings; // 0, 1, 2, 3 – max
	}

	struct Voting {
		uint pro;
		uint versus;
		address[] voted;
	}	

	constructor(
		address _owner, 
		address _daiToken,
		address _STOContractAddress, 
		address _returnAddress,
		uint[] memory _tapFunds, 
		uint[] memory _tapDurations) public 
	{
		require(_tapFunds.length == _tapDurations.length);
		STOContractAddress = _STOContractAddress;
		daiToken = ERC20(_daiToken);
		owner = _owner;
		createdAt = now;

		roadmaps[roadmapsCount].tapsCount = _tapFunds.length;
		Tap memory tap;
		for(uint tapFundsNum = 0; tapFundsNum < _tapFunds.length; tapFundsNum++) {
			require(_tapDurations[tapFundsNum] > 7);
			tapToRId[tapFundsNum] = 0; // just for clearness;
	
			tap.funds = _tapFunds[tapFundsNum];
			tap.duration = _tapDurations[tapFundsNum]*(1 days);
			tap.isWithdrawed = false;
			roadmaps[roadmapsCount].taps[tapFundsNum] = tap;
		}
		roadmapsCount += 1;
	}

	function getCurrentTapNum() internal view returns(uint) {
		(uint curTapNum, TapStage[] memory tapStages, uint v) = getTapsInfo();
		return curTapNum;
	}

	function getMaximalTapsLength() internal view returns(uint maximal) {
		for(uint rmNum = 0; rmNum < roadmapsCount; rmNum++) {
			if(roadmaps[rmNum].tapsCount > maximal) {
				maximal = roadmaps[rmNum].tapsCount;
			}
		}
	}		
	
	function replaceRoadmapToProposedOne() internal {
		uint curTapNum = getCurrentTapNum();
		for(uint tapNum = 0; tapNum < roadmaps[roadmapsCount - 1].tapsCount; tapNum++) {
			if(tapNum > curTapNum)  tapToRId[tapNum] = roadmapsCount - 1;
		}
	}

	function addInvestor(uint _amount, address _investorAddress) public {
		require(STOContractAddress == msg.sender);
		(uint curTapNum, TapStage[] memory tapStages, uint votNum) = getTapsInfo();
		require(tapStages[curTapNum] == TapStage.Investing);
		require(_amount > 0);
		

		if(newRoadmapProposed) replaceRoadmapToProposedOne(); curTapNum += 1;

		uint rmNum = tapToRId[curTapNum];
		uint invId = getInvestorId(_investorAddress);

		require(amountOfAllInvestments(curTapNum) + _amount <= tapAmountsSum(curTapNum));
		daiToken.transferFrom(STOContractAddress, address(this), _amount);

		bool notInvestor = (invId == roadmaps[rmNum].investorsCount);
		if(notInvestor) {
			uint invCount = roadmaps[rmNum].investorsCount;
			roadmaps[rmNum].investors[invCount] = Investor(_investorAddress, _amount);
			roadmaps[rmNum].investorsCount += 1;
		} else {
			roadmaps[rmNum].investors[invId].invested += _amount;
		}

		
		if(areAllFundsCollected(curTapNum) && (startedAt==0)) {
			startedAt = now;
			newRoadmapProposed = false;
		}

		emit InvestEvent(_amount, _investorAddress, amountOfAllInvestments(curTapNum), tapAmountsSum(curTapNum), startedAt);
	}

	function areAllFundsCollected(uint _tapNum) internal view returns(bool) {
		return amountOfAllInvestments(_tapNum) >= tapAmountsSum(_tapNum);
	}

	function amountOfAllInvestments(uint _tapNum) public view returns(uint sum) {
		uint rmNum = tapToRId[_tapNum];
		uint invCount = roadmaps[rmNum].investorsCount;
		for(uint invNum = 0; invNum < invCount; invNum++) {
			sum += roadmaps[rmNum].investors[invNum].invested;
		}
	}

	function tapAmountsSum(uint _tapNum) public view returns(uint sum) {
		uint rmNum = tapToRId[_tapNum];
		uint tapsCount = roadmaps[rmNum].tapsCount;
		for(uint tapNum = 0; tapNum < tapsCount; tapNum++) {
			sum += roadmaps[rmNum].taps[tapNum].funds;
		}
	}

	function returnTokens() external {
		(uint curTapNum, TapStage[] memory tapStages, uint votNum) = getTapsInfo();
		uint rmNum = tapToRId[curTapNum];
		require(tapStages[curTapNum] == TapStage.Terminated);			

		uint remainder = daiToken.balanceOf(address(this));
		uint part;
		Investor memory investor;

		for(uint invNum = 0; invNum <roadmaps[rmNum].investorsCount; invNum++) {
			investor = roadmaps[rmNum].investors[invNum];
			part = ((investor.invested * remainder) / amountOfAllInvestments(curTapNum));
			daiToken.transfer(investor.addr, part);
		}
	}

	// Функция для снятия средств owner'ом.
	function withdrawFundsFromTap(uint _tapNum) external {
		require(msg.sender == owner);

		(uint curTapNum, TapStage[] memory tapStages, uint votNum) = getTapsInfo();
		require(tapStages[_tapNum] == TapStage.Success);

		roadmaps[tapToRId[curTapNum]].taps[_tapNum].isWithdrawed = true;
		
		daiToken.transfer(owner, getTap(_tapNum).funds);
	}

	// Функция для голосования.
	function vote(bool _vote) external {
		(uint curTapNum, TapStage[] memory tapStages, uint votNum) = getTapsInfo();
		uint rmNum = tapToRId[curTapNum];
		uint invId = getInvestorId(msg.sender);
		require(invId < roadmaps[rmNum].investorsCount); // is investor
		require(tapStages[curTapNum] == TapStage.Voting 
			|| tapStages[curTapNum] == TapStage.VotingDQ 
			|| tapStages[curTapNum] == TapStage.RoadmapVoting 
			|| tapStages[curTapNum] == TapStage.RoadmapVotingDQ);
		require(!isVoted(getVoting(curTapNum, votNum).voted, msg.sender));

		Investor memory investor = roadmaps[rmNum].investors[invId];		
		
		if(_vote) roadmaps[rmNum].taps[curTapNum].votings[votNum].pro += investor.invested;
		if(!_vote) roadmaps[rmNum].taps[curTapNum].votings[votNum].versus += investor.invested;

		roadmaps[rmNum].taps[curTapNum].votings[votNum].voted.push(msg.sender);	
		emit Vote(investor.invested, msg.sender, _vote);	
	}

	function getInvestorId(address _address) internal view returns(uint) {
		uint currTapNum = getCurrentTapNum();
		uint rmNum = tapToRId[currTapNum];
		for(uint invNum = 0; invNum < roadmaps[rmNum].investorsCount; invNum++) {
			if(roadmaps[rmNum].investors[invNum].addr == _address)	 return invNum;
		}
		return roadmaps[rmNum].investorsCount;
	}

	function isVoted(address[] memory _voted, address _address) public view returns(bool isVoted) {
		for(uint voterNum = 0; voterNum < _voted.length; voterNum++) {
			if(_voted[voterNum] == _address) isVoted = true;
		}
	}

	function getTap(uint _tapNum) internal view returns(Tap) {
		uint rmNum = tapToRId[_tapNum];
		return roadmaps[rmNum].taps[_tapNum];		
	}

	function getTapsInfo() public view returns(uint, TapStage[], uint) { // curren_tap, tapstages, current_voting
		uint max = getMaximalTapsLength();
		TapStage[] memory tapStages = new TapStage[](max);
		uint start = 0;
		uint tapD;
		uint votNum = 0;

		for(uint tapNum = 0; tapNum < max; tapNum++) {
			tapD = getTap(tapNum).duration;
			(votNum, tapStages[tapNum], start) = getTapStage(tapNum, tapD, start);
			if((tapStages[tapNum]!=TapStage.Success)) return (tapNum, tapStages, votNum);
		}

		return (tapNum, tapStages, votNum);
	}

	//													               votingnum, tapstage, NewstartTime
	function getTapStage(uint _tapNum, uint _tapD, uint _start) public view returns(uint, TapStage, uint) {
		bool invC = areAllFundsCollected(_tapNum);
		uint RmV = _start + _tapD + roadmapD + votesD;
		uint addVRmV = _start + _tapD + addVotesD + roadmapD + votesD;

		if((startedAt == 0) && (now < createdAt + investD))	 return (0, TapStage.Investing, 0);
		if((startedAt == 0) && (now >= createdAt + investD))	 return (0, TapStage.Terminated, 0);
		if((_tapNum==0))						 		 return (0, TapStage.Success, 0);
		
		//          _tapNum  _start time                 duration     voting1      voting2      voting3      voting4   
		//---------------------------------------------------------------------------------------------------------- 
		if(thisCase(_tapNum, _start,                    _tapD-votesD,VR.NoResult, VR.NoResult, VR.NoResult, VR.NoResult))            return (0, TapStage.Preparing, 0);
		if(thisCase(_tapNum, _start+_tapD-votesD,       votesD,      VR.NoResult, VR.NoResult, VR.NoResult, VR.NoResult))            return (0, TapStage.Voting, 0);
		if(thisCase(_tapNum, investD,                   infinity,    VR.Decline,  VR.NoResult, VR.NoResult, VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, investD,                   infinity,    VR.Success,  VR.NoResult, VR.NoResult, VR.NoResult))            return (0, TapStage.Success, _start + _tapD);
		if(thisCase(_tapNum, _start+_tapD,              addVotesD,   VR.NoResult, VR.NoResult, VR.NoResult, VR.NoResult))            return (1, TapStage.VotingDQ, 0);
		if(thisCase(_tapNum, _start+_tapD,              infinity,    VR.NoResult, VR.NoResult, VR.NoResult, VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, _start+_tapD,              infinity,    VR.NoResult, VR.Decline,  VR.NoResult, VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, _start+_tapD,              infinity,    VR.NoResult, VR.Success,  VR.NoResult, VR.NoResult))            return (0, TapStage.Success, _start + _tapD + addVotesD);
		if(thisCase(_tapNum, _start+_tapD+addVotesD,    roadmapD,    VR.NoResult, VR.NoCons,   VR.NoResult, VR.NoResult))            return (0, TapStage.RoadmapPreparing, 0);
		if(thisCase(_tapNum, addVRmV-votesD,            votesD,      VR.NoResult, VR.NoCons,   VR.NoResult, VR.NoResult))            return (2, TapStage.RoadmapVoting, 0);
		if(thisCase(_tapNum, addVRmV,                   investD,     VR.NoResult, VR.NoCons,   VR.Success,  VR.NoResult))            return (0, TapStage.Investing, 0);
		if(thisCase(_tapNum, addVRmV,                   infinity,    VR.NoResult, VR.NoCons,   VR.Success,  VR.NoResult) && invC)    return (0, TapStage.Success, addVRmV + investD);
		if(thisCase(_tapNum, addVRmV,                   infinity,    VR.NoResult, VR.NoCons,   VR.Success,  VR.NoResult) && !invC)   return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, _start+_tapD+addVotesD,    infinity,    VR.NoResult, VR.NoCons,   VR.NoCons,   VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, _start+_tapD+addVotesD,    infinity,    VR.NoResult, VR.NoCons,   VR.Decline,  VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, addVRmV,                   addVotesD,   VR.NoResult, VR.NoCons,   VR.NoResult, VR.NoResult))            return (3, TapStage.RoadmapVotingDQ, 0);
		if(thisCase(_tapNum, addVRmV+addVotesD,         investD,     VR.NoResult, VR.NoCons,   VR.NoResult, VR.Success ))            return (0, TapStage.Investing, 0);
		if(thisCase(_tapNum, addVRmV+investD,           infinity,    VR.NoResult, VR.NoCons,   VR.NoResult, VR.NoResult ))           return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, addVRmV+investD,           infinity,    VR.NoResult, VR.NoCons,   VR.NoResult, VR.NoCons  ))            return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, addVRmV+investD,           infinity,    VR.NoResult, VR.NoCons,   VR.NoResult, VR.Decline ))            return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, addVRmV+addVotesD,         infinity,    VR.NoResult, VR.NoCons,   VR.NoResult, VR.Success ) && invC)    return (0, TapStage.Success, addVRmV + addVotesD + investD);
		if(thisCase(_tapNum, addVRmV+addVotesD,         infinity,    VR.NoResult, VR.NoCons,   VR.NoResult, VR.Success ) && !invC)   return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, _start+_tapD,              roadmapD,    VR.NoCons,   VR.NoResult, VR.NoResult, VR.NoResult))            return (0, TapStage.RoadmapPreparing, 0);
		if(thisCase(_tapNum, _start+_tapD+roadmapD,     votesD,      VR.NoCons,   VR.NoResult, VR.NoResult, VR.NoResult))            return (1, TapStage.RoadmapVoting, 0);
		if(thisCase(_tapNum, addVRmV+addVotesD+investD, infinity,    VR.NoCons,   VR.Decline,  VR.NoResult, VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, addVRmV+addVotesD+investD, infinity,    VR.NoCons,   VR.NoCons,   VR.NoResult, VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, RmV,                       investD,     VR.NoCons,   VR.Success,  VR.NoResult, VR.NoResult))            return (0, TapStage.Investing, 0);
		if(thisCase(_tapNum, RmV,                       infinity,    VR.NoCons,   VR.Success,  VR.NoResult, VR.NoResult) && invC)    return (0, TapStage.Success, RmV + investD);
		if(thisCase(_tapNum, RmV,                       infinity,    VR.NoCons,   VR.Success,  VR.NoResult, VR.NoResult) && !invC)   return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, RmV,                       addVotesD,   VR.NoCons,   VR.NoResult, VR.NoResult, VR.NoResult))            return (2, TapStage.RoadmapVotingDQ, 0);
		if(thisCase(_tapNum, RmV+addVotesD,             investD,     VR.NoCons,   VR.NoResult, VR.Success,  VR.NoResult))            return (0, TapStage.Investing, 0);
		if(thisCase(_tapNum, RmV+investD,               infinity,    VR.NoCons,   VR.NoResult, VR.NoResult, VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, RmV+investD,               infinity,    VR.NoCons,   VR.NoResult, VR.Decline,  VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, RmV+investD,               infinity,    VR.NoCons,   VR.NoResult, VR.NoCons,   VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(thisCase(_tapNum, RmV+addVotesD,             infinity,    VR.NoCons,   VR.NoCons,   VR.Success,  VR.NoResult) && invC)    return (0, TapStage.Success, addVRmV + addVotesD + investD);
		if(thisCase(_tapNum, RmV+addVotesD,             infinity,    VR.NoCons,   VR.NoCons,   VR.Success,  VR.NoResult) && !invC)   return (0, TapStage.Terminated, 0);
		//----------------------------------------------------------------------------------------------------------		
		return (0, TapStage.Preparing, 0);
	}

	function thisCase(uint _tapNum, uint _from, uint _duration, 
		VR _votingRes1, 
		VR _votingRes2, 
		VR _votingRes3, 
		VR _votingRes4) public view returns(bool)
	{
		if(!at(_from, _duration)) return false;

		bool withLessQuorum = false;
		if(_votingRes1 != votingState(_tapNum, 0, withLessQuorum)) return false;
		withLessQuorum = (_votingRes1 == VR.NoResult);

		if(_votingRes2 != votingState(_tapNum, 1, withLessQuorum)) return false;
		withLessQuorum = (_votingRes2 == VR.NoResult);

		if(_votingRes3 != votingState(_tapNum, 2, withLessQuorum)) return false;
		withLessQuorum = (_votingRes3 == VR.NoResult);

		if(_votingRes4 != votingState(_tapNum, 3, withLessQuorum)) return false;

		return true;
	}

	function proposeNewRoadmap(uint[] _tapFunds, uint[] _tapDurations) external {
		(uint curTapNum, TapStage[] memory tapStages, uint votNum) = getTapsInfo();
		uint rmNum;
		require(tapStages[curTapNum] == TapStage.RoadmapPreparing);
		require(_tapFunds.length == _tapDurations.length);
		require(msg.sender == owner);
		require(_tapFunds.length >= roadmaps[roadmapsCount - 1].tapsCount);
		require(!newRoadmapProposed);

		roadmaps[roadmapsCount].tapsCount = _tapFunds.length;
		roadmaps[roadmapsCount].investorsCount = roadmaps[roadmapsCount - 1].investorsCount;
		
		for(uint tapFundsNum = 0; tapFundsNum < _tapFunds.length; tapFundsNum++) {
			rmNum = tapToRId[tapFundsNum];
			require(_tapDurations[tapFundsNum] > 7);
			if(tapFundsNum <= curTapNum) {
				require(_tapDurations[tapFundsNum]*(1 days) == roadmaps[rmNum].taps[tapFundsNum].duration);
				require(_tapFunds[tapFundsNum] == roadmaps[rmNum].taps[tapFundsNum].funds);
			} else if(tapFundsNum > curTapNum) {
				tapToRId[tapFundsNum] = roadmapsCount; // just for clearness;	
			}
			
			Tap memory tap;
			tap.funds = _tapFunds[tapFundsNum];
			tap.duration = _tapDurations[tapFundsNum]*(1 days);
			tap.isWithdrawed = false;
			roadmaps[roadmapsCount].taps[tapFundsNum] = tap;
		}

		uint invNum;
		for(invNum = 0; invNum < roadmaps[roadmapsCount - 1].investorsCount; invNum++) {
			roadmaps[roadmapsCount].investors[invNum] = roadmaps[roadmapsCount - 1].investors[invNum];
		}

		roadmapsCount += 1;
		newRoadmapProposed = true;
	}

	function at(uint _from, uint _long) public view returns(bool) {
		return ((now >= _from + startedAt) && (now < startedAt + _from + _long));
	}

	function isQuorumReached(uint _tapNum, Voting memory _voting, uint _quorumPercent) internal view returns(bool) {
		return (_voting.pro.add(_voting.versus).mul(100) >= tapAmountsSum(_tapNum).mul(_quorumPercent));
	}

	function isConsensusReached(Voting memory _voting, uint _consensusPercent) internal view returns(bool) {
		return (_voting.pro.mul(100 - _consensusPercent) >= _voting.versus.mul(_consensusPercent));
	}

	function isDeclined(Voting memory _voting, uint _declinePercent) internal view returns(bool) {
		return (_voting.versus.mul(100 - _declinePercent) >= _voting.pro.mul(_declinePercent));
	}

	function getVoting(uint _tapNum, uint _votNum) internal view returns(Voting) {
		uint rmNum = tapToRId[_tapNum];
		return roadmaps[rmNum].taps[_tapNum].votings[_votNum];
	}

	function votingState(uint _tapNum, uint _votNum, bool _isQuorumDecreased) public view returns(VR) {
		uint _quorumPercent = quorumPercent;
		if(_isQuorumDecreased)	_quorumPercent = quorumPercent - 20;
		
		Voting memory voting = getVoting(_tapNum, _votNum);
		
		if(!isQuorumReached(_tapNum, voting, _quorumPercent)) return VR.NoResult;
		if(isConsensusReached(voting, consensusPercent))	return VR.Success;
		if(isDeclined(voting, declinePercent))	return VR.Decline;
		return VR.NoCons;
	}
}