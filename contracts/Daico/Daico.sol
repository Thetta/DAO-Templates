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

	/**
	* @param _owner owner address
	* @param _daiToken evercity token address
	* @param _STOContractAddress address of the project token
	* @param _returnAddress address to return tokens if project fails
	* @param _tapFunds array of tap amount to invest
	* @param _tapDurations array of tap durations
	*/
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

	/**
	* @dev this function will replace current roadmap to the proposed one if it was accepted
		  this function will be called at the first investment operation for a new roadmap
	*/		
	function _replaceRoadmapToProposedOne() internal {
		(uint curTapNum, TapStage[] memory tapStages, uint v) = getTapsInfo();
		for(uint tapNum = 0; tapNum < roadmaps[roadmapsCount - 1].tapsCount; tapNum++) {
			if(tapNum > curTapNum)  tapToRId[tapNum] = roadmapsCount - 1;
		}
	}

	/**
	* @dev interface for the STOContract to add an investor
	* @param _amount – token amount, that investor going to invest
	* @param _investorAddress – address of an investor
	*/		
	function addInvestor(uint _amount, address _investorAddress) public {
		require(STOContractAddress == msg.sender);
		(uint curTapNum, TapStage[] memory tapStages, uint votNum) = getTapsInfo();
		require(tapStages[curTapNum] == TapStage.Investing);
		require(_amount > 0);
		
		if(newRoadmapProposed) _replaceRoadmapToProposedOne(); curTapNum += 1;

		uint rmNum = tapToRId[curTapNum];
		uint invId = _getInvestorId(_investorAddress);

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

	/**
	* @param _tapNum – number of a tap
	* @return are all funds for a this _tapNum collected or not
	*/		
	function areAllFundsCollected(uint _tapNum) internal view returns(bool) {
		return amountOfAllInvestments(_tapNum) >= tapAmountsSum(_tapNum);
	}

	/**
	* @dev sum can vary for a different _tapNum in cases when roadmap have been changed
	* @param _tapNum – number of a tap
	* @return sum – sum of all gotten investments for a specific tap
	*/		
	function amountOfAllInvestments(uint _tapNum) public view returns(uint sum) {
		uint rmNum = tapToRId[_tapNum];
		uint invCount = roadmaps[rmNum].investorsCount;
		for(uint invNum = 0; invNum < invCount; invNum++) {
			sum += roadmaps[rmNum].investors[invNum].invested;
		}
	}

	/**
	* @dev sum of all tap amounts; output can vary for a different _tapNum in cases when roadmap have been changed
	* @param _tapNum – number of the tap (to get an appropriate roadmap)
	* @return sum – sum of tap amounts
	*/		
	function tapAmountsSum(uint _tapNum) public view returns(uint sum) {
		uint rmNum = tapToRId[_tapNum];
		uint tapsCount = roadmaps[rmNum].tapsCount;
		for(uint tapNum = 0; tapNum < tapsCount; tapNum++) {
			sum += roadmaps[rmNum].taps[tapNum].funds;
		}
	}

	/**
	* @dev withdrawal interface for the investors; works in a cases when project fails
	* @dev returns all tokens to the investors that was not spent yet
	*/		
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

	/**
	* @dev withdrawal interface for the project owner
	* @param _tapNum – number of tap to withdraw from
	*/		
	function withdrawFundsFromTap(uint _tapNum) external {
		require(msg.sender == owner);

		(uint curTapNum, TapStage[] memory tapStages, uint votNum) = getTapsInfo();
		uint rmNum = tapToRId[_tapNum];
		
		require(tapStages[_tapNum] == TapStage.Success);
		
		roadmaps[rmNum].taps[_tapNum].isWithdrawed = true;
		
		daiToken.transfer(owner, roadmaps[rmNum].taps[_tapNum].funds);
	}

	/**
	* @dev voting interface for investors
	* @param _vote – pro or versus
	*/		
	function vote(bool _vote) external {
		(uint curTapNum, TapStage[] memory tapStages, uint votNum) = getTapsInfo();
		uint rmNum = tapToRId[curTapNum];
		uint invId = _getInvestorId(msg.sender);
		require(invId < roadmaps[rmNum].investorsCount); // is investor
		require(tapStages[curTapNum] == TapStage.Voting 
			|| tapStages[curTapNum] == TapStage.VotingDQ 
			|| tapStages[curTapNum] == TapStage.RoadmapVoting 
			|| tapStages[curTapNum] == TapStage.RoadmapVotingDQ);
		require(!isVoted(curTapNum, votNum, msg.sender));

		Investor memory investor = roadmaps[rmNum].investors[invId];		
		
		if(_vote) roadmaps[rmNum].taps[curTapNum].votings[votNum].pro += investor.invested;
		if(!_vote) roadmaps[rmNum].taps[curTapNum].votings[votNum].versus += investor.invested;

		roadmaps[rmNum].taps[curTapNum].votings[votNum].voted.push(msg.sender);	
		emit Vote(investor.invested, msg.sender, _vote);	
	}

	/**
	* @param _targetAddress – address of the investor (presumably)
	* @return investor id
	*/		
	function _getInvestorId(address _targetAddress) internal view returns(uint) {
		(uint curTapNum, TapStage[] memory tapStages, uint v) = getTapsInfo();
		uint rmNum = tapToRId[curTapNum];
		for(uint invNum = 0; invNum < roadmaps[rmNum].investorsCount; invNum++) {
			if(roadmaps[rmNum].investors[invNum].addr == _targetAddress) return invNum;
		}
		return roadmaps[rmNum].investorsCount;
	}

	/**
	* @dev
	* @param _tapNum – number of the tap
	* @param _votNum – number of the voting	
	* @param _voterAddress – address of the voter (presumably)
	* @return is voted or not
	*/		
	function isVoted(uint _tapNum, uint _votNum, address _voterAddress) public view returns(bool isVoted) {
		uint rmNum = tapToRId[_tapNum];
		Voting memory voting = roadmaps[rmNum].taps[_tapNum].votings[_votNum];
	
		for(uint voterNum = 0; voterNum < voting.voted.length; voterNum++) {
			if(voting.voted[voterNum] == _voterAddress) isVoted = true;
		}
	}

	/**
	* @dev – returns tap 
	* @param _tapNum – number of the tap to return
	* @return Tap
	*/		
	function _getTap(uint _tapNum) internal view returns(Tap) {
		uint rmNum = tapToRId[_tapNum];
		return roadmaps[rmNum].taps[_tapNum];		
	}

	/**
	* @return current_tap – number of the current tap
	* @return tapStages array – array of a states for all tap stages
	* @return current voting num – number of the current voting
	*/		
	function getTapsInfo() public view returns(uint, TapStage[], uint) { // curren_tap, tapstages, current_voting
		uint maximalTapsAmount = 0;
		for(uint rmNum = 0; rmNum < roadmapsCount; rmNum++) {
			if(roadmaps[rmNum].tapsCount > maximalTapsAmount) {
				maximalTapsAmount = roadmaps[rmNum].tapsCount;
			}
		}		

		TapStage[] memory tapStages = new TapStage[](maximalTapsAmount);
		uint start = 0;
		uint tapD;
		uint votNum = 0;

		for(uint tapNum = 0; tapNum < maximalTapsAmount; tapNum++) {
			tapD = _getTap(tapNum).duration;
			(votNum, tapStages[tapNum], start) = getTapStage(tapNum, tapD, start);
			if((tapStages[tapNum]!=TapStage.Success)) return (tapNum, tapStages, votNum);
		}

		return (tapNum, tapStages, votNum);
	}

	/**
	* @param _tapNum – number of the tap
	* @param _tapD – tap duration
	* @param _start – start time of the current tap
	* @return current voting num – number of the current voting
	* @return tapStage – state of the current tap
	* @return NewstartTime – start time of the next tap
	*/		
	function getTapStage(uint _tapNum, uint _tapD, uint _start) public view returns(uint, TapStage, uint) {
		bool invC = areAllFundsCollected(_tapNum);
		uint RmV = _start + _tapD + roadmapD + votesD;
		uint addVRmV = _start + _tapD + addVotesD + roadmapD + votesD;

		if((startedAt == 0) && (now < createdAt + investD))	 return (0, TapStage.Investing, 0);
		if((startedAt == 0) && (now >= createdAt + investD))	 return (0, TapStage.Terminated, 0);
		if((_tapNum==0))						 		 return (0, TapStage.Success, 0);
		
		//          _tapNum  _start time                 duration     voting1      voting2      voting3      voting4   
		//---------------------------------------------------------------------------------------------------------- 
		if(at(_start,                    _tapD-votesD) &&thisCase(_tapNum, VR.NoResult, VR.NoResult, VR.NoResult, VR.NoResult))            return (0, TapStage.Preparing, 0);
		if(at(_start+_tapD-votesD,       votesD)   &&    thisCase(_tapNum, VR.NoResult, VR.NoResult, VR.NoResult, VR.NoResult))            return (0, TapStage.Voting, 0);
		if(at(investD,                   infinity) &&    thisCase(_tapNum, VR.Decline,  VR.NoResult, VR.NoResult, VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(at(investD,                   infinity) &&    thisCase(_tapNum, VR.Success,  VR.NoResult, VR.NoResult, VR.NoResult))            return (0, TapStage.Success, _start + _tapD);
		if(at(_start+_tapD,              addVotesD)&&    thisCase(_tapNum, VR.NoResult, VR.NoResult, VR.NoResult, VR.NoResult))            return (1, TapStage.VotingDQ, 0);
		if(at(_start+_tapD,              infinity) &&    thisCase(_tapNum, VR.NoResult, VR.NoResult, VR.NoResult, VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(at(_start+_tapD,              infinity) &&    thisCase(_tapNum, VR.NoResult, VR.Decline,  VR.NoResult, VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(at(_start+_tapD,              infinity) &&    thisCase(_tapNum, VR.NoResult, VR.Success,  VR.NoResult, VR.NoResult))            return (0, TapStage.Success, _start + _tapD + addVotesD);
		if(at(_start+_tapD+addVotesD,    roadmapD) &&    thisCase(_tapNum, VR.NoResult, VR.NoCons,   VR.NoResult, VR.NoResult))            return (0, TapStage.RoadmapPreparing, 0);
		if(at(addVRmV-votesD,            votesD)   &&    thisCase(_tapNum, VR.NoResult, VR.NoCons,   VR.NoResult, VR.NoResult))            return (2, TapStage.RoadmapVoting, 0);
		if(at(addVRmV,                   investD)  &&    thisCase(_tapNum, VR.NoResult, VR.NoCons,   VR.Success,  VR.NoResult))            return (0, TapStage.Investing, 0);
		if(at(addVRmV,                   infinity) &&    thisCase(_tapNum, VR.NoResult, VR.NoCons,   VR.Success,  VR.NoResult) && invC)    return (0, TapStage.Success, addVRmV + investD);
		if(at(addVRmV,                   infinity) &&    thisCase(_tapNum, VR.NoResult, VR.NoCons,   VR.Success,  VR.NoResult) && !invC)   return (0, TapStage.Terminated, 0);
		if(at(_start+_tapD+addVotesD,    infinity) &&    thisCase(_tapNum, VR.NoResult, VR.NoCons,   VR.NoCons,   VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(at(_start+_tapD+addVotesD,    infinity) &&    thisCase(_tapNum, VR.NoResult, VR.NoCons,   VR.Decline,  VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(at(addVRmV,                   addVotesD)&&    thisCase(_tapNum, VR.NoResult, VR.NoCons,   VR.NoResult, VR.NoResult))            return (3, TapStage.RoadmapVotingDQ, 0);
		if(at(addVRmV+addVotesD,         investD)  &&    thisCase(_tapNum, VR.NoResult, VR.NoCons,   VR.NoResult, VR.Success ))            return (0, TapStage.Investing, 0);
		if(at(addVRmV+investD,           infinity) &&    thisCase(_tapNum, VR.NoResult, VR.NoCons,   VR.NoResult, VR.NoResult ))           return (0, TapStage.Terminated, 0);
		if(at(addVRmV+investD,           infinity) &&    thisCase(_tapNum, VR.NoResult, VR.NoCons,   VR.NoResult, VR.NoCons  ))            return (0, TapStage.Terminated, 0);
		if(at(addVRmV+investD,           infinity) &&    thisCase(_tapNum, VR.NoResult, VR.NoCons,   VR.NoResult, VR.Decline ))            return (0, TapStage.Terminated, 0);
		if(at(addVRmV+addVotesD,         infinity) &&    thisCase(_tapNum, VR.NoResult, VR.NoCons,   VR.NoResult, VR.Success ) && invC)    return (0, TapStage.Success, addVRmV + addVotesD + investD);
		if(at(addVRmV+addVotesD,         infinity) &&    thisCase(_tapNum, VR.NoResult, VR.NoCons,   VR.NoResult, VR.Success ) && !invC)   return (0, TapStage.Terminated, 0);
		if(at(_start+_tapD,              roadmapD) &&    thisCase(_tapNum, VR.NoCons,   VR.NoResult, VR.NoResult, VR.NoResult))            return (0, TapStage.RoadmapPreparing, 0);
		if(at(_start+_tapD+roadmapD,     votesD)   &&    thisCase(_tapNum, VR.NoCons,   VR.NoResult, VR.NoResult, VR.NoResult))            return (1, TapStage.RoadmapVoting, 0);
		if(at(addVRmV+addVotesD+investD, infinity) &&    thisCase(_tapNum, VR.NoCons,   VR.Decline,  VR.NoResult, VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(at(addVRmV+addVotesD+investD, infinity) &&    thisCase(_tapNum, VR.NoCons,   VR.NoCons,   VR.NoResult, VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(at(RmV,                       investD)  &&    thisCase(_tapNum, VR.NoCons,   VR.Success,  VR.NoResult, VR.NoResult))            return (0, TapStage.Investing, 0);
		if(at(RmV,                       infinity) &&    thisCase(_tapNum, VR.NoCons,   VR.Success,  VR.NoResult, VR.NoResult) && invC)    return (0, TapStage.Success, RmV + investD);
		if(at(RmV,                       infinity) &&    thisCase(_tapNum, VR.NoCons,   VR.Success,  VR.NoResult, VR.NoResult) && !invC)   return (0, TapStage.Terminated, 0);
		if(at(RmV,                       addVotesD)&&    thisCase(_tapNum, VR.NoCons,   VR.NoResult, VR.NoResult, VR.NoResult))            return (2, TapStage.RoadmapVotingDQ, 0);
		if(at(RmV+addVotesD,             investD)  &&    thisCase(_tapNum, VR.NoCons,   VR.NoResult, VR.Success,  VR.NoResult))            return (0, TapStage.Investing, 0);
		if(at(RmV+investD,               infinity) &&    thisCase(_tapNum, VR.NoCons,   VR.NoResult, VR.NoResult, VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(at(RmV+investD,               infinity) &&    thisCase(_tapNum, VR.NoCons,   VR.NoResult, VR.Decline,  VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(at(RmV+investD,               infinity) &&    thisCase(_tapNum, VR.NoCons,   VR.NoResult, VR.NoCons,   VR.NoResult))            return (0, TapStage.Terminated, 0);
		if(at(RmV+addVotesD,             infinity) &&    thisCase(_tapNum, VR.NoCons,   VR.NoCons,   VR.Success,  VR.NoResult) && invC)    return (0, TapStage.Success, addVRmV + addVotesD + investD);
		if(at(RmV+addVotesD,             infinity) &&    thisCase(_tapNum, VR.NoCons,   VR.NoCons,   VR.Success,  VR.NoResult) && !invC)   return (0, TapStage.Terminated, 0);
		//----------------------------------------------------------------------------------------------------------		
		return (0, TapStage.Preparing, 0);
	}

	/**
	* @dev check that all voting results are the same
	* @param _tapNum – number of the tap
	* @param _votingRes1 – voting result for a 1 voting in the current tap
	* @param _votingRes2 – voting result for a 2 voting in the current tap
	* @param _votingRes3 – voting result for a 3 voting in the current tap
	* @param _votingRes4 – voting result for a 4 voting in the current tap
	* @return are all voting results the same
	*/		
	function thisCase(uint _tapNum,
		VR _votingRes1, 
		VR _votingRes2, 
		VR _votingRes3, 
		VR _votingRes4) public view returns(bool)
	{
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

	/**
	* @dev project owner can propose new roadmap in the case case if consensus wasn't reached
	* @param _tapFunds – array of amounts to invest for an each tap
	* @return _tapDurations – array of durations for an each tap
	*/		
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

	/**
	* @param _from – start time of this time interval
	* @param _long – duration of this time interval
	* @return is current moment in this time interval
	*/		
	function at(uint _from, uint _long) public view returns(bool) {
		return ((now >= _from + startedAt) && (now < startedAt + _from + _long));
	}

	/**
	* @param _tapNum – number of the tap
	* @param _voting – current voting
	* @param _quorumPercent – quorum percent
	* @return is quorum reached for a given voting with given quorum percent
	*/		
	function _isQuorumReached(uint _tapNum, Voting memory _voting, uint _quorumPercent) internal view returns(bool) {
		return (_voting.pro.add(_voting.versus).mul(100) >= tapAmountsSum(_tapNum).mul(_quorumPercent));
	}

	/**
	* @param _voting – current voting
	* @param _consensusPercent – consensus percent
	* @return is consensus reached for a given voting with given consensus percent
	*/		
	function _isConsensusReached(Voting memory _voting, uint _consensusPercent) internal view returns(bool) {
		return (_voting.pro.mul(100 - _consensusPercent) >= _voting.versus.mul(_consensusPercent));
	}

	/**
	* @param _voting – current voting
	* @param _declinePercent – decline percent
	* @return is this voting declined with given decline percent
	*/	
	function _isDeclined(Voting memory _voting, uint _declinePercent) internal view returns(bool) {
		return (_voting.versus.mul(100 - _declinePercent) >= _voting.pro.mul(_declinePercent));
	}

	/**
	* @dev
	* @param _tapNum – number of the tap
	* @param _votNum – number of the voting
	* @param _isQuorumDecreased – is quorum decreased or not
	* @return voting result vor this voting
	*/		
	function votingState(uint _tapNum, uint _votNum, bool _isQuorumDecreased) public view returns(VR) {
		uint _quorumPercent = quorumPercent;
		if(_isQuorumDecreased)	_quorumPercent = quorumPercent - 20;
	
		uint rmNum = tapToRId[_tapNum];
		Voting memory voting = roadmaps[rmNum].taps[_tapNum].votings[_votNum];
		
		if(!_isQuorumReached(_tapNum, voting, _quorumPercent)) return VR.NoResult;
		if(_isConsensusReached(voting, consensusPercent))	return VR.Success;
		if(_isDeclined(voting, declinePercent))	return VR.Decline;
		return VR.NoCons;
	}
}