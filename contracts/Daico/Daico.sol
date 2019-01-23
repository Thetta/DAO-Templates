pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "zeppelin-solidity/contracts/token/ERC20/MintableToken.sol";


contract Daico {
	using SafeMath for uint;
	enum TapStage {
		Preparing,
		Voting,
		VotingDQ,
		RoadmapPreparing,
		RoadmapVoting,
		RoadmapVotingDQ,
		Success,
		Terminated
	}

	enum VotingResult {
		QuorumNotReached,
		ConsensusNotReached,
		Success,
		Decline
	}

	Project public proj;

	struct Project {
		bool isActive;
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
		uint quorumDecresedPercent;
		uint declinePercent;
		uint consensusPercent;
		Tap[] taps;
		Tap[] proposedTaps;
		Investor[] investors;
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

	function nonZero(bytes32 _target) public view returns(bool) {
		return (_target == bytes32(0));
	}

	// owner создает Daico контракт, куда закладываются следующие параметры:
	// 1. daiToken – токен Evercity
	// 2. returnAddress - куда вернуть деньги в случае фейла проекта
	// 3. tapFunds – массив количества выплат на каждый tap
	// 4. tapDurations – массив длительностей каждого tap
	// В конструкторе деплоится projectToken, которые будут получать investors в обмен на daiToken
	constructor(address _owner, address _daiToken, address _returnAddress, uint[] memory _tapFunds, uint[] memory _tapDurations) public {
		require(_tapFunds.length == _tapDurations.length);
		// require(nonZero(bytes32(_owner)) && nonZero(bytes32(_daiToken)) && nonZero(bytes32(_returnAddress)) && nonZero(bytes32(_tapFunds.length)));
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
		proj.quorumDecresedPercent = 50;
		proj.declinePercent = 80;
		proj.consensusPercent = 70;

		require(_tapFunds.length == _tapDurations.length);
		for(uint i = 0; i < _tapFunds.length; i++) {
			Tap memory tap;
			tap.funds = _tapFunds[i];
			tap.duration = _tapDurations[i];
			proj.taps.push(tap);
		}
	}

	Investor[] public investors;

	// Функция инициации контракта. 
	// Имеется общее количество daiToken, которое должно поступить на контракт перед началом процесса – Sum(tapFunds)
	// Любой может купить любое количество оставшихся projectToken, предварительно сделав approve на то же количество daiToken
	// Как только все projectToken проданы, контракт автоматически переходит в первый stage, и owner может снять daiToken за первый tap.
	// Если lifetime закончился, а projectToken проданы не все, то можно вызвать returnTokens, которая вернет токены обратно инвесторам.
	// 1. Для примера – tap.durations == 1 month, все голосования проходят успешно, тогда Timeline такой:
	// 	 invest ----> active |---(1TAP:  1 month - 1 week: nothing)---(1TAP:  1 week: voting for a next tap)---(2TAP:  1 month - 1 week: nothing)---(2TAP:  1 week: voting for a next tap)---...
	// 2. Не набран кворум – сразу стартует повторное голосование (7 дней) с пониженным кворумом >50%. 
	// 	 invest ----> active |---(1TAP:  1 month - 1 week: nothing)---(1TAP:  1 week: voting for a next tap)---(1TAP:  1 additional week: voting for a next tap)---...
	// 3. Кворум набран, но пороговый % проголосовавших «за» не пройден. В результате сразу инициируется голосование по пересмотру роадмапа и доработке проекта через месяц.
	// 	 invest ----> active |---(1TAP:  1 month - 1 week: nothing)---(1TAP:  1 week: voting for a next tap)---(1TAP:  3 additional weeks: change roadmap)---(1TAP:  1 additional week: voting)---...

	function invest(uint _amount) public {
		require(!proj.isActive);
		require(nonZero(bytes32(_amount)));
		require(totalInvestitions() + _amount <= tapAmountsSum());
		proj.daiToken.transferFrom(msg.sender, address(this), _amount);
		proj.token.mint(msg.sender, _amount);
		proj.investors.push(Investor(msg.sender, _amount));
		if(totalInvestitions() + _amount == tapAmountsSum()) {
			proj.isActive = true;
			proj.startedAt = now;
		}
	}
	function totalInvestitions() public view returns(uint sum) {
		for(uint i = 0; i < proj.investors.length; i++) {
			sum += proj.investors[i].invested;
		}
	}

	function tapAmountsSum() public view returns(uint sum) {
		for(uint t = 0; t < proj.taps.length; t++) {
			sum += proj.taps[t].funds;
		}
	}

	function returnTokens() external {
		(uint t, TapStage[] memory tapStages, uint v) = getTapsInfo();
		require(tapStages[t] == TapStage.Terminated);
		uint remainder = 0;
		for(uint i = 0; i < proj.taps.length; i++) {
			if(!proj.taps[t].isWithdrawed) {
				remainder += proj.taps[i].funds;
			}
		}

		for(i = 0; i < proj.investors.length; i++) {
			proj.daiToken.transfer(proj.investors[i].addr, ((remainder * proj.investors[i].invested)/tapAmountsSum()));
		}
	}

	// Функция для снятия средств owner'ом.
	function withdrawFundsFromTap(uint _t) external {
		require(msg.sender == proj.owner);

		(uint t, TapStage[] memory tapStages, uint v) = getTapsInfo();
		require(tapStages[_t] == TapStage.Success);
		proj.taps[_t].isWithdrawed = true;
		proj.daiToken.transfer(proj.owner, proj.taps[_t].funds);
	}

	// Функция для голосования.
	function vote(bool _vote) external {
		require(isInvestor(msg.sender));

		(uint t, TapStage[] memory tapStages, uint v) = getTapsInfo();
		require(tapStages[t] == TapStage.Voting 
			|| tapStages[t] == TapStage.VotingDQ 
			|| tapStages[t] == TapStage.RoadmapVoting 
			|| tapStages[t] == TapStage.RoadmapVotingDQ);
	
		require(!isVoted(proj.taps[t].votings[v].voted, msg.sender));

		if(_vote) {
			proj.taps[t].votings[v].pro += getInvestorAmount(msg.sender);
		} else {
			proj.taps[t].votings[v].versus += getInvestorAmount(msg.sender);
		}

		proj.taps[t].votings[v].voted.push(msg.sender);
	}

	function getInvestorAmount(address _a) public view returns(uint amount) {
		for(uint i = 0; i < proj.investors.length; i++) {
			if(proj.investors[i].addr == _a) {
				amount = proj.investors[i].invested;
			}
		}
	}

	function isInvestor(address _a) public view returns(bool isInv) {
		for(uint i = 0; i < proj.investors.length; i++) {
			if(proj.investors[i].addr == _a) {
				isInv = true;
			}
		}
	}

	function isVoted(address[] memory _voted, address _a) public view returns(bool isVoted) {
		for(uint i = 0; i < _voted.length; i++) {
			if(_voted[i] == _a) {
				isVoted = true;
			}
		}
	}

	/*
	 Общая диаграмма состояния 
		 NOQ, NOC, SUC, DEC – соответственно QuorumNotReached, ConsensusNotReached, Success, Decline 
		 VOT, VOTDQ, VOT_RM – голосование, голосование с пониженным кворумом, голосование за принятие roadmap
		 PREP, RM – подготовка к голосованию, подготовка к голосованию за roadmap
		 >>> – переход на следующий tap
		 • – terminate

	                                     | NOQ---• |15|             | NOQ---• |20|         | NOQ---• |24|
	                                     |         |16|  |17|       |               |21|   |
	                                     | NOC------RM--VOT_RM----* | NOC----------VOTDQ--*| NOC---• |25|
	                            |02|     | SUC->>> |18|             | SUC->>> |22|         | SUC->>> |26|
	                | NOQ------VOTDQ----*| DEC---• |19|             | DEC---• |23|         | DEC---• |27|
	     |00|  |01| |
	INV--PREP--VOT-*| SUC->>> |03|                     
	                | DEC---• |04| 
	                |                    | NOC---• |07|      |08|      | NOQ---• |11|
	                | NOC--RM--VOT_RM---*| NOQ--------------VOTDQ-----*| NOC---• |12|
	                      |05|  |06|     | SUC->>> |09|                | SUC->>> |13|
	                                     | DEC---• |10|                | DEC---• |14|
	*/

	// check that roadmap changed
	function getTapsInfo() public view returns(uint, TapStage[] memory, uint) {
		require(proj.startedAt > 0);

		uint votD = proj.votingDuration;
		uint addD = proj.additionalDuration;
		uint tapD;
		uint rmD = proj.changeRoadmapDuration;
		TapStage[] memory tapStages = new TapStage[](proj.taps.length);
		uint tapStart = proj.startedAt;
		
		for(uint t = 0; t < proj.taps.length; t++) {
			tapD = proj.taps[t].duration;

			if(at(tapStart, tapD-votD)) {
				tapStages[t] = TapStage.Preparing;
				return (t, tapStages, 0);
			} else if(at(tapStart+tapD-votD, votD)) {
				tapStages[t] = TapStage.Voting;
				return (t, tapStages, 0);
			} else if(now > tapStart+tapD) {
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
					} else if(now > tapStart+tapD+addD) {
						if(VotingResult.QuorumNotReached == votingState(t, 1, true)) {
							tapStages[t] = TapStage.Terminated;
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
							} else if(now > tapStart+tapD+addD+rmD+votD) {
								if(VotingResult.Success == votingState(t, 2, false)) {
									tapStages[t] = TapStage.Success;
									tapStart += (tapD+addD+rmD+votD);
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
									} else if(now > tapStart+tapD+addD+rmD+votD+addD) {
										if(VotingResult.Success == votingState(t, 3, true)) {
											tapStages[t] = TapStage.Success;
											tapStart += (tapD+addD+rmD+votD+addD);
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
					} else if(now > tapStart+tapD+rmD+votD) {
						if(VotingResult.Decline == votingState(t, 1, false)) {
							tapStages[t] = TapStage.Terminated;
							return (t, tapStages, 1);
						} else if(VotingResult.Success == votingState(t, 1, false)) {
							tapStages[t] = TapStage.Success;
							tapStart += tapD+rmD+votD;
						} else if(VotingResult.ConsensusNotReached == votingState(t, 1, false)) {
							tapStages[t] = TapStage.Terminated;
							return (t, tapStages, 1);
						} else if(VotingResult.QuorumNotReached == votingState(t, 1, false)) {
							if(at(tapStart+tapD+rmD+votD, addD)) {
								tapStages[t] = TapStage.RoadmapVotingDQ;
								return (t, tapStages, 2);
							} else if(now > tapStart+tapD+rmD+votD+addD) {
								if(VotingResult.Decline == votingState(t, 2, true)) {
									tapStages[t] = TapStage.Terminated;
									return (t, tapStages, 2);
								} else if(VotingResult.Success == votingState(t, 2, true)) {
									tapStages[t] = TapStage.Success;
									tapStart += tapD+rmD+votD+addD;
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
	}

	/*function proposeNewRoadmap(uint[] _tapFunds, uint[] _tapDurations) external {
		require(msg.sender == proj.owner);
		require(nonZero(bytes32(_tapFunds.length));
		(uint t, TapStage[] tapStages, uint v) = getTapsInfo();
		require(tapStages[t] == TapStage.RoadmapPreparing);
		require(_tapFunds.length == _tapDurations.length);
		for(uint i = 0; i < _tapFunds.length; i++) {
			Tap memory tap;
			tap.funds = _tapFunds[i];
			tap.duration = _tapDurations[i];
			proj.proposedTaps.push(tap);
		}
		// GOTO invest stage, if need more money
		// GOTO withdraw proficit
		// FIX: success taps shouldn't be replaced
	}*/

	function at(uint _from, uint _long) public view returns(bool) {
		return ((now >= _from) && (now < _from + _long));
	}

	function isQuorumReached(Voting memory _v, uint _quorumPercent) internal view returns(bool) {
		return (_v.pro.add(_v.versus).mul(100) >= tapAmountsSum().mul(_quorumPercent));
	}

	function isConsensusReached(Voting memory _v, uint _consensusPercent) internal view returns(bool) {
		return (_v.pro.mul(100 - _consensusPercent) >= _v.versus.mul(_consensusPercent));
	}

	function isDeclined(Voting memory _v, uint _declinePercent) internal view returns(bool) {
		return (_v.versus.mul(100 - _declinePercent) >= _v.pro.mul(_declinePercent));
	}

	function votingState(uint _t, uint _v, bool _isQuorumDecreased) returns(VotingResult) {
		uint quorumPercent;
		if(_isQuorumDecreased) {
			quorumPercent = proj.quorumDecresedPercent;
		} else {
			quorumPercent = proj.quorumPercent;
		}
		Voting memory v = proj.taps[_t].votings[_v];
		if(isQuorumReached(v, quorumPercent)) {
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