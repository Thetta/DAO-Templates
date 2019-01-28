pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "zeppelin-solidity/contracts/token/ERC20/MintableToken.sol";


contract Daico {
	using SafeMath for uint;

	event InvestEvent(uint amount, address _sender, uint total, uint tapSum);

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

	enum VotingResult {
		NotExist,
		QuorumNotReached,
		ConsensusNotReached,
		Success,
		Decline
	}

	Project public proj;

	struct Project {
		address owner;
		MintableToken token;
		ERC20 daiToken;
		uint createdAt;
		uint startedAt;
		uint investDuration;
		uint votingDuration;
		uint additionalDuration;
		uint changeRoadmapDuration;
		uint quorumPercent;
		// uint quorumDecresedPercent;
		uint declinePercent;
		uint consensusPercent;
		bool rewrited;
		uint roadmapsCount;
		mapping(uint=>uint) tapToRId; // tapId -> roadmapId
		mapping(uint=>Roadmap) roadmaps; // roadmapId -> roadmap
	}

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

	// owner создает Daico контракт, куда закладываются следующие параметры:
	// 1. daiToken – токен Evercity
	// 2. returnAddress - куда вернуть деньги в случае фейла проекта
	// 3. tapFunds – массив количества выплат на каждый tap
	// 4. tapDurations – массив длительностей каждого tap
	// В конструкторе деплоится projectToken, которые будут получать investors в обмен на daiToken
	constructor(address _owner, address _daiToken, address _returnAddress, uint[] memory _tapFunds, uint[] memory _tapDurations) public {
		require(_tapFunds.length == _tapDurations.length);
		MintableToken projectToken = new MintableToken();
		proj.token = projectToken;
		proj.daiToken = ERC20(_daiToken);
		proj.owner = _owner;
		proj.createdAt = now;
		proj.investDuration = 7 days;
		proj.votingDuration = 7 days;
		proj.additionalDuration = 7 days;
		proj.changeRoadmapDuration = 21 days;
		proj.quorumPercent = 70;
		// proj.quorumDecresedPercent = 50;
		proj.declinePercent = 80;
		proj.consensusPercent = 70;

		proj.roadmaps[proj.roadmapsCount].tapsCount = _tapFunds.length;
		for(uint i = 0; i < _tapFunds.length; i++) {
			require(_tapDurations[i] > 7);
			proj.tapToRId[i] = 0; // just for clearness;
			proj.roadmaps[proj.roadmapsCount].taps[i] = Tap(_tapFunds[i], _tapDurations[i]*(1 days), false);
		}
		proj.roadmapsCount += 1;
	}

	function getCurrentTap() internal view returns(uint) {
		(uint t, TapStage[] memory tapStages, uint v) = getTapsInfo();
		return t;
	}

	function getMaximalTapsLength() internal view returns(uint maximal) {
		for(uint i = 0; i < proj.roadmapsCount; i++) {
			if(proj.roadmaps[i].tapsCount > maximal) {
				maximal = proj.roadmaps[i].tapsCount;
			}
		}
	}		
	
	// // Функция инициации контракта. 
	// // Имеется общее количество daiToken, которое должно поступить на контракт перед началом процесса – Sum(tapFunds)
	// // Любой может купить любое количество оставшихся projectToken, предварительно сделав approve на то же количество daiToken
	// // Как только все projectToken проданы, контракт автоматически переходит в первый stage, и owner может снять daiToken за первый tap.
	// // Если lifetime закончился, а projectToken проданы не все, то можно вызвать returnTokens, которая вернет токены обратно инвесторам.
	// // 1. Для примера – tap.durations == 1 month, все голосования проходят успешно, тогда Timeline такой:
	// // 	 invest ----> active |---(1TAP:  1 month - 1 week: nothing)---(1TAP:  1 week: voting for a next tap)---(2TAP:  1 month - 1 week: nothing)---(2TAP:  1 week: voting for a next tap)---...
	// // 2. Не набран кворум – сразу стартует повторное голосование (7 дней) с пониженным кворумом >50%. 
	// // 	 invest ----> active |---(1TAP:  1 month - 1 week: nothing)---(1TAP:  1 week: voting for a next tap)---(1TAP:  1 additional week: voting for a next tap)---...
	// // 3. Кворум набран, но пороговый % проголосовавших «за» не пройден. В результате сразу инициируется голосование по пересмотру роадмапа и доработке проекта через месяц.
	// // 	 invest ----> active |---(1TAP:  1 month - 1 week: nothing)---(1TAP:  1 week: voting for a next tap)---(1TAP:  3 additional weeks: change roadmap)---(1TAP:  1 additional week: voting)---...
	function invest(uint _amount) public {
		(uint t, TapStage[] memory tapStages, uint v) = getTapsInfo();
		require(tapStages[t] == TapStage.Investing);
		require(_amount > 0);

		if(proj.rewrited) {
			for(uint i = 0; i < proj.roadmaps[proj.roadmapsCount - 1].tapsCount; i++) {
				if(i > t) {
					proj.tapToRId[i] = proj.roadmapsCount - 1;
				}
			}
			t += 1;
		}

		require(totalInvestitions(t) + _amount <= tapAmountsSum(t));
		proj.daiToken.transferFrom(msg.sender, address(this), _amount);
		proj.token.mint(msg.sender, _amount);
		if(getInvestorId(msg.sender) == proj.roadmaps[proj.tapToRId[getCurrentTap()]].investorsCount) { // not investor
			uint invCount = proj.roadmaps[proj.tapToRId[t]].investorsCount;
			proj.roadmaps[proj.tapToRId[t]].investors[invCount] = Investor(msg.sender, _amount);
			proj.roadmaps[proj.tapToRId[t]].investorsCount += 1;
		} else {
			proj.roadmaps[proj.tapToRId[t]].investors[getInvestorId(msg.sender)].invested += _amount;
		}

		emit InvestEvent(_amount, msg.sender, totalInvestitions(t), tapAmountsSum(t));
		if((totalInvestitions(t) >= tapAmountsSum(t)) && (proj.startedAt==0)) {
			proj.startedAt = now;
			proj.rewrited = false;
		}

	}

	/*function getVotingsResultForTap(uint t) public view returns(uint[]) {
		uint[] memory vr = new uint[](4);
		vr[0] = proj.taps[t].votings[0].pro;//votingState(t, 0, false);
		vr[1] = proj.taps[t].votings[1].pro;//votingState(t, 1, false);
		vr[2] = proj.taps[t].votings[2].pro;//votingState(t, 2, false);
		vr[3] = proj.taps[t].votings[3].pro;//votingState(t, 3, false);
		return vr;
	}

	function getTaps() public view returns(uint[], uint[]) {
		uint[] memory tapFunds = new uint[](getMaximalTapsLength());
		uint[] memory tapDurations = new uint[](getMaximalTapsLength());
		for(uint i = 0; i < getMaximalTapsLength(); i++) {
			tapFunds[i] = proj.taps[i].funds;
			tapDurations[i] = proj.taps[i].duration;
		}

		return (tapFunds, tapDurations);
	}*/

	function totalInvestitions(uint _t) public view returns(uint sum) {
		for(uint i = 0; i < proj.roadmaps[proj.tapToRId[_t]].investorsCount; i++) {
			sum += proj.roadmaps[proj.tapToRId[_t]].investors[i].invested;
		}
	}

	function tapAmountsSum(uint _t) public view returns(uint sum) {
		for(uint t = 0; t < proj.roadmaps[proj.tapToRId[_t]].tapsCount; t++) {
			sum += proj.roadmaps[proj.tapToRId[_t]].taps[t].funds;
		}
	}

	function returnTokens() external {
		(uint t, TapStage[] memory tapStages, uint v) = getTapsInfo();
		require(tapStages[t] == TapStage.Terminated);			

		uint remainder = proj.daiToken.balanceOf(address(this));
		uint part;
		for(uint i = 0; i < proj.roadmaps[proj.tapToRId[getCurrentTap()]].investorsCount; i++) {
			part = ((remainder * proj.roadmaps[proj.tapToRId[getCurrentTap()]].investors[i].invested)/totalInvestitions(t));
			proj.daiToken.transfer(proj.roadmaps[proj.tapToRId[getCurrentTap()]].investors[i].addr, part);
		}
	}

	// Функция для снятия средств owner'ом.
	function withdrawFundsFromTap(uint _t) external {
		require(msg.sender == proj.owner);

		(uint t, TapStage[] memory tapStages, uint v) = getTapsInfo();
		require(tapStages[_t] == TapStage.Success);
		proj.roadmaps[proj.tapToRId[t]].taps[_t].isWithdrawed = true;
		proj.daiToken.transfer(proj.owner, proj.roadmaps[proj.tapToRId[t]].taps[_t].funds);
	}

	// Функция для голосования.
	function vote(bool _vote) external {
		(uint t, TapStage[] memory tapStages, uint v) = getTapsInfo();
		require(getInvestorId(msg.sender) < proj.roadmaps[proj.tapToRId[t]].investorsCount); // is investor
		require(tapStages[t] == TapStage.Voting 
			|| tapStages[t] == TapStage.VotingDQ 
			|| tapStages[t] == TapStage.RoadmapVoting 
			|| tapStages[t] == TapStage.RoadmapVotingDQ);
		require(!isVoted(proj.roadmaps[proj.tapToRId[t]].taps[t].votings[v].voted, msg.sender));

		if(_vote) {
			proj.roadmaps[proj.tapToRId[t]].taps[t].votings[v].pro += proj.roadmaps[proj.tapToRId[t]].investors[getInvestorId(msg.sender)].invested;
		} else {
			proj.roadmaps[proj.tapToRId[t]].taps[t].votings[v].versus += proj.roadmaps[proj.tapToRId[t]].investors[getInvestorId(msg.sender)].invested;
		}

		proj.roadmaps[proj.tapToRId[t]].taps[t].votings[v].voted.push(msg.sender);
	}

	function getInvestorId(address _a) internal view returns(uint) {
		for(uint i = 0; i < proj.roadmaps[proj.tapToRId[getCurrentTap()]].investorsCount; i++) {
			if(proj.roadmaps[proj.tapToRId[getCurrentTap()]].investors[i].addr == _a) {
				return i;
			}
		}
		return proj.roadmaps[proj.tapToRId[getCurrentTap()]].investorsCount;
	}

	function isVoted(address[] memory _voted, address _a) public view returns(bool isVoted) {
		for(uint i = 0; i < _voted.length; i++) {
			if(_voted[i] == _a) {
				isVoted = true;
			}
		}
	}

	// /*
	//  Общая диаграмма состояния 
	// 	 NOQ, NOC, SUC, DEC – соответственно QuorumNotReached, ConsensusNotReached, Success, Decline 
	// 	 VOT, VOTDQ, VOT_RM – голосование, голосование с пониженным кворумом, голосование за принятие roadmap
	// 	 PREP, RM – подготовка к голосованию, подготовка к голосованию за roadmap
	// 	 >>> – переход на следующий tap
	// 	 • – terminate

	//                                      | NOQ---• |15|             | NOQ---• |20|         | NOQ---• |24|
	//                                      |         |16|  |17|       |               |21|   |
	//                                      | NOC------RM--VOT_RM----* | NOC----------VOTDQ--*| NOC---• |25|
	//                             |02|     | SUC->>> |18|             | SUC->>> |22|         | SUC->>> |26|
	//                 | NOQ------VOTDQ----*| DEC---• |19|             | DEC---• |23|         | DEC---• |27|
	//      |00|  |01| |
	// INV--PREP--VOT-*| SUC->>> |03|                     
	//                 | DEC---• |04| 
	//                 |                    | NOC---• |07|      |08|      | NOQ---• |11|
	//                 | NOC--RM--VOT_RM---*| NOQ--------------VOTDQ-----*| NOC---• |12|
	//                       |05|  |06|     | SUC->>> |09|                | SUC->>> |13|
	//                                      | DEC---• |10|                | DEC---• |14|
	// */

	function getTapsInfo() public view returns(uint, TapStage[], uint) { // curren_tap, tapstages, current_voting
		uint votD = proj.votingDuration;
		uint addD = proj.additionalDuration;
		uint invD = proj.investDuration;
		uint tapD;
		uint rmD = proj.changeRoadmapDuration;
		uint max = getMaximalTapsLength();
		TapStage[] memory tapStages = new TapStage[](max);
		uint tapStart = 0;
		uint t;
		for(t = 0; t < max; t++) {
			tapD = proj.roadmaps[proj.tapToRId[t]].taps[t].duration;
			if(proj.startedAt == 0) {
				if(now > proj.createdAt + proj.investDuration) {
					tapStages[0] = TapStage.Terminated;
					return (t, tapStages, 0);					
				} else {
					tapStages[0] = TapStage.Investing;
					return (t, tapStages, 0);
				}
			} else if(t==0) {
				tapStages[t] = TapStage.Success;
			} else if(at(tapStart, tapD-votD)) {
				tapStages[t] = TapStage.Preparing;
				return (t, tapStages, 0);
			} else if(at(tapStart+tapD-votD, votD)) {
				tapStages[t] = TapStage.Voting;
				return (t, tapStages, 0);
			} else if(now >= proj.startedAt + tapStart+tapD) {
				if(VotingResult.Decline == votingState(t, 0, false)) {
					tapStages[t] = TapStage.Terminated;
					return (t, tapStages, 0);
				} else if(VotingResult.Success == votingState(t, 0, false)) {
					tapStages[t] = TapStage.Success;
					tapStart += tapD;
				} else if(VotingResult.QuorumNotReached == votingState(t, 0, false)) {
					if(at(tapStart+tapD, addD)) {
						tapStages[t] = TapStage.VotingDQ;
						return (t, tapStages, 1);
					} else if(now >= proj.startedAt + tapStart+tapD+addD) {
						if(VotingResult.QuorumNotReached == votingState(t, 1, true)) {
							tapStages[t] = TapStage.Terminated;
							return (t, tapStages, 1);
						} else if(VotingResult.Decline == votingState(t, 1, true)) {
							tapStages[t] = TapStage.Terminated;
							return (t, tapStages, 1);
						} else if(VotingResult.Success == votingState(t, 1, true)) {
							tapStages[t] = TapStage.Success;
							tapStart += (tapD+addD);
						} else if(VotingResult.ConsensusNotReached == votingState(t, 1, true)) {
							if(at(tapStart+tapD+addD, rmD)) {
								tapStages[t] = TapStage.RoadmapPreparing;
								return (t, tapStages, 2);
							} else if(at(tapStart+tapD+addD+rmD, votD)) {
								tapStages[t] = TapStage.RoadmapVoting;
								return (t, tapStages, 2);
							} else if(now >= proj.startedAt + tapStart+tapD+addD+rmD+votD) {
								if(VotingResult.Success == votingState(t, 2, false)) {
									if(at(tapStart+tapD+addD+rmD+votD, invD)) { // invest stage for a new roadmap
										tapStages[t] = TapStage.Investing;
										return (t, tapStages, 2);
									} else if((now >= proj.startedAt + tapStart+tapD+addD+rmD+votD+invD) && (totalInvestitions(t) >= tapAmountsSum(t))) {
										tapStages[t] = TapStage.Success;
										tapStart += (tapStart+tapD+addD+rmD+votD+invD);
									} else {
										tapStages[t] = TapStage.Success;
										return (t, tapStages, 2);
									}
								} else if(VotingResult.ConsensusNotReached == votingState(t, 2, false)) {
									tapStages[t] = TapStage.Terminated;
									return (t, tapStages, 2);
								} else if(VotingResult.Decline == votingState(t, 2, false)) {
									tapStages[t] = TapStage.Terminated;
									return (t, tapStages, 2);
								} else if(VotingResult.QuorumNotReached == votingState(t, 2, false)) {
									if(at(tapStart+tapD+addD+rmD+votD, addD)) {
										tapStages[t] = TapStage.RoadmapVotingDQ;
										return (t, tapStages, 3);
									} else if(now >= proj.startedAt + tapStart+tapD+addD+rmD+votD+addD) {
										if(VotingResult.Success == votingState(t, 3, true)) {
											if(at(tapStart+tapD+addD+rmD+votD+addD, invD)) { // invest stage for a new roadmap
												tapStages[t] = TapStage.Investing;
												return (t, tapStages, 3);
											} else if((now >= proj.startedAt + tapStart+tapD+addD+rmD+votD+addD+invD) && (totalInvestitions(t) >= tapAmountsSum(t))) {
												tapStages[t] = TapStage.Success;
												tapStart += (tapStart+tapD+addD+rmD+votD+addD+invD);
											} else {
												tapStages[t] = TapStage.Terminated;
												return (t, tapStages, 3);
											}
										} else if(VotingResult.ConsensusNotReached == votingState(t, 3, true)) {
											tapStages[t] = TapStage.Terminated;
											return (t, tapStages, 3);
										} else if(VotingResult.Decline == votingState(t, 3, true)) {
											tapStages[t] = TapStage.Terminated;
											return (t, tapStages, 3);
										} else if(VotingResult.QuorumNotReached == votingState(t, 3, true)) {
											tapStages[t] = TapStage.Terminated;
											return (t, tapStages, 3);
										}
									}
								}
							}
						}
					}
				} else if(VotingResult.ConsensusNotReached == votingState(t, 0, false)) {
					if(at(tapStart+tapD, rmD)) {
						tapStages[t] = TapStage.RoadmapPreparing;
						return (t, tapStages, 1);
					} else if(at(tapStart+tapD+rmD, votD)) {
						tapStages[t] = TapStage.RoadmapVoting;
						return (t, tapStages, 1);
					} else if(now >= proj.startedAt + tapStart+tapD+rmD+votD) {
						if(VotingResult.Decline == votingState(t, 1, false)) {
							tapStages[t] = TapStage.Terminated;
							return (t, tapStages, 1);
						} else if(VotingResult.Success == votingState(t, 1, false)) {
							if(at(tapStart+tapD+rmD+votD, invD)) { // invest stage for a new roadmap
								tapStages[t] = TapStage.Investing;
								return (t, tapStages, 1);
							} else if((now >= proj.startedAt + tapStart+tapD+rmD+votD+invD) && (totalInvestitions(t) >= tapAmountsSum(t))) {
								tapStages[t] = TapStage.Success;
								tapStart += (tapD+rmD+votD+invD);
							} else {
								tapStages[t] = TapStage.Terminated;
								return (t, tapStages, 1);
							}
						} else if(VotingResult.ConsensusNotReached == votingState(t, 1, false)) {
							tapStages[t] = TapStage.Terminated;
							return (t, tapStages, 1);
						} else if(VotingResult.QuorumNotReached == votingState(t, 1, false)) {
							if(at(tapStart+tapD+rmD+votD, addD)) {
								tapStages[t] = TapStage.RoadmapVotingDQ;
								return (t, tapStages, 2);
							} else if(now >= proj.startedAt + tapStart+tapD+rmD+votD+addD) {
								if(VotingResult.Decline == votingState(t, 2, true)) {
									tapStages[t] = TapStage.Terminated;
									return (t, tapStages, 2);
								} else if(VotingResult.Success == votingState(t, 2, true)) {
									if(at(tapStart+tapD+rmD+votD+addD, invD)) { // invest stage for a new roadmap
										tapStages[t] = TapStage.Investing;
										return (t, tapStages, 2);
									} else if((now >= proj.startedAt + tapStart+tapD+rmD+votD+addD+invD) && (totalInvestitions(t) >= tapAmountsSum(t))) {
										tapStages[t] = TapStage.Success;
										tapStart += (tapD+addD+rmD+votD+addD+invD);
									} else {
										tapStages[t] = TapStage.Terminated;
										return (t, tapStages, 2);
									}
								} else if(VotingResult.ConsensusNotReached == votingState(t, 2, true)) {
									tapStages[t] = TapStage.Terminated;
									return (t, tapStages, 2);
								} else if(VotingResult.QuorumNotReached == votingState(t, 2, true)) {
									tapStages[t] = TapStage.Terminated;
									return (t, tapStages, 2);
								}
							}
						}
					}
				}
			}
		}
		return (t, tapStages, 0);
	}

	function proposeNewRoadmap(uint[] _tapFunds, uint[] _tapDurations) external {
		(uint t, TapStage[] memory tapStages, uint v) = getTapsInfo();
		require(tapStages[t] == TapStage.RoadmapPreparing);
		require(_tapFunds.length == _tapDurations.length);
		require(msg.sender == proj.owner);
		require(_tapFunds.length >= proj.roadmaps[proj.roadmapsCount - 1].tapsCount);
		require(!proj.rewrited);

		proj.roadmaps[proj.roadmapsCount].tapsCount = _tapFunds.length;
		proj.roadmaps[proj.roadmapsCount].investorsCount = proj.roadmaps[proj.roadmapsCount - 1].investorsCount;
		uint i;

		for(i = 0; i < _tapFunds.length; i++) {
			require(_tapDurations[i] > 7);
			if(i <= t) {
				require(_tapDurations[i]*(1 days) == proj.roadmaps[proj.tapToRId[i]].taps[i].duration);
				require(_tapFunds[i] == proj.roadmaps[proj.tapToRId[i]].taps[i].funds);
			} else if(i > t) {
				proj.tapToRId[i] = proj.roadmapsCount; // just for clearness;	
			}
			
			proj.roadmaps[proj.roadmapsCount].taps[i] = Tap(_tapFunds[i], _tapDurations[i]*(1 days), false);
		}

		for(i = 0; i < proj.roadmaps[proj.roadmapsCount - 1].investorsCount; i++) {
			proj.roadmaps[proj.roadmapsCount].investors[i] = proj.roadmaps[proj.roadmapsCount - 1].investors[i];
		}

		proj.roadmapsCount += 1;
		proj.rewrited = true;
	}

	function at(uint _from, uint _long) public view returns(bool) {
		bool out = ((now >= _from + proj.startedAt) && (now < proj.startedAt + _from + _long));
		return out;
	}

	function isQuorumReached(uint _t, Voting memory _v, uint _quorumPercent) internal view returns(bool) {
		return (_v.pro.add(_v.versus).mul(100) >= tapAmountsSum(_t).mul(_quorumPercent)); // FIX HERE: totalInvestitions change after roadmap
	}

	function isConsensusReached(Voting memory _v, uint _consensusPercent) internal view returns(bool) {
		return (_v.pro.mul(100 - _consensusPercent) >= _v.versus.mul(_consensusPercent));
	}

	function isDeclined(Voting memory _v, uint _declinePercent) internal view returns(bool) {
		return (_v.versus.mul(100 - _declinePercent) >= _v.pro.mul(_declinePercent));
	}

	function votingState(uint _t, uint _v, bool _isQuorumDecreased) public view returns(VotingResult) {
		uint quorumPercent;
		if(_isQuorumDecreased) {
			quorumPercent = proj.quorumPercent - 20;
		} else {
			quorumPercent = proj.quorumPercent;
		}
		Voting memory v = proj.roadmaps[proj.tapToRId[_t]].taps[_t].votings[_v];
		if(isQuorumReached(_t, v, quorumPercent)) {
			if(isConsensusReached(v, proj.consensusPercent)) {
				return VotingResult.Success;
			} else if(isDeclined(v, proj.declinePercent)) {
				return VotingResult.Decline;
			} else {
				return VotingResult.ConsensusNotReached;
			}
		} else {
			return VotingResult.QuorumNotReached;
		}
	}
}